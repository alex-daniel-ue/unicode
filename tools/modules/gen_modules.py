"""Writes the levels of the modules around Iteration and Arrays, from the specs
in module_specs.py: Input and Output, Values and Variables, Operators and
Expressions, Selection, Functions, Dictionaries and Text Files.

    python tools/modules/gen_modules.py <project root> [solutions.json] [bounds.json]

It paints rooms with the Arrays generator's painter and clutter (gen_arrays.py,
imported), so the rooms look like the rest of the game, and adds what those
modules need: a terminal standing in each room (TerminalEntity) with its typed
lines and the lines it should show, signs on the floor, and more than three
rooms. Besides the scenes it writes:

  level/module_briefs.gd         every level's brief, for LevelBriefs
  tools/modules/cases.json       each level's intended program and the wrong
                                 ones it is built to catch, for level_checks
  %TEMP%/module_catalog.json     the catalog entries, for add_catalog.py

finish_modules.py runs the intended programs for their YAML (the par, and the
assistant's reference) and bake_level for the bounds, then reruns this with both.
"""
import json, math, os, sys

ROOT = sys.argv[1]
SOLUTIONS = json.load(open(sys.argv[2])) if len(sys.argv) > 2 and os.path.exists(sys.argv[2]) else {}
BOUNDS = json.load(open(sys.argv[3])) if len(sys.argv) > 3 and os.path.exists(sys.argv[3]) else {}
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "arrays"))
_argv = sys.argv
sys.argv = [_argv[0], ROOT]  # gen_arrays reads its own argv when imported
import gen_arrays as g  # noqa: E402
sys.argv = _argv
from module_rooms import T, terminal_px, band_rows, floor_tiles, boards_px, dict_px, file_px, py_repr  # noqa: E402
from module_specs import MODULES, BLK  # noqa: E402

WALL_ROWS = 2
GAP = 1


def block(room):
    """One room's tiles and where its parts go, in pixels from its block's
    top-left (the left wall column, at the top of the wall)."""
    room.setdefault("dicts", [])
    room.setdefault("files", [])
    robot_rows = room["walk_h"] if room["robot"] else 0
    band = band_rows(room)
    extra = 1 if band and not room["robot"] else 0
    h = max(robot_rows + band + extra, 1)
    tw = boards_px(room)[0]
    width_px = max(T + room["walk_w"] * T, T + 8 + tw + 8)
    w = max(room["walk_w"], math.ceil((width_px - T) / T), 3)
    reserved = {(x, robot_rows + r) for x in range(w) for r in range(band)}
    for (tile, _text) in room["signs"]:
        reserved.add(tile)
        reserved.add((tile[0] + 1, tile[1]))
    return dict(room=room, w=w, h=h, board_tiles=reserved,
                term_at=(T + 8, (WALL_ROWS + robot_rows) * T + 6),
                dict_at=[(T + 8 + (terminal_px(room["terminal"])[0] + 12 if room["terminal"] else 0)
                          + sum(dict_px(d)[0] + 12 for d in room["dicts"][:i]), (WALL_ROWS + robot_rows) * T + 6)
                         for i in range(len(room["dicts"]))],
                file_at=[(T + 8 + (terminal_px(room["terminal"])[0] + 12 if room["terminal"] else 0)
                          + sum(dict_px(d)[0] + 12 for d in room["dicts"])
                          + sum(file_px(f)[0] + 12 for f in room["files"][:i]), (WALL_ROWS + robot_rows) * T + 6)
                         for i in range(len(room["files"]))],
                tiles=(w + 2, WALL_ROWS + h + 1))


def arrange(blocks, columns):
    """Tile offsets of each block, `columns` to a row, and the level's size."""
    at, y, total_w = {}, 0, 0
    for row_start in range(0, len(blocks), columns):
        row = list(range(row_start, min(row_start + columns, len(blocks))))
        x, depth = 0, 0
        for i in row:
            bw, bh = blocks[i]["tiles"]
            at[i] = (x, y)
            x += bw + GAP
            depth = max(depth, bh)
        total_w = max(total_w, x - GAP)
        y += depth + GAP
    return at, (total_w, y - GAP)


def layout(spec):
    blocks = [block(room) for room in spec["rooms"]]
    tried = []
    for columns in ([1, 2] if len(blocks) >= 4 else [1]):
        at, size = arrange(blocks, columns)
        tried.append((g.zoom(size), columns, at, size))
    best = max(tried, key=lambda t: t[0])
    return blocks, best


def esc(text):
    return g.esc(text)


def packed(strings):
    return g.packed(strings)


def build(spec):
    key = spec["key"]
    ext, ext_ids = [], {}

    def res(kind, path, uid=None):
        if path not in ext_ids:
            ext_ids[path] = "%d_%s" % (len(ext) + 1, os.path.basename(path).split(".")[0][:12].replace(" ", "_"))
            u = ' uid="%s"' % uid if uid else ""
            ext.append('[ext_resource type="%s"%s path="%s" id="%s"]' % (kind, u, path, ext_ids[path]))
        return 'ExtResource("%s")' % ext_ids[path]

    LEVEL = res("PackedScene", "res://level/level.tscn", "uid://kyh2mtywp5j8")
    FURNITURE = res("TileSet", "res://world/tilesets/school_chairs.tres", "uid://dwdeg5l2ik0ee")
    THEME = res("Theme", "res://puzzle/ui/themes/main_theme.tres", "uid://dndk60sn664bq")
    DATA = res("Script", "res://puzzle/ui/block/data/block_data.gd", "uid://dbo3fa8pswxeg")
    MGR = res("Script", "res://level/goal_manager.gd", "uid://dih2mwqkdmcfd")
    FLOOR = res("TileSet", "res://world/tilesets/school_tiles.tres", "uid://b41gvomjqm625")
    WALLS = res("TileSet", "res://world/tilesets/school_walls.tres", "uid://ci0tufhkgt2lv")
    rooms = spec["rooms"]
    has_robot = any(r["robot"] for r in rooms)
    has_terminal = any(r["terminal"] for r in rooms)
    has_dicts = any(r.get("dicts") for r in rooms)
    has_files = any(r.get("files") for r in rooms)
    if has_files:
        FILE = res("PackedScene", "res://level/objects/entities/file/file_entity.tscn")
        FGOAL = res("Script", "res://level/goals/file_goal.gd")
    if has_dicts:
        DICT = res("PackedScene", "res://level/objects/entities/dict/dict_entity.tscn")
        DGOAL = res("Script", "res://level/goals/dict_goal.gd")
    if has_terminal:
        TERMINAL = res("PackedScene", "res://level/objects/entities/terminal/terminal_entity.tscn")
        TGOAL = res("Script", "res://level/goals/terminal_goal.gd")
    if has_robot:
        DEST = res("Script", "res://level/goals/destination_goal.gd", "uid://q6bakhqg0ln6")
        CHECK = res("Script", "res://level/goals/checkpoint_goal.gd", "uid://dpdkg6h24nyxe")
        SENSED = res("Script", "res://level/goals/sensed_area.gd", "uid://o1ylv1wr01a7")
        FLAG = res("Texture2D", "res://level/objects/green_flag.png", "uid://b3ebyhau47md8")
        PEN = res("Texture2D", "res://world/assets/objects/battery.png", "uid://cetefcnjyhden")
        ROBOT = res("PackedScene", "res://level/objects/entities/robot/robot_character.tscn", "uid://cmxfefkbr2y3a")
        RESET = res("Script", "res://level/components/resettable_component.gd", "uid://b7gqcxxy3e2bv")
        FRAMES = res("SpriteFrames", "res://level/objects/entities/robot/sprite_frames.tres", "uid://bbra16dnqb2nc")
    blk = lambda k: res("Resource", BLK[k])

    blocks, (zoom, columns, at, size) = layout(spec)
    walls, floor, furniture = {}, {}, {}
    placed = []
    for k, b in enumerate(blocks):
        room = b["room"]
        ox, oy = at[k]
        x0, y0 = ox + 1, oy + WALL_ROWS
        g.paint_room(walls, floor, x0, y0, b["w"], b["h"])
        cb = dict(b)
        if not room["robot"]:
            cb["room"] = dict(room, robot=None)
        for (cx, cy), cell in g.clutter(cb, "%s-%d" % (key, k)).items():
            furniture[(x0 + cx, y0 + cy)] = cell
        tile = lambda t: (x0 + t[0], y0 + t[1])
        p = dict(label=((x0 * 2 + b["w"]) * T // 2 - 26, (y0 + b["h"]) * T + 4),
                 term_at=(ox * T + b["term_at"][0], oy * T + b["term_at"][1]),
                 dict_at=[(ox * T + x, oy * T + y) for x, y in b["dict_at"]],
                 file_at=[(ox * T + x, oy * T + y) for x, y in b["file_at"]],
                 signs=[(tile(t), text) for t, text in room["signs"]])
        if room["robot"]:
            r = room["robot"]
            p.update(start=tile(r["start"]), flag=tile(r["flag"]), pens=[tile(q) for q in r["pens"]])
        placed.append(p)

    subs = []
    if has_robot:
        subs.append('[sub_resource type="CircleShape2D" id="Circle_1"]\nradius = 12.0\n')
    out = []
    add = out.append
    managers = ["GoalManager"] + ["GoalManagerRoom%d" % (k + 1) for k in range(1, len(rooms))]
    add('[node name="%s" node_paths=PackedStringArray("room_goals") instance=%s]\n' % (spec["root"], LEVEL))
    add('intended_solution = "%s"\n' % esc(SOLUTIONS.get(key, "")))
    add('room_goals = [%s]\n' % ", ".join('NodePath("RoomGoals/%s")' % m for m in managers))
    if spec.get("star_slack", 1) != 1:
        add("star_slack = %d\n" % spec["star_slack"])
    if spec.get("par"):
        add("star_par_override = %d\n" % spec["par"])
    add("\n")

    add('[node name="LevelDescription" parent="." index="0"]\n')
    add('title = "%s"\nmission = "%s"\n' % (esc(spec["title"]), esc(spec["mission"])))
    if spec["rooms_text"]:
        add("rooms = %s\n" % packed(spec["rooms_text"]))
    if spec["twist"]:
        add('twist = "%s"\n' % esc(spec["twist"]))
    if spec["blocks"]:
        add("blocks = Array[%s]([%s])\n" % (DATA, ", ".join(blk(x) for x in spec["blocks"])))
        add("block_notes = %s\n" % packed(spec["notes"]))
        if spec.get("block_values"):
            add("block_values = %s\n" % packed(spec["block_values"]))
    add('tip = "%s"\n' % esc(spec["tip"]))
    add("\n")

    if spec.get("preset"):
        add('[node name="LevelBlockPreset" parent="." index="1"]\n')
        if spec.get("immovable"):
            add("immovable = true\n")
        add('program = "%s"\n\n' % esc(json.dumps(spec["preset"])))

    add('[node name="GenericBlockProvider" parent="." index="2"]\n')
    add("block_data = Array[%s]([%s])\n\n" % (DATA, ", ".join(blk(x) for x in spec["toolbox"])))

    if spec.get("functions"):
        # The level's functions: their define blocks go on the canvas, their
        # call blocks into the Toolbox (FunctionDefinitions).
        FUNCS = res("Script", "res://level/function_definitions.gd")
        add('[node name="Functions" type="Node" parent="."]\nscript = %s\nfunctions = "%s"\n\n' % (FUNCS, esc(json.dumps(spec["functions"]))))

    for k, (room, p) in enumerate(zip(rooms, placed)):
        mgr = managers[k]
        n = k + 1
        if k == 0:
            add('[node name="GoalManager" parent="RoomGoals" index="0" node_paths=PackedStringArray("focus_markers")]\n')
        else:
            add('[node name="%s" type="Node" parent="RoomGoals" index="%d" node_paths=PackedStringArray("focus_markers")]\n' % (mgr, k))
            add("script = %s\n" % MGR)
        bounds = BOUNDS.get(key, {}).get(mgr)
        if bounds:
            add("bounds = Rect2(%s, %s, %s, %s)\n" % tuple(bounds))
        markers = []
        if room["terminal"]:
            markers.append('NodePath("../../Visuals/Terminals/Room%d")' % n)
        if room.get("dicts"):
            markers.append('NodePath("../../Visuals/Dicts/Room%d")' % n)
        if room.get("files"):
            markers.append('NodePath("../../Visuals/Files/Room%d")' % n)
        if room["robot"]:
            markers.append('NodePath("../../Visuals/Destination%d")' % n)
        add("focus_markers = [%s]\n\n" % ", ".join(markers))
        index = 0
        if room["terminal"] and room["terminal"]["expected"] is not None:
            add('[node name="TerminalGoal" type="Node" parent="RoomGoals/%s" index="%d" node_paths=PackedStringArray("terminal")]\n' % (mgr, index))
            add("script = %s\n" % TGOAL)
            add('terminal = NodePath("../../../Visuals/Terminals/Room%d/Terminal")\n' % n)
            add("expected = %s\n\n" % packed(room["terminal"]["expected"]))
            index += 1
        for d in room.get("dicts", []):
            if d["expected"] is None:
                continue
            add('[node name="%sGoal" type="Node" parent="RoomGoals/%s" index="%d" node_paths=PackedStringArray("board")]\n' % (d["name"].title().replace("_", ""), mgr, index))
            add("script = %s\n" % DGOAL)
            add('board = NodePath("../../../Visuals/Dicts/Room%d/%s")\n' % (n, d["name"]))
            add("expected = %s\n\n" % gd_dict(d["expected"]))
            index += 1
        for f in room.get("files", []):
            if f["expected"] is None:
                continue
            node = f["name"].replace(".", "_")
            add('[node name="%sGoal" type="Node" parent="RoomGoals/%s" index="%d" node_paths=PackedStringArray("file")]\n' % (node.title().replace("_", ""), mgr, index))
            add("script = %s\n" % FGOAL)
            add('file = NodePath("../../../Visuals/Files/Room%d/%s")\n' % (n, node))
            add("expected = %s\n\n" % packed(f["expected"]))
            index += 1
        if not room["robot"]:
            continue
        for j, _pen in enumerate(p["pens"]):
            add('[node name="CheckpointGoal%d" type="Node" parent="RoomGoals/%s" index="%d" node_paths=PackedStringArray("required_entity", "camera_focus", "detection_area")]\n' % (j + 1, mgr, index))
            add("script = %s\n" % CHECK)
            add('required_entity = NodePath("../../../Visuals/YSorted/RobotCharacter")\n')
            add('fail_message = "The robot didn\'t collect every battery."\n')
            add('camera_focus = NodePath("../../../Visuals/Pen%d_%d")\n' % (n, j + 1))
            add('detection_area = NodePath("../../../Visuals/Pen%d_%d")\n\n' % (n, j + 1))
            index += 1
        add('[node name="DestinationGoal" type="Node" parent="RoomGoals/%s" index="%d" node_paths=PackedStringArray("required_entity", "destination_area", "camera_focus", "detection_area")]\n' % (mgr, index))
        add("script = %s\n" % DEST)
        add('required_entity = NodePath("../../../Visuals/YSorted/RobotCharacter")\n')
        add('destination_area = NodePath("../../../Visuals/Destination%d")\n' % n)
        add('fail_message = "The robot didn\'t stop on the green flag."\n')
        add('camera_focus = NodePath("../../../Visuals/Destination%d")\n' % n)
        add('detection_area = NodePath("../../../Visuals/Destination%d")\n\n' % n)

    lb = BOUNDS.get(key, {}).get("level")
    add('[node name="Camera2D" parent="." index="4"]\n')
    if lb:
        add("level_bounds = Rect2(%s, %s, %s, %s)\n" % tuple(lb))
    add("\n")

    add('[node name="Visuals" type="Node2D" parent="." index="5"]\n\n')
    add('[node name="Floor" type="TileMapLayer" parent="Visuals"]\n')
    add('tile_map_data = PackedByteArray("%s")\ntile_set = %s\n\n' % (g.encode(floor), FLOOR))

    def area(name, pos, tag, texture, scale="1"):
        add('[node name="%s" type="Area2D" parent="Visuals"]\n' % name)
        add("position = Vector2(%d, %d)\nscript = %s\ntag = &\"%s\"\n\n" % (pos[0], pos[1], SENSED, tag))
        add('[node name="CollisionShape2D" type="CollisionShape2D" parent="Visuals/%s"]\nshape = SubResource("Circle_1")\n\n' % name)
        add('[node name="Sprite" type="Sprite2D" parent="Visuals/%s"]\nscale = Vector2(%s, %s)\ntexture = %s\n\n' % (name, scale, scale, texture))

    if has_robot:
        for k, p in enumerate(placed):
            if "flag" not in p:
                continue
            area("Destination%d" % (k + 1), g.center(p["flag"]), "destination", FLAG)
            for j, pen in enumerate(p["pens"]):
                area("Pen%d_%d" % (k + 1, j + 1), g.center(pen), "undetectable", PEN)

    if has_terminal:
        # One terminal per room; a block finds the running room's by room_index.
        add('[node name="Terminals" type="Node2D" parent="Visuals"]\n\n')
        for k, (room, p) in enumerate(zip(rooms, placed)):
            add('[node name="Room%d" type="Node2D" parent="Visuals/Terminals"]\n\n' % (k + 1))
            if not room["terminal"]:
                continue
            add('[node name="Terminal" parent="Visuals/Terminals/Room%d" instance=%s]\n' % (k + 1, TERMINAL))
            add("position = Vector2(%d, %d)\n" % p["term_at"])
            add("room_index = %d\ninputs = %s\n\n" % (k, packed(room["terminal"]["inputs"])))

    if has_dicts:
        # One board per room for each dictionary, all under the same names.
        add('[node name="Dicts" type="Node2D" parent="Visuals"]\n\n')
        for k, (room, p) in enumerate(zip(rooms, placed)):
            add('[node name="Room%d" type="Node2D" parent="Visuals/Dicts"]\n\n' % (k + 1))
            for d, at in zip(room.get("dicts", []), p["dict_at"]):
                add('[node name="%s" parent="Visuals/Dicts/Room%d" instance=%s]\n' % (d["name"], k + 1, DICT))
                add("position = Vector2(%d, %d)\n" % at)
                add("room_index = %d\nentries = %s\n\n" % (k, gd_dict(d["entries"])))

    if has_files:
        # One file per room for each name, all under the same names.
        add('[node name="Files" type="Node2D" parent="Visuals"]\n\n')
        for k, (room, p) in enumerate(zip(rooms, placed)):
            add('[node name="Room%d" type="Node2D" parent="Visuals/Files"]\n\n' % (k + 1))
            for f, at in zip(room.get("files", []), p["file_at"]):
                add('[node name="%s" parent="Visuals/Files/Room%d" instance=%s]\n' % (f["name"].replace(".", "_"), k + 1, FILE))
                add("position = Vector2(%d, %d)\n" % at)
                add('file_name = "%s"\nroom_index = %d\nlines = %s\n\n' % (esc(f["name"]), k, packed(f["lines"])))

    for k, p in enumerate(placed):
        for j, ((tx, ty), text) in enumerate(p["signs"]):
            add('[node name="Sign%d_%d" type="Label" parent="Visuals"]\n' % (k + 1, j + 1))
            add("offset_left = %d.0\noffset_top = %d.0\noffset_right = %d.0\noffset_bottom = %d.0\n" % (tx * T + 34, ty * T + 4, tx * T + 120, ty * T + 27))
            add('theme = %s\ntheme_type_variation = &"RoomLabel"\ntext = "%s"\n\n' % (THEME, esc(text)))

    add('[node name="YSorted" type="Node2D" parent="Visuals"]\ny_sort_enabled = true\n\n')
    if furniture:
        add('[node name="Furniture" type="TileMapLayer" parent="Visuals/YSorted"]\ny_sort_enabled = true\n')
        add('tile_map_data = PackedByteArray("%s")\ntile_set = %s\n\n' % (g.encode(furniture), FURNITURE))
    robot_rooms = [k for k, room in enumerate(rooms) if room["robot"]]
    if has_robot:
        assert len(robot_rooms) == len(rooms), "%s: a robot level needs the robot in every room" % key
        starts = [g.center(p["start"]) for p in placed]
        robot_z = "z_index = 2\n"
        add('[node name="RobotCharacter" parent="Visuals/YSorted" instance=%s]\n' % ROBOT)
        add("%sposition = Vector2(%d, %d)\nfacing_direction = Vector2(1, 0)\n\n" % ((robot_z,) + starts[0]))
        add('[node name="AnimatedSprite2D" parent="Visuals/YSorted/RobotCharacter" index="0"]\nanimation = &"idle_right"\n\n')
        add('[node name="BlockProvider" parent="Visuals/YSorted/RobotCharacter" index="2"]\n')
        add("block_data = Array[%s]([%s])\n\n" % (DATA, ", ".join(blk(x) for x in spec["robot"])))
        add('[node name="ResettableComponent" type="Node" parent="Visuals/YSorted/RobotCharacter" index="4" node_paths=PackedStringArray("base")]\n')
        add('script = %s\nbase = NodePath("..")\n' % RESET)
        add('tracked_properties = PackedStringArray("facing_direction", "transform")\n')
        add("room_snapshots = Array[Dictionary]([%s])\n\n" % ", ".join(
            'Dictionary[StringName, Variant]({\n&"facing_direction": Vector2(1, 0),\n&"transform": Transform2D(1, 0, 0, 1, %d, %d)\n})' % s
            for s in starts))
    add('[node name="Walls" type="TileMapLayer" parent="Visuals/YSorted"]\ny_sort_enabled = true\n')
    add('tile_map_data = PackedByteArray("%s")\ntile_set = %s\n\n' % (g.encode(walls), WALLS))
    if has_robot:
        for k in range(1, len(rooms)):
            add('[node name="PhantomSprite%s" type="AnimatedSprite2D" parent="Visuals/YSorted"]\n' % ("" if k == 1 else str(k)))
            add(robot_z + "modulate = Color(1, 1, 1, 0.38039216)\nposition = Vector2(%d, %d)\nscale = Vector2(0.915, 0.915)\n" % starts[k])
            add('sprite_frames = %s\nanimation = &"idle_right"\nspeed_scale = 0.0\n\n' % FRAMES)

    if len(rooms) > 1:
        for k, p in enumerate(placed):
            lx, ly = p["label"]
            add('[node name="Room%dLabel" type="Label" parent="Visuals"]\n' % (k + 1))
            add("offset_left = %d.0\noffset_top = %d.0\noffset_right = %d.0\noffset_bottom = %d.0\n" % (lx, ly, lx + 52, ly + 23))
            add('theme = %s\ntheme_type_variation = &"RoomLabel"\ntext = "Room %d"\n\n' % (THEME, k + 1))

    editable = '[editable path="LevelBlockPreset/BeginBlock"]\n'
    if has_robot:
        editable += '[editable path="Visuals/YSorted/RobotCharacter"]\n'
    add(editable)

    head = "[gd_scene load_steps=%d format=4]\n\n" % (len(ext) + len(subs) + 1)
    text = head + "\n".join(ext) + "\n\n" + ("\n".join(subs) + "\n" if subs else "") + "".join(out)
    with open(os.path.join(ROOT, "level/levels/%s.tscn" % key), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    return zoom


def gd_dict(pairs):
    """(key, value) pairs as a Godot Dictionary literal, in order."""
    def lit(v):
        if isinstance(v, str):
            return '"%s"' % esc(v)
        if isinstance(v, bool):
            return "true" if v else "false"
        return str(v)
    return "{\n%s\n}" % ",\n".join("%s: %s" % (lit(k), lit(v)) for k, v in pairs) if pairs else "{}"


def gd_string(s):
    return '"%s"' % esc(s)


def briefs_gd():
    """level/module_briefs.gd: LevelBriefs reads it for these levels."""
    lines = [
        "## The briefs of the levels tools/modules/gen_modules.py writes, keyed by",
        "## scene file name. Generated: change module_specs.py and run the generator.",
        "## LevelBriefs.for_scene() reads this table after its own.",
        "class_name ModuleBriefs",
        "extends RefCounted",
        "",
        "const BRIEFS := {",
    ]
    for module in MODULES:
        for s in module["levels"]:
            lines.append('\t"%s": {' % s["key"])
            lines.append('\t\t"title": %s,' % gd_string(s["title"]))
            lines.append('\t\t"mission": %s,' % gd_string(s["mission"]))
            if s["twist"]:
                lines.append('\t\t"twist": %s,' % gd_string(s["twist"]))
            if s["rooms_text"]:
                lines.append('\t\t"rooms": [%s],' % ", ".join(gd_string(r) for r in s["rooms_text"]))
            if s["blocks"]:
                lines.append('\t\t"blocks": [%s],' % ", ".join('"%s"' % BLK[b] for b in s["blocks"]))
                lines.append('\t\t"block_notes": [%s],' % ", ".join(gd_string(n) for n in s["notes"]))
                if s.get("block_values"):
                    lines.append('\t\t"block_values": [%s],' % ", ".join(gd_string(v) for v in s["block_values"]))
            lines.append('\t\t"tip": %s,' % gd_string(s["tip"]))
            lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def cases_json():
    """Every level's intended program and its wrong ones, for level_checks."""
    out = []
    for module in MODULES:
        for s in module["levels"]:
            path = "res://level/levels/%s.tscn" % s["key"]
            tag = s["id"].upper()
            out.append([tag + " intended", path, s["solution"], "PASS"])
            for title, program, expect in s.get("cases", []):
                out.append(["%s %s" % (tag, title), path, program, expect])
    return out


if __name__ == "__main__":
    report = []
    for module in MODULES:
        for spec in module["levels"]:
            zoom = build(spec)
            report.append("%-8s %d rooms  zoom %.2f" % (spec["key"], len(spec["rooms"]), zoom))
    with open(os.path.join(ROOT, "level/module_briefs.gd"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(briefs_gd())
    with open(os.path.join(HERE, "cases.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(cases_json(), fh, indent=0)
    tmp = os.environ.get("TEMP", ".")
    json.dump([dict(id=m["id"], name=m["name"], subtitle=m["subtitle"], after=m["after"],
                    levels=[dict(id=s["id"], key=s["key"], label=s["label"], title=s["title"], concept=s["concept"])
                            for s in m["levels"]]) for m in MODULES],
              open(os.path.join(tmp, "module_catalog.json"), "w"), indent=1)
    print("\n".join(report))
