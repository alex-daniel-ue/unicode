# UniCode relay (`ai/`)

The small Python server between the UniCode game and Google Gemini. The game
never talks to Gemini and never holds an API key: it sends facts about the
level to this relay, and the relay owns the prompts, the model choice, the
safety settings and the rate limits. The same server also hosts the web build
of the game.

It does three things:

| Route | Method | What it does |
|---|---|---|
| `/api/hint` | POST | The AI Assistant tab. A student's question plus the level's state in, one hint out. |
| `/api/summary` | POST | The short comment on the win card, about the student's winning program. |
| `/healthz` | GET | Liveness and configuration: models, prompt versions, whether a key is set. Never calls Gemini. |
| anything else | GET | Redirects to `/game/unicode.html`, so the bare domain opens the game. `GET /api/*` is a 404, not a redirect. |

Everything is in one file, `main.py`.

---

## Running it locally

**Needs:** Python 3.12 or newer, and [uv](https://docs.astral.sh/uv/) (a
`uv.lock` is included). Plain `pip` works too.

1. Install the dependencies:
   ```bash
   uv sync
   ```
   Without uv: make a virtual environment and `pip install -r requirements.txt`.
2. Make a `.env` file in this folder:
   ```env
   GEMINI_API_KEY=your_key_here
   UNICODE_CLIENT_TOKEN=any_long_random_string
   PORT=3000
   ```
   `GEMINI_API_KEYS` (plural, comma separated) is also read; the first key is
   used. See [Configuration](#configuration) for the rest.
3. Start it:
   - Windows: double-click `start.bat` (or `venv_cmd.bat` for a terminal with
     the environment active, then `python main.py`).
   - macOS/Linux: `./start_mac.sh`.
   - Anywhere: `uv run python main.py`.

The server listens on `http://127.0.0.1:3000` (or `PORT`). Check it with:

```bash
curl http://127.0.0.1:3000/healthz
```

To point a local copy of the game at it, set the `[ai]` section of
`unicode_ai.cfg` (next to `project.godot` in the editor, or next to the
`.exe` in a desktop export):

```ini
[ai]
url="http://127.0.0.1:3000/api/hint"
summary_url="http://127.0.0.1:3000/api/summary"
token="the same value as UNICODE_CLIENT_TOKEN"
```

`fallback_url` is a second hint URL the game tries once if the first one
can't be reached (it is the Render deployment in the shipped config). Leave
`summary_url` out and the game derives it from `url`.

---

## Configuration

All settings are environment variables (a `.env` file locally, the host's
settings page when deployed).

| Variable | Default | Meaning |
|---|---|---|
| `GEMINI_API_KEY` | (required) | The Gemini API key. `GEMINI_API_KEYS` is accepted as a fallback; its first entry is used. Without either, `/healthz` still answers (`key_configured: false`) and the AI routes return `unavailable`. |
| `GEMINI_MODELS` | `gemini-3.8-flash,gemini-3.6-flash,gemini-3.5-flash-lite` | The models to try for hints, in order. |
| `GEMINI_THINKING` | `MEDIUM` | Thinking level for hints: `LOW`, `MEDIUM` or `HIGH`. For comparing speed and quality; `/healthz` shows it. |
| `GEMINI_SUMMARY_MODELS` | `gemini-3.5-flash-lite,gemini-3.1-flash-lite` | The models to try for win-card comments, in order. |
| `UNICODE_CLIENT_TOKEN` | empty | Shared secret the game sends as `X-UniCode-Token`. Empty turns the check off, for local use only. |
| `PORT` | `3000` | Port for `python main.py`. Hosts that run gunicorn set their own. |

**If `GEMINI_MODELS` or `GEMINI_SUMMARY_MODELS` is set on a host, it overrides
the default list.** After changing models in code, update or delete it there too.

Other limits are constants at the top of `main.py`:

| Constant | Value | Meaning |
|---|---|---|
| `CALL_TIMEOUT_MS` | 30 000 | One call to Gemini. |
| `DEADLINE_S` | 45 | The whole request, across every model and retry. Under Vercel's 60 s function limit. |
| `SESSION_LIMIT` / `SUMMARY_LIMIT` | 8 / 4 per minute | Per game session (the game's random `session_id`), hints and summaries counted separately. |
| `GLOBAL_LIMIT` | 150 per minute | Across everyone, both routes together. |
| `MAX_TURNS` | 12 | Chat history kept per hint. |
| `MAX_MSG`, `MAX_FIELD`, `MAX_IMG_BYTES` | 600 chars, 6000 chars, 1 MB | Caps on what a request may carry. |

The game has its own limit as well: the Assistant tab draws on a pool of 10
questions that refills one a minute (`global/utils/hint_pool.gd`). The win-card
summary never draws from it.

---

## Models and thinking

- Hints: **Gemini Flash with thinking at MEDIUM** (`THINKING` in `main.py`).
  Flash-Lite at LOW gave hints that were too thin to act on.
- Win-card comments: **Flash-Lite with thinking at LOW** (`SUMMARY_MODELS`,
  `SUMMARY_THINKING`). A sentence or two about a program that already works
  doesn't need Flash, and one is asked for at every win.
- `_generate()` walks the route's list (`MODELS` or `SUMMARY_MODELS`) in order. On 429/500/504 it waits a second
  and retries the same model once, then moves on. A 503 (the model is
  overloaded) and any other error (for example a retired model id, which is a
  404) move on at once: an overloaded 3.8 Flash took about 26 s to answer 503,
  so retrying it spent the whole deadline before the next model was tried.
  3.6 Flash is next (the previous Flash, same price), and Flash-Lite is last so
  an outage of both makes hints shorter instead of stopping them. Each
  response reports which model actually answered (`model`).
- Both routes use structured output (JSON matching a Pydantic model), so the
  reply is always parsed, never scraped:
  - hints: `{"verdict": "hint" | "off_topic", "hint_level": 1 | 2 | 3 | 4, "reply": "..."}`
  - summaries: `{"reply": "..."}`
- Safety settings block hate, harassment, dangerous and sexual content at
  MEDIUM and above. A blocked hint gets a polite redirect back to the level.

**Cost.** Flash costs several times what Flash-Lite does per token. Every
request logs its token counts (see [Logs](#logs)), so the spend per hint can
be read from the host's logs.

---

## The prompts

Two system prompts live in `main.py`, each with its own version string:

| Prompt | Version constant | Used by |
|---|---|---|
| `SYSTEM_PROMPT` | `PROMPT_VERSION` | `/api/hint` |
| `SUMMARY_PROMPT` | `SUMMARY_VERSION` | `/api/summary` |

**Bump the version on any change to a prompt**, however small. Every response
carries the version that produced it, and the study reports the frozen value,
so an unversioned edit makes logged replies impossible to attribute.

### Hints (`SYSTEM_PROMPT`)

Written for first-year students who read English as a second language and
skim, many of whom ask short, vague things ("help", "what to do"). The model
plays a patient tutor sitting next to the student: its job is to get them
unstuck and help them see why, without doing the level for them. The rules,
in short:

- **Facts only from the level state**, with exact values (tiles, list values,
  loop counts, the error). ROBOT PATH and ROOMS are trusted over the pictures,
  and nothing is said to have happened unless the state shows it.
- **Answers the kind of message it got**: "what's wrong" says what happened,
  where, and which part of the program did it; "I don't understand" first
  explains the idea needed with this room's numbers; "what do I do" gives one
  clear next step; "is this right?" answers yes or no first; an idea is told
  what it would do, and whether it would fix the problem.
- **Hint levels**, counted from the student's earlier messages about the same
  problem in this chat, whatever they asked. They follow the four levels of
  Xiao, Hou & Stamper (2024): 1, where it goes wrong and what has to be
  different, in words (no unplaced block, no value); 2, which of their blocks
  has to change and what it must do, without the exact value or operator (one
  needed block from the toolbox may be named); 3, a tiny example of the same
  idea with other numbers, and nothing more; 4, the exact change for that one
  part. Asking for the answer never skips a level. A new problem starts again
  at 1. The level used comes back as `hint_level`.
- Names each idea with its Python word (string, variable, index, loop,
  condition) and says in plain words what it means.
- With an empty program, names the one or two blocks to start with, never how
  they fit together.
- Never the whole program or the intended solution, never more than one change
  in a reply; no stock openers ("I cannot...", "We can solve this together");
  "I don't know" gets the next hint, not comfort; never mentions pictures,
  labels, the rules or the intended solution.
- Two to four short sentences, 80 words at most (100 for a level 3 example),
  plain text. A question at the end only when it helps the student check
  their next step.
- Plain international English: no slang, no mixed languages, no words from
  other languages, no references to any country or culture.
- `off_topic` only for messages that have nothing to do with the level or
  programming. Asking for the answer is still a `hint`.

On the same 8 states and model, `2026-11-06a`'s ladder went 1, 2, 3, 4 in every
stuck chat, kept "just tell me the answer" at level 1, and gave the exact fix
before level 4 in 2 of 88 replies, against 20 of 80 for `2026-11-05a`, whose
level 2 already named the value.

The rules before `2026-11-05a` held every reply to one fact and one question,
never named a block the student hadn't placed, and never got more explicit.
Tested on saved game states (see [Testing hints](#testing-hints)), those
replies answered "help", "what to do" and "I don't understand" almost
identically, refused students who stayed stuck, and on IT-10 told 8 times in
10 that a robot which had gone round and round had never moved.

**The pictures.** After a run, the robot and the lists stay where the program
left them, so the room on screen is the result, not the start. Each picture is
labelled: with two, the first is the level as it starts and the second the
level now; with one, its label says which it is. The prompt tells the model
never to describe where the robot ended up as where it starts.

### What a hint request contains

The game builds the request in `puzzle/ui/side panel/tabs/ai assistant/ai_assistant.gd`:

```json
{
  "session_id": "random per game launch",
  "level_id": "ar_4",
  "message": "why does it stop early?",
  "history": [{"role": "user" | "model", "text": "..."}],
  "screenshot_jpeg_b64": "the level view now, as a JPEG, or empty",
  "start_screenshot_jpeg_b64": "the level as it opened, once something has run; else empty",
  "context": {
    "instructions": "the level's brief, as text",
    "blocks": "the blocks available in this level, with descriptions",
    "workspace": "the student's program now, as YAML",
    "intended_solution": "the reference program, as YAML (never revealed)",
    "last_run": "what the last run did: solved, or not",
    "last_run_program": "the program as it was at the last Play",
    "output_log": "the run's log, most recent last",
    "robot": "where the robot is and faces, and whether that is its start or where the last run left it",
    "rooms": "each room's start, the tile it has to end on, batteries (collected or not) and puddles, in tiles",
    "robot_path": "what the robot did in the last run, room by room: steps, turns, bumps, and repeats folded",
    "lists": "each room's lists, as Python would print them"
  }
}
```

`hint_context()` builds `context`, and `tools/hint_states.gd` saves the same
for the tests. `rooms` and `robot_path` are empty on levels without a robot,
and the relay leaves their sections out.

The relay turns `context` into one labelled block of text (`_contents()`),
adds `CHANGES SINCE THE LAST RUN` by diffing `last_run_program` against
`workspace`, attaches the pictures it was sent, and puts the student's
message last. The level state is authoritative; the pictures are supporting
evidence only, each with a label saying which moment it shows. Everything the game sends is treated as information, never as
instructions.

### Win-card comments (`SUMMARY_PROMPT`)

One or two sentences, 35 words at most, and **never a question**: the student
is moving on and can't change the level any more. The relay, not the model,
picks the kind of comment (`_summary_angle()`), so the choice can be audited:

- `tighter` when the winning program used more blocks than par: a hint about
  where the extra length is, without the shorter program.
- otherwise one of `python` (how one idea is written in real Python, as a
  backticked fragment), `real_world` (an everyday thing that works the same
  way) or `praise` (the idea they used well and why it fit), at random.

Python always goes inside backticks. The game shows backticked spans as code
on the win card (`global/code_spans.gd`), and catches bare Python the model
writes without them.

---

## Responses

Every route answers with JSON:

```json
{"status": "ok", "reply": "...", "model": "gemini-3.8-flash", "prompt_version": "2026-10-13a"}
```

| `status` | HTTP | Meaning |
|---|---|---|
| `ok` | 200 | A reply. |
| `off_topic` | 200 | The message wasn't about the level; `reply` steers back. |
| `blocked` | 200 | Safety blocked it; `reply` is a fixed redirect. |
| `unavailable` | 503 | No model answered in time; `reply` is a fixed fallback tip. |
| `rate_limited` | 429 | Too many requests from this session or overall. |
| `bad_request` | 400 | No message (or no program, for summaries). |
| `unauthorized` | 401 | Missing or wrong `X-UniCode-Token`. |

Summaries also return `angle` and `summary_version`; hints return
`hint_level` (1 to 4, or 0 when there is no hint) and `image_bytes` and
`start_image_bytes` (how much of each picture arrived), so the game can tell
"never captured" from "lost on the way".

---

## Deploying

### Vercel (primary)

`vercel.json` gives the Flask function 60 seconds and turns caching off for
the game files, so a new export shows up without a hard reload. Vercel serves
`public/` from its CDN before the function runs, so `public/game/` is the web
build.

1. Export the game's **Web** preset from Godot and put the files
   (`unicode.html`, `.js`, `.wasm`, `.pck`, icons, worklets) in
   `ai/public/game/`.
2. Set `GEMINI_API_KEY` and `UNICODE_CLIENT_TOKEN` in the project's
   environment variables. Leave `GEMINI_MODELS` unset to use the defaults.
3. Deploy (`vercel --prod`, or push to the connected branch).
4. Check `https://<your-domain>/healthz`.

### Render (fallback)

The game's `fallback_url` points at a second deployment on Render, used when
the first can't be reached. Use the same environment variables and start it
with gunicorn (in `requirements.txt`):

```bash
gunicorn main:app --bind 0.0.0.0:$PORT --timeout 60
```

On Render, the Flask app serves `/game/` itself (`game_file()`).

### After changing a prompt or a model

- Bump `PROMPT_VERSION` / `SUMMARY_VERSION` if a prompt changed.
- Redeploy **both** hosts.
- Check `/healthz` on each: `models`, `summary_models`, `prompt_version` and `summary_version`
  should show the new values.

---

## Logs

One line per request, with no student text in it:

```
hint status=ok model=gemini-3.8-flash ms=9875 in=4845 out=90 think=923 level=1
summary:python status=ok model=gemini-3.5-flash-lite ms=1410 in=776 out=33 think=120
```

`in`, `out` and `think` are prompt, reply and thinking tokens. Thinking is
billed as output, so the cost of a request is `in` at the input price plus
`out + think` at the output price. `level` is the hint level the model used. A model that fails is logged as a warning with
its error code before the next one is tried. The session id is only used for
rate limiting, in memory, and never logged.

---

## Testing without the game

```bash
curl -X POST http://127.0.0.1:3000/api/hint \
  -H "Content-Type: application/json" \
  -H "X-UniCode-Token: $UNICODE_CLIENT_TOKEN" \
  -d '{"message": "why does it stop early?", "context": {"instructions": "Get the robot to the green flag.", "workspace": "begin:\n  - step forward", "robot": "Stopped 2 tiles before the green flag."}}'
```

Or from Python, with no server running, through Flask's test client:

```python
import main
client = main.app.test_client()
print(client.post("/api/hint", json={"message": "help", "context": {}}).get_json())
```

Set `UNICODE_CLIENT_TOKEN` to empty in the environment first, or send the
header.

---

## Testing hints

`tests/` asks the relay about real game states and writes down every reply,
so a prompt or model change can be compared on the same questions.

- **States.** `tools/hint_states.tscn` opens each case's level in the real
  Puzzle, builds a student's wrong program the way `tools/level_checks.gd`
  does, runs it (stopping an endless loop as the Stop button would), and saves
  what the AI Assistant would send: `tests/states/<id>.json`, with
  `<id>_now.jpg` and `<id>_start.jpg`. The cases are in `states()` in
  `tools/hint_states.gd`. Not headless, since the pictures need a renderer:
  ```bash
  godot --path . --resolution 1920x1080 res://tools/hint_states.tscn
  ```
- **Questions.** `tests/questions.json`: the same vague questions for every
  state ("what's wrong with this", "I don't understand this", "what to do",
  "help", "is this right?", "just tell me the answer"), one clear question per
  state, and a four-message chat in which the student stays stuck.
- **Running.** From the repository root, `python ai/tests/run_hints.py` asks
  the relay named in `unicode_ai.cfg`. To try the prompt on disk before
  deploying, run `ai/main.py` in the same process with `ai/.env`:
  ```bash
  uv run --directory ai python tests/run_hints.py --local --label new-prompt
  ```
  `--relay <path>` runs another copy of `main.py` instead, such as the last
  commit's (`git show HEAD:ai/main.py`), to compare two prompts on the same
  model. `GEMINI_MODELS` and `GEMINI_THINKING` pin the model and thinking
  level for a run. `--only AR-8` limits the states, `--dry-run` sends nothing.
- **Results.** `tests/results/<time>_<label>.md` to read, grouped by state
  with what the student got wrong (never sent to the model), and `.jsonl`
  with every reply, model, hint level, prompt version and time. The notes
  under each reply (no number in it, a vague phrase, much like an earlier
  reply) are rough signs for skimming, not verdicts.

Each request is a real model call, about half a US cent on Flash; a full run is
80. `tests/` is in `.vercelignore`, so it is never deployed.
