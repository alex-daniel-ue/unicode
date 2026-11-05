"""Rooms for the module generator (gen_modules.py), as data: where the robot
walks, the flag, the batteries, the terminal's typed lines and the lines it
should show, and signs on the floor. No Godot here, and nothing written.

Tile coordinates are inside the room's floor, (0, 0) its top-left tile. The
robot starts facing right, as in every generated level.
"""
import math

T = 32

# Kenney Mini's advance at 16 px for ASCII 32..126 (no kerning), so the room is
# sized to the terminal TerminalEntity will draw. Measured from the font.
ADV = [4, 4, 8, 12, 10, 12, 12, 4, 6, 6, 8, 8, 4, 8, 4, 12, 10, 6, 10, 10, 10, 10, 10, 10, 10, 10, 4, 4,
       8, 8, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 4, 8, 10, 8, 12, 10, 10, 10, 10, 10, 10, 8, 10,
       12, 12, 10, 10, 10, 6, 12, 6, 8, 10, 10, 10, 10, 10, 10, 10, 8, 10, 10, 4, 8, 10, 6, 12, 10, 10,
       10, 10, 10, 10, 8, 10, 12, 12, 10, 10, 10, 8, 4, 8, 10]


def text_w(s):
    return sum(ADV[ord(c) - 32] if 32 <= ord(c) < 127 else 10 for c in s)


def terminal_px(term):
    """TerminalEntity.size_for() with legs, for its typed lines and goal lines."""
    rows = max(1, len(term["expected"] or []))
    widest = max([text_w(l) for l in term["expected"] or []] + [0])
    strip = 30 + sum(text_w(i) + 8 + 4 for i in term["inputs"])
    screen_w = max(120, widest + 12, strip + 6)
    h = 4 * 2 + 6 * 2 + rows * 20 + (26 if term["inputs"] else 0) + 8
    return screen_w + 8, h


def term(inputs=(), expected=None):
    """A terminal: what the user types, and what the screen should show
    (None: no goal on it, as when the room only reads from it)."""
    return dict(inputs=[str(i) for i in inputs], expected=None if expected is None else [str(e) for e in expected])


def screen(expected, inputs=(), dicts=(), files=()):
    """A room that is only a terminal, and any dictionaries and files beside it."""
    has_terminal = expected is not None or bool(inputs)
    return dict(terminal=term(inputs, expected) if has_terminal else None, robot=None, walk_w=0, walk_h=0, signs=[],
                dicts=list(dicts), files=list(files))


def board(name, entries, expected=None):
    """A dictionary: its name, its (key, value) pairs in order, and the pairs
    it should end up with (None: no goal on it)."""
    return dict(name=name, entries=list(entries), expected=None if expected is None else list(expected))


def hall(steps, length, terminal=None, pens=()):
    """A straight hallway `length` tiles long: the robot at its left end facing
    right, the flag `steps` tiles on, and a row for desks below."""
    path = [(x, 0) for x in range(length)]
    robot = dict(start=(0, 0), flag=(steps, 0), pens=list(pens), path=path)
    return dict(terminal=terminal, robot=robot, walk_w=length, walk_h=2, signs=[])


def route(legs, terminal=None, pad=1):
    """Drive `legs` from (0, 0) facing right, turning left after each leg
    (gen_arrays.walk), the flag at the end of the last one."""
    x = y = 0
    dx, dy = 1, 0
    seen = [(0, 0)]
    for leg in legs:
        for _ in range(leg):
            x, y = x + dx, y + dy
            seen.append((x, y))
        dx, dy = dy, -dx
    minx = min(p[0] for p in seen); miny = min(p[1] for p in seen)
    maxx = max(p[0] for p in seen); maxy = max(p[1] for p in seen)
    shift = lambda p: (p[0] - minx, p[1] - miny)
    path = [shift(p) for p in seen]
    robot = dict(start=shift((0, 0)), flag=path[-1], pens=[], path=path)
    return dict(terminal=terminal, robot=robot, walk_w=maxx - minx + 1 + pad, walk_h=maxy - miny + 1 + pad, signs=[])


def walk(moves, terminal=None, pens_at=(), pad=1):
    """A path the robot drives: F steps forward, L and R turn (robot.gd's
    turns), from (0, 0) facing right. The flag is where it ends; a battery sits
    where the n-th step (counted from 1) lands, for each n in pens_at, so a
    route that skips the path misses one."""
    x = y = 0
    dx, dy = 1, 0
    seen = [(0, 0)]
    steps = []
    for move in moves:
        if move == "F":
            x, y = x + dx, y + dy
            seen.append((x, y))
            steps.append((x, y))
        elif move == "L":
            dx, dy = dy, -dx
        elif move == "R":
            dx, dy = -dy, dx
    minx = min(p[0] for p in seen); miny = min(p[1] for p in seen)
    maxx = max(p[0] for p in seen); maxy = max(p[1] for p in seen)
    shift = lambda p: (p[0] - minx, p[1] - miny)
    path = [shift(p) for p in seen]
    pens = [shift(steps[n - 1]) for n in pens_at]
    robot = dict(start=shift((0, 0)), flag=path[-1], pens=pens, path=path)
    return dict(terminal=terminal, robot=robot, walk_w=maxx - minx + 1 + pad, walk_h=maxy - miny + 1 + pad, signs=[])


def junction(goal, terminal=None, signs=None):
    """A hall into a crossing: two tiles on, a branch goes up (left of the
    robot) one tile, the hall goes on two more tiles, and a branch goes down
    (right of the robot) one tile. The flag is at the end of `goal`: "left",
    "straight" or "right". Signs name each end when given, {end: text}."""
    ends = {"left": (2, 0), "straight": (4, 1), "right": (2, 2)}
    path = [(0, 1), (1, 1), (2, 1), (2, 0), (2, 2), (3, 1), (4, 1)]
    robot = dict(start=(0, 1), flag=ends[goal], pens=[], path=path)
    placed = []
    for end, text in (signs or {}).items():
        placed.append((ends[end], text))
    # Seven wide: a sign stands to the right of each end, and the hall's end has one too.
    return dict(terminal=terminal, robot=robot, walk_w=7, walk_h=3, signs=placed)


def floor_tiles(room):
    """Every tile the robot may stand on or that must stay clear."""
    r = room["robot"]
    if not r:
        return set()
    tiles = set(r["path"]) | {r["start"], r["flag"]} | set(r["pens"])
    return tiles


def py_repr(value):
    """A key or value as Python writes it, as DictEntity draws it."""
    if isinstance(value, str):
        return "'%s'" % value
    if isinstance(value, bool):
        return "True" if value else "False"
    return str(value)


def dict_px(board):
    """DictEntity._size() for its entries and the rows its goal adds."""
    entries = board["entries"]
    target = board.get("expected") or []
    keys = [k for k, _v in entries] + [k for k, _v in target if k not in [e for e, _ in entries]]
    key_w, value_w = 30, 30
    for key in keys:
        key_w = max(key_w, text_w(py_repr(key)) + 10)
    for _key, value in entries:
        value_w = max(value_w, text_w(py_repr(value)) + 10)
    for _key, value in target:
        value_w = max(value_w, text_w(py_repr(value)) + 10 + 30)
    name_w = text_w(board["name"]) + 10
    w = max(name_w, key_w + 16 + value_w) + 12
    h = 6 + 26 + 4 + max(len(keys), 1) * 24 + 6
    return w, h


def file_px(f):
    """FileEntity._size() for its lines and the lines its goal adds."""
    lines, expected = f["lines"], f.get("expected") or []
    widest = text_w(f["name"]) + 12
    for line in lines + expected:
        widest = max(widest, text_w(line) + 22 + 12)
    rows = max(1, len(lines), len(expected))
    return max(110, widest), 22 + 6 + rows * 20 + 6


def textfile(name, lines, expected=None):
    """A text file: its name, its lines, and the lines it should end up with
    (None: no goal on it)."""
    return dict(name=name, lines=[str(l) for l in lines], expected=None if expected is None else [str(e) for e in expected])


def boards_px(room):
    """The width and height of the band's contents: the terminal, then each
    dictionary and each file to its right."""
    parts = []
    if room["terminal"]:
        parts.append(terminal_px(room["terminal"]))
    for board in room.get("dicts", []):
        parts.append(dict_px(board))
    for f in room.get("files", []):
        parts.append(file_px(f))
    if not parts:
        return 0, 0
    return sum(w for w, _h in parts) + 12 * (len(parts) - 1), max(h for _w, h in parts)


def band_rows(room):
    _w, h = boards_px(room)
    return math.ceil((h + 12) / T) if h else 0
