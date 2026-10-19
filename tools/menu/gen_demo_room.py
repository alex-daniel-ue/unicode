"""Writes the main menu's demo rooms, menus/main/demo_<name>.tscn: little
classrooms painted from the same tilesets and by the same rules as the Arrays
rooms (this borrows gen_arrays.py's painter), so they look like levels.

    python tools/menu/gen_demo_room.py <project root>

Each room is described in ROOMS: its floor in tiles, its furniture, where the
robot starts (if it has one) and the lists on its wall. menu_demo.gd plays a
program in each; the robot's path there follows from the start given here.
A room with a list gets the levels' taller wall, and is widened when its board
needs it. Every scene keeps its size in pixels as `metadata/size`.
"""
import os, sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, "..", "arrays"))
sys.argv = [sys.argv[0], root]  # gen_arrays reads the root from argv when imported
import gen_arrays as g  # noqa: E402

X0 = 1   # the floor's left column: one wall column left of it
DESK, TRASH, EXT = g.DESKS, g.TRASH[0], g.EXTINGUISHER
# Board name widths in pixels, as gen_arrays.NAME_W measures them.
g.NAME_W.setdefault("nums", 42)

ROOMS = {
    # while True: step forward 2 times; turn left. Round the desk in the middle.
    "lap": dict(w=5, h=3, robot=(1, 2), lists=[],
                furniture={(2, 1): DESK[1], (0, 0): EXT, (4, 2): TRASH}),
    # while True: if ahead is blocked: turn around, else: step forward.
    "patrol": dict(w=4, h=2, robot=(0, 0), lists=[],
                   furniture={(1, 1): DESK[0], (2, 1): TRASH, (3, 1): EXT}),
    # while True: for each steps in route: step forward steps times; turn left.
    "route": dict(w=7, h=2, robot=(1, 1), lists=[("route", [3, 1, 3, 1])],
                  furniture={(0, 0): EXT, (6, 1): DESK[1], (6, 0): TRASH}),
    # while True: swap the first and the last values of nums.
    "swap": dict(w=6, h=2, robot=None, lists=[("nums", [3, 5, 8])],
                 furniture={(0, 1): DESK[0], (2, 1): DESK[1], (4, 1): DESK[2], (5, 0): EXT}),
}


def scene(name, room):
    walls, floor, furniture = {}, {}, {}
    # As gen_arrays.block(): a board on the wall makes the wall taller.
    wall_rows = g.BOARD_WALL_ROWS if room["lists"] else g.WALL_ROWS
    Y0 = wall_rows
    w = room["w"]
    for list_name, values in room["lists"]:
        w = max(w, -(-(g.board_right(list_name, len(values)) + 6 - g.T) // g.T))
    g.paint_room(walls, floor, X0, Y0, w, room["h"], wall_rows)
    for (x, y), cell in room["furniture"].items():
        flip = g.FLIP_H if cell == TRASH and x % 2 else 0
        furniture[(X0 + (w - room["w"] if x == room["w"] - 1 else 0) + x, Y0 + y)] = cell + (flip,)
    size = ((w + 2) * g.T, (room["h"] + wall_rows + 1) * g.T)
    ext = [
        '[ext_resource type="TileSet" uid="uid://b41gvomjqm625" path="res://world/tilesets/school_tiles.tres" id="1_floor"]',
        '[ext_resource type="TileSet" uid="uid://ci0tufhkgt2lv" path="res://world/tilesets/school_walls.tres" id="2_walls"]',
        '[ext_resource type="TileSet" uid="uid://dwdeg5l2ik0ee" path="res://world/tilesets/school_chairs.tres" id="3_furniture"]',
        '[ext_resource type="SpriteFrames" uid="uid://bbra16dnqb2nc" path="res://level/objects/entities/robot/sprite_frames.tres" id="4_robot"]',
    ]
    if room["lists"]:
        ext.append('[ext_resource type="PackedScene" uid="uid://cb5ve56xnp5r5" path="res://level/objects/entities/list/list_entity.tscn" id="5_board"]')
    out = ["[gd_scene load_steps=%d format=4]\n" % (len(ext) + 1), "\n".join(ext), "",
           '[node name="Demo%s" type="Node2D"]' % name.title(),
           "metadata/size = Vector2(%d, %d)" % size, "",
           '[node name="Floor" type="TileMapLayer" parent="."]',
           'tile_map_data = PackedByteArray("%s")' % g.encode(floor),
           'tile_set = ExtResource("1_floor")', ""]
    for list_name, values in room["lists"]:
        # On the wall, where gen_arrays hangs a room's first list; over the
        # walls, which draw later.
        out += ['[node name="%s" parent="." instance=ExtResource("5_board")]' % list_name,
                "z_index = 1", "position = Vector2(%d, %d)" % (g.board_x(list_name), g.BOARD_Y[wall_rows]),
                "values = [%s]" % ", ".join(str(v) for v in values), ""]
    out += ['[node name="YSorted" type="Node2D" parent="."]', "y_sort_enabled = true", "",
            '[node name="Furniture" type="TileMapLayer" parent="YSorted"]', "y_sort_enabled = true",
            'tile_map_data = PackedByteArray("%s")' % g.encode(furniture),
            'tile_set = ExtResource("3_furniture")', ""]
    if room["robot"] is not None:
        rx, ry = room["robot"]
        out += ['[node name="Robot" type="Node2D" parent="YSorted"]',
                "position = Vector2(%d, %d)" % ((X0 + rx) * g.T + 16, (Y0 + ry) * g.T + 16), "",
                # z 2, as in the levels: in front of the boards on the wall.
                '[node name="Sprite" type="AnimatedSprite2D" parent="YSorted/Robot"]',
                "z_index = 2", "position = Vector2(-0.125, -12)", "scale = Vector2(0.915, 0.915)",
                'sprite_frames = ExtResource("4_robot")', 'animation = &"idle_right"', ""]
    out += ['[node name="Walls" type="TileMapLayer" parent="YSorted"]', "y_sort_enabled = true",
            'tile_map_data = PackedByteArray("%s")' % g.encode(walls),
            'tile_set = ExtResource("2_walls")', ""]
    path = os.path.join(root, "menus/main/demo_%s.tscn" % name)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))
    print("demo_%s.tscn: %dx%d px" % (name, size[0], size[1]))


for name, room in ROOMS.items():
    scene(name, room)
