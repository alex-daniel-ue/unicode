"""Generates the Arrays module's scenes: ar_t2 and ar_t3 (Arrays 1 and 2) and
ar_4.tscn .. ar_11.tscn. AR-3 is hand-made in the editor and listed in
HAND_MADE, so this never overwrites it; its spec stays here for the brief text
and the catalog.

The ids are the progress and thesis-data keys, so they never change: Arrays 1
and 2 keep the "t" from when they were tutorials, and there is no ar_9, since
Tidy up was cut.

    python gen_arrays.py <project root> [solutions.json] [bounds.json]

solutions.json maps "ar_4" -> intended_solution YAML (from the harness's yaml
mode); bounds.json maps "ar_4" -> {"level": [x, y, w, h], "GoalManager": ...}
(from tools/bake_level.tscn). Run once without them, capture both, run again.

Every room is an open rectangle painted by rule from the wall and floor
tilesets, the way Iteration's rooms are painted: a two-row wall face on top,
one wall tile on each side, a one-row base.

Lists are whiteboards. A room's first list hangs on its wall; any others stand
on the floor below it on legs, one under the other, so a room is as wide as its
widest board. Rooms are stacked top to bottom, since the level panel is tall.
The robot is only in a level when where it goes depends on the list.

Brief text here is kept in step with level/level_briefs.gd by hand: change both.
"""
import base64, json, math, os, random, struct, sys

ROOT = sys.argv[1]
SOLUTIONS = json.load(open(sys.argv[2])) if len(sys.argv) > 2 and os.path.exists(sys.argv[2]) else {}
BOUNDS = json.load(open(sys.argv[3])) if len(sys.argv) > 3 and os.path.exists(sys.argv[3]) else {}

BLK = {
    "move_n": "res://level/objects/entities/robot/blocks/move_n.tres",
    "turn": "res://level/objects/entities/robot/blocks/turn.tres",
    "item": "res://puzzle/blocks/lists/item_of.tres",
    # A list's name block. Only for a brief's blocks: it stands for the level's
    # own lists' name blocks, which exist only at runtime (ListEntity.is_reporter).
    "list": "res://puzzle/blocks/lists/list_reporter.tres",
    "len": "res://puzzle/blocks/lists/length_of.tres",
    "setitem": "res://puzzle/blocks/lists/set_item.tres",
    "append": "res://puzzle/blocks/lists/append.tres",
    "in": "res://puzzle/blocks/lists/contains.tres",
    "each": "res://puzzle/blocks/control flow/for_each.tres",
    "for": "res://puzzle/blocks/control flow/for_int.tres",
    "if": "res://puzzle/blocks/control flow/if.tres",
    "not": "res://puzzle/blocks/socket/not.tres",
    "cmp": "res://puzzle/blocks/socket/comparison.tres",
    "arith": "res://puzzle/blocks/socket/arithmetic.tres",
    "set": "res://puzzle/blocks/generic/set_var.tres",
}

# The level panel at 1920x1080, which the camera fits the whole level into
# before Play. Narrower windows keep about the same shape.
PANEL = (548, 1055)

# Board geometry, as list_entity.gd lays it out.
T = 32
NAME_W = {"route": 48, "lockers": 66, "scores": 60, "passed": 60, "bags": 40, "tidy": 32,
          "chess": 50, "choir": 44, "both": 38, "monday": 62, "tuesday": 68, "present": 68}
INDEX_W = 44
CHIP_PAD = 8          # list_entity.gd: the name sits on a chip this much wider each side


def name_col(name):
    return max(NAME_W[name] + 2 * CHIP_PAD, INDEX_W) + 2


# A room with a board on its wall gets a wall three tiles tall instead of two,
# and the board hangs with plain wall under it. With the board's index row
# right on the floor's edge, and one box per tile, the indexes read as numbers
# for the floor's columns. For the same reason a board's boxes start half a
# tile into a column (board_shift), so each box sits across two tiles.
WALL_ROWS, BOARD_WALL_ROWS = 2, 3
BOARD_Y = {2: 8, 3: 20}   # the top of a hanging board's boxes, from the top of the wall


def board_shift(name):
    """How far right of the usual place a board's boxes go, in pixels, so box 0
    starts half a tile into a floor column. Never left: the board's left margin
    is all there is between it and the side wall."""
    usual = 6 + 6 + name_col(name) + 8   # from the floor's left edge
    return (T // 2 - usual) % T


def board_x(name):
    """Where box 0 of a board goes, from the left of the room's block."""
    return T + 6 + 6 + name_col(name) + 8 + board_shift(name)


def board_right(name, boxes_):
    """The right edge of a board, from the left of the room's block."""
    return T + 6 + board_shift(name) + board_width(name, boxes_)


def board_width(name, boxes):
    """Left margin, name column, gap, boxes, right margin."""
    return 6 + name_col(name) + 8 + max(boxes, 1) * T + 6


def boxes(l):
    return max(len(l["values"]), len(l.get("goal", [])))


# ---------------------------------------------------------------- level specs

def walk(legs):
    """Drive `legs` from (0, 0) facing right, turning left after each leg.
    Returns (start, leg ends, w, h) in room tile coordinates."""
    x = y = 0
    dx, dy = 1, 0
    seen = [(0, 0)]
    ends = []
    for leg in legs:
        for _ in range(leg):
            x, y = x + dx, y + dy
            seen.append((x, y))
        ends.append((x, y))
        dx, dy = dy, -dx  # turn left, as robot.gd: (y, -x)
    minx = min(p[0] for p in seen); miny = min(p[1] for p in seen)
    maxx = max(p[0] for p in seen); maxy = max(p[1] for p in seen)
    shift = lambda p: (p[0] - minx, p[1] - miny)
    walk.path = [shift(p) for p in seen]
    return shift((0, 0)), [shift(e) for e in ends], maxx - minx + 1, maxy - miny + 1


def route_room(card, legs, pens_at_corners=False, flag="end", pen_far=False):
    """A room the robot drives through, its route on a board on the wall."""
    start, ends, w, h = walk(legs)
    robot = dict(start=start, flag=ends[-1] if flag == "end" else start, pens=[], path=walk.path)
    if pens_at_corners:
        robot["pens"] = [e for e in ends[:-1] if e != start]
    if pen_far:
        robot["pens"] = robot["pens"] + [ends[-1]]
    return dict(walk_w=w, walk_h=h, robot=robot, wall=[dict(name="route", values=card)], standing=[], goals=[])


def hall_room(steps, length, card=None):
    """A straight hallway `length` tiles long, the robot at its left end facing
    right and the flag `steps` tiles on, with a row of desks below. `card`, when
    given, hangs on the wall as the route list."""
    path = [(x, 0) for x in range(steps + 1)]
    robot = dict(start=(0, 0), flag=(steps, 0), pens=[], path=path)
    wall = [dict(name="route", values=card)] if card else []
    return dict(walk_w=length, walk_h=2, robot=robot, wall=wall, standing=[], goals=[])


def data_room(wall, standing=(), goals=(), robot_walk=None):
    """A room about its lists. `wall` hangs on the wall, `standing` stands on the
    floor. With `robot_walk`, a one-tile hallway runs along the top of the
    floor and the flag is that many tiles from the robot."""
    goal_of = dict(goals)
    standing = [dict(l, goal=goal_of.get(l["name"], [])) for l in standing]
    wall = [dict(l, goal=goal_of.get(l["name"], [])) for l in wall]
    robot = None
    if robot_walk is not None:
        robot = dict(start=(0, 0), flag=(robot_walk, 0), pens=[], path=[(x, 0) for x in range(robot_walk + 1)])
    return dict(walk_w=(robot_walk + 2) if robot else 1, walk_h=1 if robot else 0, robot=robot,
                wall=wall, standing=standing, goals=list(goals))


LEVELS = {}

# Arrays 1 to 3 add one idea each: read a value by its index, count the values,
# then find the last value. Arrays 1 also brings Step Forward N Times, which is
# Iteration's step forward with a number. Every level has two rooms with
# different lists, so no number typed in passes.
LEVELS["ar_t2"] = dict(
    id="ar-t2", label="1", root="ART2ReadAList", title="Read a list",
    concept="Reading one value from a list, by its index.",
    mission="Stop the robot on the green flag in each room. The flag is as far away as the third value in the list.",
    rooms_text=["A list with three values.", "A list with four values."],
    twist="Each room has a different list.",
    blocks=["move_n", "list", "item"],
    notes=["This block makes the robot step forward that many times. A number, or the answer of another block, goes into it.",
           "This is the name block of a list. Drop it into a list slot.",
           "This block gives you the value at an index of a list. The first index is 0."],
    block_values=["", "", ",list:route"],
    tip="In Python, index 0 of route is written as `route[0]`.",
    robot=["move_n"], toolbox=["item"],
    # In Room 1 the third value is also the last one; Room 2's longer list keeps
    # "the last value" from passing as well.
    rooms=[hall_room(3, 7, [4, 1, 3]), hall_room(5, 7, [2, 6, 5, 1])],
)

LEVELS["ar_t3"] = dict(
    id="ar-t3", label="2", root="ART3HowLongIsAList", title="How long is a list?",
    concept="Counting the values in a list.",
    mission="Before the turn, move as far as the number of values in the list. After the turn, move as far as the first value in the list.",
    rooms_text=["A short list.", "A longer list."], twist="Each room has a list of a different length.",
    blocks=["len"],
    # The second sentence sets up Arrays 3, where the last index is length - 1.
    notes=["This block counts the values in a list. A list with 4 values has indexes 0 to 3."],
    block_values=["list:route"],
    tip="In Python, length of route is written as `len(route)`.",
    robot=["move_n", "turn"], toolbox=["item", "len"],
    # Move, turn, move: Arrays 3 keeps this shape and changes only what is read.
    # Neither list holds its own length, so reading one value can't pass the
    # first move, and the lists differ, so no number typed in passes.
    rooms=[route_room(c, [len(c), c[0]]) for c in ([2, 6, 1, 3], [1, 4, 2, 5, 1, 3])],
)

LEVELS["ar_3"] = dict(
    id="ar-3", label="3", root="AR3CountThenTheLast", title="Last index, last value",
    concept="The last index is the length minus 1, and the last value sits there.",
    mission="Before the turn, move as far as the last index of the list. After the turn, move as far as the last value in the list.",
    rooms_text=["A list with three values.", "A list with two values."],
    twist="Each list has a different length.",
    blocks=["arith"],
    notes=["This block does math, like 3 + 1. Pick the sign in the middle. Either side can take a number, or the answer of another block."],
    tip="The Math block can use the answer of another block. In Python: `len(route) + 1`.",
    robot=["move_n", "turn"], toolbox=["item", "len", "arith"],
    # The first move builds (length of route) - 1 alone; the second puts the same
    # block inside Index Of, so the nesting deepens one step at a time.
    rooms=[route_room(c, [len(c) - 1, c[-1]]) for c in ([2, 5, 1], [4, 3])],
)


# The first half of the module has two rooms a level, not three: a third board
# and a third route on screen was more to take in than it taught.
def ar4_rooms():
    return [route_room(c, c, pens_at_corners=True) for c in ([4, 2, 4, 2], [3, 2, 3])]


LEVELS["ar_4"] = dict(
    id="ar-4", label="4", root="AR4EveryStop", title="Every stop",
    concept="Going through a list by index.",
    mission="Each value in the list is how far to move before the next left turn. Collect every battery on the way to the green flag.",
    rooms_text=["A lap.", "A U-turn."],
    twist="Each list has a different number of stops.",
    blocks=[], notes=[],
    tip="The For block stops before its end number, like `range(0, 3)` in Python, which gives 0, 1, 2.",
    robot=["move_n", "turn"], toolbox=["for", "item", "len", "arith"],
    rooms=ar4_rooms(),
)

LEVELS["ar_5"] = dict(
    id="ar-5", label="5", root="AR5EveryStopAgain", title="Every stop, again",
    concept="Going through a list value by value: for each.",
    mission="These are the same rooms as in the last level. Each value in the list is how far to move before the next left turn. Collect every battery on the way to the green flag.",
    rooms_text=["A lap.", "A U-turn."],
    twist="This time, there is no Index Of block and no Length Of block.",
    blocks=["each"],
    notes=["This block runs its blocks once for each value in a list. The box that it is on lights up."],
    block_values=["steps,list:route"],
    tip="In Python: `for steps in route:`",
    robot=["move_n", "turn"], toolbox=["each"],
    rooms=ar4_rooms(),
)

LEVELS["ar_6"] = dict(
    id="ar-6", label="6", root="AR6ThereAndBack", title="There and back",
    concept="Going through a list backwards.",
    mission="Move out and collect every battery. Then move back the same way, to the green flag where you started.",
    rooms_text=["A long way out.", "A winding way out."],
    twist="The way back is the list, read backwards.",
    blocks=[], notes=[],
    tip="The For block can count down. Give it a step of -1.",
    robot=["move_n", "turn"], toolbox=["each", "for", "item", "len", "arith"],
    star_slack=2,
    # A battery at every corner and at the far end: each one is a turn the robot
    # makes on the way out, and again on the way back.
    rooms=[route_room(c, c, flag="start", pens_at_corners=True, pen_far=True) for c in ([3, 2, 4], [2, 3, 1, 2])],
)

LEVELS["ar_7"] = dict(
    id="ar-7", label="7", root="AR7NumberTheLockers", title="Number the lockers",
    concept="Changing a list's values in place.",
    mission="Give each locker its number.",
    rooms_text=["Three lockers.", "Five lockers.", "Four lockers."],
    twist="People count lockers from 1, not from 0.",
    blocks=["setitem"],
    notes=["This block changes the value at an index of a list."],
    block_values=["0,list:lockers,1"],
    tip="In Python: `lockers[0] = 1`",
    # for each and set var are red herrings: `for each x in lockers { set x to ... }`
    # leaves the lockers unchanged, because the loop variable is a copy.
    robot=None, toolbox=["for", "setitem", "item", "len", "arith", "each", "set"],
    rooms=[data_room([dict(name="lockers", values=[0] * n)], goals=[("lockers", list(range(1, n + 1)))]) for n in (3, 5, 4)],
)

SCORES = [[70, 82, 75, 60, 91], [74, 60, 55, 90], [75, 75, 80, 99, 76, 62]]
LEVELS["ar_8"] = dict(
    id="ar-8", label="8", root="AR8PassingMarks", title="Passing marks",
    concept="Building a new list with append.",
    mission="Copy every score of 75 or more into the passed list. Keep the scores in the same order.",
    rooms_text=["Five scores.", "Four scores.", "Six scores."],
    twist="The passed list starts empty.",
    blocks=["append"],
    notes=["This block adds a value to the end of a list."],
    block_values=["82,list:passed"],
    tip="In Python: `passed.append(s)`",
    # set item and item of are red herrings: they are how a student finds out
    # that passed starts empty.
    robot=None, toolbox=["each", "if", "cmp", "append", "len", "setitem", "item"],
    rooms=[data_room([dict(name="scores", values=s)], [dict(name="passed", values=[])],
                     goals=[("passed", [v for v in s if v >= 75])]) for s in SCORES],
)

CLUBS =[([1, 2, 3, 4], [2, 4, 5]), ([6, 7], [8]), ([1, 5, 9], [1, 5, 9, 10])]
LEVELS["ar_10"] = dict(
    id="ar-10", label="9", root="AR10InBoth", title="In both",
    concept="Checking whether a value is in a list.",
    mission="Find every student who is in both chess and choir. Put each of them into the both list.",
    rooms_text=["Four students in chess.", "Two students in chess.", "Three students in chess."],
    twist="Some rooms have no one in both.",
    blocks=["in"],
    notes=["This block is True when the value is somewhere in the list."],
    block_values=["2,list:choir"],
    tip="In Python: `s in choir`",
    robot=None, toolbox=["each", "if", "in", "append"],
    rooms=[data_room([dict(name="chess", values=a), dict(name="choir", values=b)], [dict(name="both", values=[])],
                     goals=[("both", [v for v in a if v in b])]) for a, b in CLUBS],
)

DAYS = [([1, 2, 3], [2, 3, 4]), ([5, 6], [5, 6]), ([1, 3, 5, 7], [2, 3])]
LEVELS["ar_11"] = dict(
    id="ar-11", label="10", root="AR11HereEitherDay", title="Here either day",
    concept="Joining two lists without repeats, using not and in.",
    mission="The monday list has the students who came on Monday. The tuesday list has the students who came on Tuesday. Put every student who came on either day into the present list, and put each student in only once.",
    rooms_text=["Three on Monday, three on Tuesday.", "Two on Monday, two on Tuesday.", "Four on Monday, two on Tuesday."],
    twist="Some students came on both days.",
    blocks=[], notes=[],
    tip="The Not block turns True into False, and False into True.",
    robot=None, toolbox=["each", "if", "in", "not", "append"],
    rooms=[data_room([dict(name="monday", values=m), dict(name="tuesday", values=t)], [dict(name="present", values=[])],
                     goals=[("present", m + [v for v in t if v not in m])]) for m, t in DAYS],
)


# ------------------------------------------------------------------ painting

FLIP_H, FLIP_V, TRANSPOSE = 4096, 8192, 16384


def paint_room(walls, floor, x0, y0, w, h, wall_rows=WALL_ROWS):
    """An open rectangle with its interior at (x0, y0), w x h tiles, under a
    wall `wall_rows` tiles tall: its top row, plain rows (atlas row 2), then the
    row with the skirting."""
    x1, y1 = x0 + w - 1, y0 + h - 1
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            # Edges get the edge tiles; inside, the two middle variants take
            # turns starting from the first, as Iteration's floors do.
            ax = 0 if x == x0 else (3 if x == x1 and w > 1 else 1 + (x - x0 - 1) % 2)
            ay = 0 if y == y0 else (3 if y == y1 else 1 + (y - y0 - 1) % 2)
            floor[(x, y)] = (1, ax, ay, 0)
    rows = [0] + [2] * (wall_rows - 2) + [1]
    for i, atlas_y in enumerate(rows):
        row = y0 - wall_rows + i
        side = 1 if atlas_y == 2 else atlas_y   # the side walls' row 1 repeats as it is
        walls[(x0 - 1, row)] = (1, 0, side, 0)
        walls[(x0, row)] = (1, 3, atlas_y, 0)
        for x in range(x0 + 1, x1 + 1):
            walls[(x, row)] = (1, 1, atlas_y, 0)
        walls[(x1 + 1, row)] = (1, 0, side, FLIP_H)
    for y in range(y0, y1 + 1):
        walls[(x0 - 1, y)] = (1, 0, 1, 0)
        walls[(x1 + 1, y)] = (1, 0, 1, FLIP_H)
    walls[(x0 - 1, y1 + 1)] = (1, 2, 0, FLIP_H | FLIP_V)
    for x in range(x0, x1 + 1):
        walls[(x, y1 + 1)] = (0, 0, 1, FLIP_H | FLIP_V | TRANSPOSE)
    walls[(x1 + 1, y1 + 1)] = (1, 2, 0, FLIP_V)


def encode(cells):
    data = struct.pack("<H", 0)
    for (x, y), (s, ax, ay, alt) in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        data += struct.pack("<hhHHHH", x, y, s, ax, ay, alt)
    return base64.b64encode(data).decode()


# -------------------------------------------------------------------- layout

LABEL_W = 60          # the "Room N" label, with a little room around it
GAP = 1               # tiles between two rooms' blocks


def block(room):
    """One room laid out in pixels from its block's top-left: the top-left of the
    left wall column, at the top of the wall face. The floor starts wall_rows
    rows down; the robot's rows come first, then a two-row band per standing board.

    The room's first list hangs on the wall; every other list stands on the
    floor below, one under the other, so the room is as wide as its widest board
    and no wider."""
    robot_rows = room["walk_h"]
    lists = room["wall"] + room["standing"]
    on_wall, on_floor = lists[:1], lists[1:]
    wall_rows = BOARD_WALL_ROWS if on_wall else WALL_ROWS
    wall_at = [(l, (board_x(l["name"]), BOARD_Y[wall_rows])) for l in on_wall]
    wall_right = max([board_right(l["name"], boxes(l)) for l in on_wall] or [T])
    standing_at = []
    for k, l in enumerate(on_floor):
        top = wall_rows * T + robot_rows * T + k * 2 * T
        standing_at.append((l, (board_x(l["name"]), top + 5)))
    standing_right = max([board_right(l["name"], boxes(l)) for l in on_floor] or [0])
    width_px = max(wall_right + 6, standing_right + 6, T + room["walk_w"] * T)
    w = max(room["walk_w"], int(math.ceil((width_px - T) / T)), 3)
    h = robot_rows + 2 * len(on_floor)
    if room["robot"] is None:
        h += 1  # a row for desks: a room about lists is still a classroom
    h = max(h, 1)
    # Floor tiles under a standing board, in room tiles.
    board_tiles = set()
    for k, l in enumerate(on_floor):
        cols = int(math.ceil((board_right(l["name"], boxes(l)) - T) / T))
        # Its two rows, and the row below, where a desk's top would stand in
        # front of the board's legs.
        for row in (robot_rows + 2 * k, robot_rows + 2 * k + 1, robot_rows + 2 * k + 2):
            board_tiles.update((x, row) for x in range(min(cols + 1, w)))
    return dict(room=room, w=w, h=h, wall=wall_at, standing=standing_at, board_tiles=board_tiles,
                wall_rows=wall_rows, tiles=(w + 2, wall_rows + h + 1),
                # The label fits on the wall beside the board.
                label_fits=wall_right + LABEL_W <= (w + 1) * T)


# Furniture, from world/tilesets/school_chairs.tres: (source, atlas x, atlas y).
DESKS = [(1, 0, 0), (1, 1, 0), (1, 2, 0)]   # these block the robot like walls
TRASH = [(3, 0, 0)]                         # paper; batteries are only ever to collect
EXTINGUISHER = (0, 0, 0)


def clutter(b, seed):
    """Where the room's clutter goes, as {room tile: (source, ax, ay, alt)}.
    Never on the robot's path or a tile next to where it turns, never under a
    standing board, and desks never in the top row, where they would stand in
    front of the wall's boards. Seeded, so regenerating a level keeps its room."""
    rng = random.Random(seed)
    room = b["room"]
    taken = set(b["board_tiles"])
    if room["robot"]:
        r = room["robot"]
        for (x, y) in r["path"] + [r["start"], r["flag"]] + r["pens"]:
            taken.add((x, y))
        # A tile beside the path stays clear too, so the way through still reads
        # as open floor rather than a gap between desks.
        for (x, y) in list(taken):
            if (x, y) in r["path"]:
                taken.update({(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)})
    free = [(x, y) for y in range(b["h"]) for x in range(b["w"]) if (x, y) not in taken]
    rng.shuffle(free)
    cells = {}
    desk_spots = [t for t in free if t[1] > 0]
    for t in desk_spots[:min(4, max(1, len(desk_spots) // 5))]:
        cells[t] = DESKS[rng.randrange(len(DESKS))] + (0,)
    rest = [t for t in free if t not in cells]
    for t in rest[:min(3, max(1, len(rest) // 8))]:
        source = TRASH[rng.randrange(len(TRASH))]
        cells[t] = source + ((4096 if rng.random() < 0.5 else 0),)
    corner = [t for t in rest if t not in cells and t[1] == 0 and t[0] in (0, b["w"] - 1)]
    if corner:
        cells[corner[0]] = EXTINGUISHER + (0,)
    return cells


ARRANGEMENTS = {
    "stacked": ("rows", [[0], [1], [2]]),
    "side by side": ("rows", [[0, 1, 2]]),
    "two, then one": ("rows", [[0, 1], [2]]),
    "one, then two": ("rows", [[0], [1, 2]]),
    "one beside two": ("cols", [[0], [1, 2]]),
    "two beside one": ("cols", [[0, 1], [2]]),
}


def arrange(blocks, how):
    """Tile offsets of each block, and the whole level's size in tiles."""
    kind, groups = ARRANGEMENTS[how]
    groups = [[i for i in g if i < len(blocks)] for g in groups]
    groups = [g for g in groups if g]
    at, major, total_minor = {}, 0, 0
    for group in groups:
        minor, depth = 0, 0
        for i in group:
            bw, bh = blocks[i]["tiles"]
            if kind == "rows":
                at[i] = (minor, major)
                minor += bw + GAP
                depth = max(depth, bh)
            else:
                at[i] = (major, minor)
                minor += bh + GAP
                depth = max(depth, bw)
        total_minor = max(total_minor, minor - GAP)
        major += depth + GAP
    major -= GAP
    size = (total_minor, major) if kind == "rows" else (major, total_minor)
    return at, size


def zoom(size):
    w, h = size[0] * T, size[1] * T
    return min(PANEL[0] / (w + 16), PANEL[1] / (h + 16))


def layout(spec):
    """Rooms stacked top to bottom: the level panel is tall and narrow, and the
    rooms read in order down it."""
    blocks = [block(room) for room in spec["rooms"]]
    at, size = arrange(blocks, "stacked")
    best = (zoom(size), "stacked" if len(blocks) > 1 else "single", at, size)
    return blocks, best, [best]


# ------------------------------------------------------------------- writing

def esc(text):
    return text.replace("\\", "\\\\").replace('"', '\\"')


def arr(values):
    return "[" + ", ".join(str(v) for v in values) + "]"


def packed(strings):
    return "PackedStringArray(%s)" % ", ".join('"%s"' % esc(s) for s in strings)


def center(tile):
    return (tile[0] * T + 16, tile[1] * T + 16)


def build(key, spec):
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
    LGOAL = res("Script", "res://level/goals/list_goal.gd")
    FLOOR = res("TileSet", "res://world/tilesets/school_tiles.tres", "uid://b41gvomjqm625")
    WALLS = res("TileSet", "res://world/tilesets/school_walls.tres", "uid://ci0tufhkgt2lv")
    BOARD = res("PackedScene", "res://level/objects/entities/list/list_entity.tscn", "uid://cb5ve56xnp5r5")
    has_robot = spec["robot"] is not None
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

    rooms = spec["rooms"]
    blocks, (z, how, at, size), _tried = layout(spec)
    walls, floor, furniture = {}, {}, {}
    placed = []
    labels_on_top = all(b["label_fits"] for b in blocks)
    for k, b in enumerate(blocks):
        room = b["room"]
        ox, oy = at[k]
        x0, y0 = ox + 1, oy + b["wall_rows"]
        paint_room(walls, floor, x0, y0, b["w"], b["h"], b["wall_rows"])
        for (cx, cy), cell in clutter(b, "%s-%d" % (key, k)).items():
            furniture[(x0 + cx, y0 + cy)] = cell
        tile = lambda t: (x0 + t[0], y0 + t[1])
        p = dict(boards=[(l, (ox * T + x, oy * T + y), False) for l, (x, y) in b["wall"]]
                 + [(l, (ox * T + x, oy * T + y), True) for l, (x, y) in b["standing"]],
                 label=((x0 + b["w"]) * T - 58, oy * T + 18 + (b["wall_rows"] - WALL_ROWS) * T // 2) if labels_on_top
                 else ((x0 * 2 + b["w"]) * T // 2 - 26, (y0 + b["h"]) * T + 4))
        if room["robot"]:
            r = room["robot"]
            p.update(start=tile(r["start"]), flag=tile(r["flag"]), pens=[tile(q) for q in r["pens"]])
        placed.append(p)

    subs = []
    if has_robot:
        subs.append('[sub_resource type="CircleShape2D" id="Circle_1"]\nradius = 12.0\n')
    out = []
    add = out.append
    add('[node name="%s" node_paths=PackedStringArray("room_goals") instance=%s]\n' % (spec["root"], LEVEL))
    add('intended_solution = "%s"\n' % esc(SOLUTIONS.get(key, "")))
    add('room_goals = [%s]\n' % ", ".join('NodePath("RoomGoals/%s")' % mgr for mgr in
                                          ["GoalManager", "GoalManagerRoom2", "GoalManagerRoom3"][:len(rooms)]))
    if spec.get("star_slack", 1) != 1:
        add("star_slack = %d\n" % spec["star_slack"])
    if spec.get("auto_run"):
        add("auto_run = true\n")
    if spec.get("minimal_ui"):
        add("minimal_ui = true\n")
    add("\n")

    add('[node name="LevelDescription" parent="." index="0"]\n')
    add('title = "%s"\nmission = "%s"\n' % (esc(spec["title"]), esc(spec["mission"])))
    if spec["rooms_text"]:
        add("rooms = %s\n" % packed(spec["rooms_text"]))
    if spec["twist"]:
        add('twist = "%s"\n' % esc(spec["twist"]))
    if spec["blocks"]:
        add("blocks = Array[%s]([%s])\n" % (DATA, ", ".join(blk(b) for b in spec["blocks"])))
        add("block_notes = %s\n" % packed(spec["notes"]))
        if spec.get("block_values"):
            add("block_values = %s\n" % packed(spec["block_values"]))
    add('tip = "%s"\n' % esc(spec["tip"]))
    if spec.get("show_stars") is False:
        add("show_stars = false\n")
    add("\n")

    if spec.get("preset"):
        add('[node name="LevelBlockPreset" parent="." index="1"]\nimmovable = true\nprogram = "%s"\n\n' % esc(json.dumps(spec["preset"])))

    add('[node name="GenericBlockProvider" parent="." index="2"]\n')
    add("block_data = Array[%s]([%s])\n\n" % (DATA, ", ".join(blk(b) for b in spec["toolbox"])))

    for k, (room, p) in enumerate(zip(rooms, placed)):
        mgr = "GoalManager" if k == 0 else "GoalManagerRoom%d" % (k + 1)
        n = k + 1
        if k == 0:
            add('[node name="GoalManager" parent="RoomGoals" index="0" node_paths=PackedStringArray("focus_markers")]\n')
        else:
            add('[node name="%s" type="Node" parent="RoomGoals" index="%d" node_paths=PackedStringArray("focus_markers")]\n' % (mgr, k))
            add("script = %s\n" % MGR)
        bounds = BOUNDS.get(key, {}).get(mgr)
        if bounds:
            add("bounds = Rect2(%s, %s, %s, %s)\n" % tuple(bounds))
        # A room with no list frames on its flag alone.
        markers = ['NodePath("../../Visuals/Lists/Room%d")' % n] if room["wall"] or room["standing"] else []
        if room["robot"]:
            markers.append('NodePath("../../Visuals/Destination%d")' % n)
        add("focus_markers = [%s]\n\n" % ", ".join(markers))
        index = 0
        for name, expected in room["goals"]:
            add('[node name="%sGoal" type="Node" parent="RoomGoals/%s" index="%d" node_paths=PackedStringArray("list")]\n' % (name.title().replace("_", ""), mgr, index))
            add("script = %s\n" % LGOAL)
            add('list = NodePath("../../../Visuals/Lists/Room%d/%s")\n' % (n, name))
            add("expected = %s\n\n" % arr(expected))
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
    add('tile_map_data = PackedByteArray("%s")\ntile_set = %s\n\n' % (encode(floor), FLOOR))

    def area(name, pos, tag, texture, scale="0.055"):
        add('[node name="%s" type="Area2D" parent="Visuals"]\n' % name)
        add("position = Vector2(%d, %d)\nscript = %s\ntag = &\"%s\"\n\n" % (pos[0], pos[1], SENSED, tag))
        add('[node name="CollisionShape2D" type="CollisionShape2D" parent="Visuals/%s"]\nshape = SubResource("Circle_1")\n\n' % name)
        add('[node name="Sprite" type="Sprite2D" parent="Visuals/%s"]\nscale = Vector2(%s, %s)\ntexture = %s\n\n' % (name, scale, scale, texture))

    if has_robot:
        for k, p in enumerate(placed):
            area("Destination%d" % (k + 1), center(p["flag"]), "destination", FLAG, "1")
            for j, pen in enumerate(p["pens"]):
                area("Pen%d_%d" % (k + 1, j + 1), center(pen), "undetectable", PEN, "1")

    # One board per room for each list, all under the same names; the name
    # block a student drags finds the running room's board by room_index.
    add('[node name="Lists" type="Node2D" parent="Visuals"]\n\n')
    for k, p in enumerate(placed):
        add('[node name="Room%d" type="Node2D" parent="Visuals/Lists"]\n\n' % (k + 1))
        for l, (bx, by), standing in p["boards"]:
            add('[node name="%s" parent="Visuals/Lists/Room%d" instance=%s]\n' % (l["name"], k + 1, BOARD))
            add("position = Vector2(%d, %d)\n" % (bx, by))
            if not standing:
                # On the wall face, which the y-sorted Walls layer draws later.
                add("z_index = 1\n")
            add("room_index = %d\nvalues = %s\n" % (k, arr(l["values"])))
            if standing:
                add("standing = true\n")
            add("\n")

    add('[node name="YSorted" type="Node2D" parent="Visuals"]\ny_sort_enabled = true\n\n')
    if furniture:
        add('[node name="Furniture" type="TileMapLayer" parent="Visuals/YSorted"]\ny_sort_enabled = true\n')
        add('tile_map_data = PackedByteArray("%s")\ntile_set = %s\n\n' % (encode(furniture), FURNITURE))
    if has_robot:
        starts = [center(p["start"]) for p in placed]
        # Boards on a wall face draw above the walls (z 1); the robot, whose head
        # reaches up into the wall row, stands in front of them.
        robot_z = "z_index = 2\n"
        add('[node name="RobotCharacter" parent="Visuals/YSorted" instance=%s]\n' % ROBOT)
        add("%sposition = Vector2(%d, %d)\nfacing_direction = Vector2(1, 0)\n\n" % ((robot_z,) + starts[0]))
        add('[node name="AnimatedSprite2D" parent="Visuals/YSorted/RobotCharacter" index="0"]\nanimation = &"idle_right"\n\n')
        add('[node name="BlockProvider" parent="Visuals/YSorted/RobotCharacter" index="2"]\n')
        add("block_data = Array[%s]([%s])\n\n" % (DATA, ", ".join(blk(b) for b in spec["robot"])))
        add('[node name="ResettableComponent" type="Node" parent="Visuals/YSorted/RobotCharacter" index="4" node_paths=PackedStringArray("base")]\n')
        add('script = %s\nbase = NodePath("..")\n' % RESET)
        add('tracked_properties = PackedStringArray("facing_direction", "transform")\n')
        add("room_snapshots = Array[Dictionary]([%s])\n\n" % ", ".join(
            'Dictionary[StringName, Variant]({\n&"facing_direction": Vector2(1, 0),\n&"transform": Transform2D(1, 0, 0, 1, %d, %d)\n})' % s
            for s in starts))
    add('[node name="Walls" type="TileMapLayer" parent="Visuals/YSorted"]\ny_sort_enabled = true\n')
    add('tile_map_data = PackedByteArray("%s")\ntile_set = %s\n\n' % (encode(walls), WALLS))
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


def briefs_gd():
    """The LevelBriefs entries, to paste over the table's Arrays section."""
    lines = []
    for key, s in LEVELS.items():
        lines.append('\t"%s": {' % key)
        lines.append('\t\t"title": "%s",' % esc(s["title"]))
        lines.append('\t\t"mission": "%s",' % esc(s["mission"]))
        if s["twist"]:
            lines.append('\t\t"twist": "%s",' % esc(s["twist"]))
        if s["rooms_text"]:
            lines.append('\t\t"rooms": [%s],' % ", ".join('"%s"' % esc(r) for r in s["rooms_text"]))
        if s["blocks"]:
            lines.append('\t\t"blocks": [%s],' % ", ".join('"%s"' % BLK[b] for b in s["blocks"]))
            lines.append('\t\t"block_notes": [%s],' % ", ".join('"%s"' % esc(n) for n in s["notes"]))
            if s.get("block_values"):
                lines.append('\t\t"block_values": [%s],' % ", ".join('"%s"' % esc(v) for v in s["block_values"]))
        lines.append('\t\t"tip": "%s",' % esc(s["tip"]))
        if s.get("show_stars") is False:
            lines.append('\t\t"show_stars": false,')
        lines.append("\t},")
    return "\n".join(lines)


def zoom_report():
    lines = []
    for key, spec in LEVELS.items():
        blocks, best, tried = layout(spec)
        cells = ", ".join("%s %.2f" % (how, z) for z, how, _at, _size in tried)
        lines.append("%-6s %-15s %.2f   (%s)" % (key, best[1], best[0], cells))
    return "\n".join(lines)


HAND_MADE = {"ar_3"}  # reworked by hand in the editor; never overwritten

if __name__ == "__main__":
    for key, spec in LEVELS.items():
        if key not in HAND_MADE:
            build(key, spec)
    tmp = os.environ.get("TEMP", ".")
    with open(os.path.join(tmp, "ar_briefs.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(briefs_gd())
    json.dump({k: dict(id=s["id"], label=s["label"], title=s["title"], concept=s["concept"], counts=s.get("counts", True))
               for k, s in LEVELS.items()},
              open(os.path.join(tmp, "ar_catalog.json"), "w"), indent=1)
    print(zoom_report())
    print("wrote", ", ".join(k for k in LEVELS if k not in HAND_MADE))
