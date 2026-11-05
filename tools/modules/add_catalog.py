"""Puts the generated modules into global/utils/level_catalog.tres, from the
module_catalog.json gen_modules.py writes to %TEMP%. Safe to rerun: a module
already in the catalog is replaced, not added twice.

    python tools/modules/add_catalog.py <project root>

Each module goes after the module its spec names in `after`, so the grid's
order follows the course: Tutorial, Input and Output, Values and Variables,
Operators and Expressions, Selection, Iteration, Functions, Arrays,
Dictionaries, Text Files.

Their levels don't count for progress (counts_for_progress = false): the
progress code holds 20 levels, and Iteration and Arrays use all 20. Stars are
kept on this computer, as the Tutorial's are. Scoring them needs a new code
format (see the README's Known pitfalls).
"""
import json, os, re, sys

root = sys.argv[1]


def tres(text):
    """Text as a .tres string writes it: a backslash and a quote escaped."""
    return text.replace("\\", "\\\\").replace('"', '\\"')


path = os.path.join(root, "global/utils/level_catalog.tres")
modules = json.load(open(os.path.join(os.environ.get("TEMP", "."), "module_catalog.json")))
s = open(path, encoding="utf-8").read()

for m in modules:
    tag = "gen_%s" % m["id"]
    # Out with any earlier copy of this module: its scenes, entries and module.
    s = re.sub(r'\[ext_resource type="PackedScene" path="res://level/levels/[^"]+" id="%s_[^"]+"\]\n' % tag, "", s)
    # A sub_resource runs until the next line that starts with "[".
    s = re.sub(r'(?m)^\[sub_resource type="Resource" id="%s(?:_[^"]+)?"\]\n(?:(?!\[).*\n)*' % tag, "", s)
    s = s.replace('SubResource("%s"), ' % tag, "").replace(', SubResource("%s")' % tag, "")

    ext = "".join('[ext_resource type="PackedScene" path="res://level/levels/%s.tscn" id="%s_%s"]\n' % (lv["key"], tag, lv["key"]) for lv in m["levels"])
    first_sub = s.index("\n[sub_resource")
    s = s[:first_sub] + "\n" + ext.rstrip("\n") + s[first_sub:]

    subs = []
    for lv in m["levels"]:
        subs.append('[sub_resource type="Resource" id="%s_%s"]\nscript = ExtResource("2_level_entry")\nid = &"%s"\nlabel = "%s"\ntitle = "%s"\nconcept = "%s"\nscene = ExtResource("%s_%s")\ncounts_for_progress = false\nmetadata/_custom_type_script = "uid://copysdfiq2iil"\n'
                    % (tag, lv["key"], lv["id"], lv["label"], tres(lv["title"]), tres(lv["concept"]), tag, lv["key"]))
    subs.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("1_level_module")\nid = &"%s"\ndisplay_name = "%s"\nsubtitle = "%s"\nlevels = Array[ExtResource("2_level_entry")]([%s])\nmetadata/_custom_type_script = "uid://bosuufgg1ovh8"\n'
                % (tag, m["id"], m["name"], m["subtitle"], ", ".join('SubResource("%s_%s")' % (tag, lv["key"]) for lv in m["levels"])))
    resource_at = s.index("\n[resource]")
    s = s[:resource_at] + "\n" + "\n".join(subs) + s[resource_at:]

    # Into the module list, after the module it follows.
    modules_line = re.search(r"modules = Array\[ExtResource\(\"1_level_module\"\)\]\(\[(.*)\]\)", s)
    refs = [r.strip() for r in modules_line.group(1).split(",") if r.strip()]
    ids = {}
    for ref in refs:
        rid = re.search(r'SubResource\("([^"]+)"\)', ref).group(1)
        block = re.search(r'\[sub_resource type="Resource" id="%s"\]\n(?:.*\n)*?id = &"([^"]+)"' % re.escape(rid), s)
        ids[block.group(1)] = ref
    after = ids.get(m["after"])
    new_ref = 'SubResource("%s")' % tag
    position = refs.index(after) + 1 if after in refs else len(refs)
    refs.insert(position, new_ref)
    s = s[:modules_line.start(1)] + ", ".join(refs) + s[modules_line.end(1):]

steps = s.count("[ext_resource") + s.count("[sub_resource") + 1
s = re.sub(r"load_steps=\d+", "load_steps=%d" % steps, s, count=1)
open(path, "w", encoding="utf-8", newline="\n").write(s)
print("catalog: %s" % ", ".join(m["id"] for m in modules))
