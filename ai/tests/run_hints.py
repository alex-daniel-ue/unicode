"""Asks the hint relay about saved game states and writes down what it says.

The states in states/ are real game states, saved by tools/hint_states.tscn:
the context the AI Assistant sends with a question, and its pictures.
questions.json says what to ask about each one:

  vague     the same short questions for every state ("help", "what to do"),
            the way many students actually ask
  specific  one clear question per state, about what went wrong there
  chain     a short chat in which the student stays stuck, to see whether
            the hints get more specific as it goes on

From the repository root:
  python ai/tests/run_hints.py                   # the relay named in unicode_ai.cfg
  python ai/tests/run_hints.py --only AR-8       # states whose id contains AR-8
  python ai/tests/run_hints.py --label baseline  # names the result files
  python ai/tests/run_hints.py --url http://127.0.0.1:3000/api/hint --token ""
  python ai/tests/run_hints.py --dry-run         # list the requests, send nothing

  # The prompt on disk, before deploying: ai/main.py in this process, with ai/.env
  uv run --directory ai python tests/run_hints.py --local --label new-prompt
  # (set GEMINI_THINKING=LOW first to try another thinking level)

Writes results/<time>_<label>.md to read, and .jsonl with every reply. Every
request is a real model call: about half a US cent each on Gemini Flash.
"""
import argparse
import base64
import configparser
import difflib
import json
import re
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PAUSE_S = 2.0  # between requests: the deployed relay serves real players too
# Unanswered requests in a row that stop the run: past this the model, the quota
# or the network is down, and going on only spends the live game's quota.
STOP_AFTER_FAILURES = 5
# Phrases that point the student somewhere without saying anything: a rough
# sign of a general hint, not proof of one.
GENERIC = ("look at", "look again", "take a look", "think about", "what do you think",
           "press play", "run it", "try again", "check your")


def relay_from_cfg() -> tuple[str, str]:
    cfg = configparser.ConfigParser()
    cfg.read(ROOT / "unicode_ai.cfg", encoding="utf-8")
    value = lambda key: cfg.get("ai", key, fallback="").strip().strip('"')
    return value("url"), value("token")


def load_states(only: str) -> list[dict]:
    states = []
    for path in sorted((HERE / "states").glob("*.json")):
        state = json.loads(path.read_text(encoding="utf-8"))
        if only and only not in state["id"]:
            continue
        state["pictures"] = {}
        for key, suffix in (("now", "_now.jpg"), ("start", "_start.jpg")):
            jpg = path.with_name(state["id"] + suffix)
            state["pictures"][key] = base64.b64encode(jpg.read_bytes()).decode() if jpg.exists() else ""
        states.append(state)
    return states


def post(url: str, token: str, payload: dict) -> dict:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["X-UniCode-Token"] = token
    request = urllib.request.Request(url, json.dumps(payload).encode(), headers, method="POST")
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=70) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:  # the relay answers errors in its own shape too
        try:
            data = json.loads(exc.read().decode("utf-8"))
        except ValueError:
            data = {"status": f"http_{exc.code}", "reply": ""}
    except (urllib.error.URLError, TimeoutError, ValueError) as exc:
        data = {"status": "unreachable", "reply": f"{type(exc).__name__}: {exc}"}
    data["ms"] = round((time.monotonic() - started) * 1000)
    return data


RELAY = None  # the relay module, with --local


def load_relay(path: Path):
    """Imports a relay's main.py from `path`, after loading ai/.env, so an older
    copy kept elsewhere (to compare prompts) finds the same key."""
    import importlib.util
    from dotenv import load_dotenv
    load_dotenv(HERE.parent / ".env")
    spec = importlib.util.spec_from_file_location("relay_under_test", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def post_local(payload: dict) -> dict:
    """The relay in this process, through Flask's test client: a prompt as it is
    on disk, before it is deployed."""
    started = time.monotonic()
    with RELAY.app.test_client() as client:
        response = client.post("/api/hint", json=payload, headers={"X-UniCode-Token": RELAY.CLIENT_TOKEN})
    data = response.get_json(silent=True) or {"status": f"http_{response.status_code}", "reply": ""}
    data["ms"] = round((time.monotonic() - started) * 1000)
    return data


def ask(args, state: dict, session: str, message: str, history: list[dict]) -> dict:
    """One question, as the game sends it."""
    payload = {
        "session_id": session,
        "level_id": state["level_id"],
        "message": message,
        "history": history,
        "screenshot_jpeg_b64": state["pictures"]["now"],
        "start_screenshot_jpeg_b64": state["pictures"]["start"],
        "context": state["context"],
    }
    # The relay's own rate limit is waited out. "unavailable" (every model failed:
    # overloaded, out of quota, or no network) gets one more try only: the tests
    # share the live game's API quota, and retrying hard once used it up.
    tries = {"rate_limited": 3, "unavailable": 1}
    while True:
        data = post_local(payload) if args.local else post(args.url, args.token, payload)
        status = data.get("status")
        if tries.get(status, 0) <= 0:
            break
        tries[status] -= 1
        time.sleep(20 if status == "rate_limited" else 30)
    time.sleep(PAUSE_S)
    return data


def notes(reply: str, earlier: list[str]) -> list[str]:
    """Rough signs of a general reply, for skimming. Not verdicts."""
    found = []
    words = len(reply.split())
    if words > 80:
        found.append(f"{words} words")
    questions = reply.count("?")
    if questions != 1:
        found.append(f"{questions} questions")
    if not re.search(r"\d", reply):
        found.append("no number")
    generic = [p for p in GENERIC if p in reply.lower()]
    if generic:
        found.append("vague phrase: " + ", ".join(generic))
    if any(difflib.SequenceMatcher(None, b.lower(), reply.lower()).ratio() > 0.6 for b in earlier):
        found.append("much like an earlier reply")
    return found


def plan_requests(states: list[dict], questions: dict) -> list[tuple[dict, str, list[str]]]:
    """(state, kind, messages): one chat each, one message unless it's the chain."""
    plan = []
    for state in states:
        plan += [(state, "vague", [m]) for m in questions["vague"]]
        if state["id"] in questions["specific"]:
            plan.append((state, "specific", [questions["specific"][state["id"]]]))
        plan.append((state, "chain", questions["chain"]))
    return plan


def quote(text: str) -> str:
    return "\n".join("> " + line for line in (text.splitlines() or [""]))


def report(records: list[dict], states: list[dict], args) -> str:
    ok = [r for r in records if r["status"] in ("ok", "off_topic")]
    models = sorted({str(r["model"]) for r in ok})
    versions = sorted({str(r["prompt_version"]) for r in records if r["prompt_version"]})
    statuses = Counter(r["status"] for r in records)
    lines = [
        f"# Hint test: {args.label}",
        "",
        f"{datetime.now():%Y-%m-%d %H:%M}, relay `{args.url}`. "
        f"Models: {', '.join(models) or 'none'}. Prompt version: {', '.join(versions) or 'unknown'}.",
        "",
        "Replies: " + ", ".join(f"{n} {s}" for s, n in statuses.most_common()) + ".",
    ]
    if ok:
        avg_s = sum(r["ms"] for r in ok) / len(ok) / 1000
        avg_words = sum(len(r["reply"].split()) for r in ok) / len(ok)
        no_number = sum("no number" in r["notes"] for r in ok)
        vague = sum(any(n.startswith("vague phrase") for n in r["notes"]) for r in ok)
        repeats = sum("much like an earlier reply" in r["notes"] for r in ok)
        lines += [
            f"Average {avg_s:.1f} s and {avg_words:.0f} words a reply. {no_number} of {len(ok)} replies "
            f"have no number in them, {vague} use a vague phrase, and {repeats} chat replies are much "
            "like an earlier one in the same chat.",
        ]
    lines += ["", "The notes under each reply are rough signs for skimming, not verdicts: read the replies."]

    by_state: dict[str, list[dict]] = {}
    for r in records:
        by_state.setdefault(r["state"], []).append(r)
    headings = {"vague": "Vague questions", "specific": "A clear question", "chain": "A student who stays stuck"}
    for state in states:
        rows = by_state.get(state["id"], [])
        if not rows:
            continue
        ctx = state["context"]
        log = [line.strip() for line in ctx["output_log"].splitlines() if line.strip()]
        lines += [
            "", f"## {state['id']}", "",
            f"- **What the student got wrong** (not sent to the AI): {state['mistake']}",
            f"- **Last run:** {ctx['last_run']}",
            f"- **End of the log:** {' / '.join(log[-3:]) or '(empty)'}",
            f"- **Robot:** {ctx['robot']}",
        ]
        if ctx.get("lists"):
            lines.append(f"- **Lists:** {' / '.join(ctx['lists'].splitlines())}")
        kind = None
        for r in rows:
            if r["kind"] != kind or (r["kind"] == "chain" and r["turn"] == 1):
                lines += ["", f"### {headings[r['kind']]}", ""]
            kind = r["kind"]
            meta = f"{r['status']}, {r['model'] or '-'}, {r['ms'] / 1000:.1f} s"
            if r.get("hint_level"):
                meta += f", hint level {r['hint_level']}"
            if r["notes"]:
                meta += "; " + "; ".join(r["notes"])
            turn = f"{r['turn']}. " if r["kind"] == "chain" else ""
            lines += [f"{turn}**Student:** {r['message']}", "", quote(r["reply"]), "", f"*{meta}*", ""]
    return "\n".join(lines) + "\n"


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    url, token = relay_from_cfg()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", default=url, help="the relay's /api/hint (default: unicode_ai.cfg)")
    parser.add_argument("--token", default=token, help="X-UniCode-Token (default: unicode_ai.cfg)")
    parser.add_argument("--only", default="", help="only the states whose id contains this")
    parser.add_argument("--label", default="run", help="added to the result file names")
    parser.add_argument("--max", type=int, default=0, help="stop after this many requests (0: all)")
    parser.add_argument("--workers", type=int, default=4, help="states asked about at the same time")
    parser.add_argument("--local", action="store_true",
                        help="run ai/main.py in this process with its .env instead of calling a URL "
                             "(run with: uv run --directory ai python tests/run_hints.py --local)")
    parser.add_argument("--relay", type=Path, default=HERE.parent / "main.py",
                        help="with --local, the main.py to run, such as an older copy to compare prompts")
    parser.add_argument("--dry-run", action="store_true", help="list the requests and send nothing")
    args = parser.parse_args()
    if args.local:
        global RELAY
        RELAY = load_relay(args.relay)
        thinking = getattr(getattr(RELAY, "THINKING", None), "name", "?")
        args.url = (f"{args.relay.name} in this process: prompt {RELAY.PROMPT_VERSION}, "
                    f"models {', '.join(RELAY.MODELS)}, thinking {thinking}")

    questions = json.loads((HERE / "questions.json").read_text(encoding="utf-8"))
    states = load_states(args.only)
    plan = plan_requests(states, questions)
    total = sum(len(messages) for _, _, messages in plan)
    if args.max:
        total = min(total, args.max)
    print(f"{len(states)} states, {total} requests to {args.url}")
    if args.dry_run or not plan:
        for state, kind, messages in plan:
            print(f"  {state['id']:28} {kind:9} {' -> '.join(messages)}")
        return

    out = HERE / "results"
    out.mkdir(exist_ok=True)
    jsonl_path = out / f"{datetime.now():%Y-%m-%d_%H%M}_{args.label}.jsonl"
    records: list[dict] = []
    lock = threading.Lock()
    jsonl = jsonl_path.open("w", encoding="utf-8")
    failures = {"in_a_row": 0, "stopped": False}

    def chat(index: int, state: dict, kind: str, messages: list[str]) -> None:
        session = "hint-test-" + uuid.uuid4().hex[:12]  # a fresh chat, as after New chat
        history: list[dict] = []
        earlier: list[str] = []
        for turn, message in enumerate(messages, 1):
            with lock:
                if len(records) >= total or failures["stopped"]:
                    return
                records.append({})  # holds the place, so --max counts requests sent
                slot = len(records) - 1
            data = ask(args, state, session, message, history)
            reply = str(data.get("reply", ""))
            answered = data.get("status") in ("ok", "off_topic")
            record = {
                "state": state["id"], "kind": kind, "turn": turn, "message": message,
                "status": data.get("status"), "reply": reply, "model": data.get("model"),
                "hint_level": data.get("hint_level"),  # relays from 2026-11-05a on
                "prompt_version": data.get("prompt_version"), "ms": data.get("ms"),
                "notes": notes(reply, earlier) if answered else [], "order": (index, turn),
            }
            with lock:
                records[slot] = record
                jsonl.write(json.dumps(record, ensure_ascii=False) + "\n")
                jsonl.flush()
                done = sum(1 for r in records if r)
                print(f"[{done}/{total}] {state['id']} {kind} {turn}: {record['status']}, {record['ms']} ms", flush=True)
                failures["in_a_row"] = 0 if answered else failures["in_a_row"] + 1
                if failures["in_a_row"] >= STOP_AFTER_FAILURES and not failures["stopped"]:
                    failures["stopped"] = True
                    print(f"Stopping: {STOP_AFTER_FAILURES} requests in a row went unanswered "
                          f"(last: {record['status']}).", flush=True)
            if not answered:
                return  # the chat can't go on without a reply
            history += [{"role": "user", "text": message}, {"role": "model", "text": reply}]
            earlier.append(reply)

    # One worker per state at a time, so each state's chats run in order and the
    # relay sees a few students at once rather than a burst.
    by_state: dict[str, list] = {}
    for index, (state, kind, messages) in enumerate(plan):
        by_state.setdefault(state["id"], []).append((index, state, kind, messages))
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futures = [pool.submit(lambda chats=chats: [chat(*c) for c in chats]) for chats in by_state.values()]
        for future in futures:
            future.result()  # a worker's exception stops the run here instead of vanishing
    jsonl.close()
    records = sorted((r for r in records if r), key=lambda r: r["order"])
    if failures["stopped"]:
        args.label += f" (stopped early: {STOP_AFTER_FAILURES} unanswered in a row)"
    md_path = jsonl_path.with_suffix(".md")
    md_path.write_text(report(records, states, args), encoding="utf-8")
    print(f"Wrote {md_path}")


if __name__ == "__main__":
    main()
