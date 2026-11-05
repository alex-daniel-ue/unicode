"""Fills in each generated level's intended_solution and camera bounds.

    python tools/modules/finish_modules.py <project root> <godot exe>

Runs every "<ID> intended" harness case in yaml mode in one go and keeps the
serializer's output for each (the par, and the assistant's reference), then
measures every level with tools/bake_level.tscn, then reruns gen_modules.py
with both. Then puts the modules into the catalog (add_catalog.py).
"""
import json, os, re, subprocess, sys

root, godot = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
tmp = os.environ["TEMP"]
sys.path.insert(0, here)
from module_specs import MODULES  # noqa: E402


def run(args, timeout=1800):
    done = subprocess.run([godot, "--headless", "--path", root] + args, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=timeout)
    return done.stdout + done.stderr


specs = [s for m in MODULES for s in m["levels"]]
ids = {s["id"].upper() + " intended": s["key"] for s in specs}

out = run(["--fixed-fps", "60", "res://tools/level_checks.tscn", "--", "intended", "yaml"])
yamls = re.findall(r"^(# locked: true.*?)(?=^# locked: true|^\S*={5,}|\Z)", out, re.M | re.S)
results = re.findall(r"^(OK  |BAD ) (.+?) +-> (.*)$", out, re.M)
assert len(yamls) == len(results), "%d programs, %d results" % (len(yamls), len(results))
solutions = {}
for (status, title, got), yaml in zip(results, yamls):
    key = ids.get(title.strip())
    if key is None:
        continue
    if not got.startswith("PASS"):
        print(key, "intended program did not pass:", got)
        continue
    solutions[key] = "\n".join(line for line in yaml.strip().splitlines() if line.strip())

out = run(["res://tools/bake_level.tscn", "--"] + ["res://level/levels/%s.tscn" % s["key"] for s in specs])
bounds = {}
for path, data in re.findall(r"^BOUNDS_FOR (\S+) (.*)$", out, re.M):
    bounds[os.path.basename(path).split(".")[0]] = json.loads(data)
missing = [s["key"] for s in specs if s["key"] not in solutions or s["key"] not in bounds]
print("solutions %d, bounds %d, missing %s" % (len(solutions), len(bounds), ", ".join(missing) or "none"))

json.dump(solutions, open(os.path.join(tmp, "module_solutions.json"), "w"), indent=1)
json.dump(bounds, open(os.path.join(tmp, "module_bounds.json"), "w"), indent=1)
subprocess.run([sys.executable, os.path.join(here, "gen_modules.py"), root,
                os.path.join(tmp, "module_solutions.json"), os.path.join(tmp, "module_bounds.json")], check=True)
subprocess.run([sys.executable, os.path.join(here, "add_catalog.py"), root], check=True)
