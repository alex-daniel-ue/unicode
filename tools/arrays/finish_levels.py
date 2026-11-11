"""Fills in each Arrays level's intended_solution and camera bounds.

    python finish_levels.py <project root> <godot exe>

For each level: runs its "AR-n intended" harness case in yaml mode and keeps
the serializer's output, then measures the level with tools/bake_level.tscn.
Then reruns gen_arrays.py with both, so they land in the scenes. That rewrites
every Arrays scene, ar_11 included, which has been saved in the editor since.
"""
import json, os, re, subprocess, sys

root, godot = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
tmp = os.environ["TEMP"]
keys = ["ar_t2", "ar_t3"] + ["ar_%d" % n for n in (3, 4, 5, 6, 7, 8, 10, 11)]  # no ar_9: Tidy up was cut


def run(args):
    done = subprocess.run([godot, "--headless", "--path", root] + args, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=600)
    return done.stdout + done.stderr


solutions, bounds = {}, {}
for key in keys:
    n = key.split("_")[1].upper()  # "T2", "4": the harness calls the case "AR-T2 intended"
    out = run(["--fixed-fps", "60", "res://tools/level_checks.tscn", "--", "AR-%s intended" % n, "yaml"])
    result = re.search(r"^(OK  |BAD ) AR-%s intended\s+-> (.*)$" % n, out, re.M)
    yaml = re.search(r"^(# locked: true.*?)(?=^\S*={5,}|\Z)", out, re.M | re.S)
    if not result or not result.group(2).startswith("PASS") or not yaml:
        print(key, "intended program did not pass:", result.group(2) if result else "no result")
        continue
    solutions[key] = "\n".join(line for line in yaml.group(1).strip().splitlines() if line.strip())
    out = run(["res://tools/bake_level.tscn", "--", "res://level/levels/%s.tscn" % key])
    found = re.search(r"^BOUNDS (.*)$", out, re.M)
    bounds[key] = json.loads(found.group(1)) if found else {}
    print(key, "solution %d lines, bounds %s" % (len(solutions[key].splitlines()), bounds[key].get("level")))

json.dump(solutions, open(os.path.join(tmp, "ar_solutions.json"), "w"), indent=1)
json.dump(bounds, open(os.path.join(tmp, "ar_bounds_all.json"), "w"), indent=1)
subprocess.run([sys.executable, os.path.join(here, "gen_arrays.py"), root,
                os.path.join(tmp, "ar_solutions.json"), os.path.join(tmp, "ar_bounds_all.json")], check=True)
