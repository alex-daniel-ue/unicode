"""Draws the main menu's art into menus/main/art/: the title logo, recoloured
from menus/main/logo.png ("UNI" cyan, "CODE" white, outlined in ink with a
drop shadow under it), the buttons' skins (title_buttons.png: the gold Start
and the white others, each normal, hover and pressed, as 9-slices for
main_theme.tres's TitleButton and TitleStartButton) and the buttons' icons.

    python tools/menu/gen_menu_art.py <project root>

Drawn a pixel to a pixel: the menu scales the logo by whole numbers and a
9-slice keeps its edges as they are, so the pixels stay square.
"""
import os, sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, "..", "arrays"))
import pngtool  # noqa: E402

OUT = os.path.join(root, "menus/main/art")


def rgb(code):
    return (int(code[0:2], 16), int(code[2:4], 16), int(code[4:6], 16), 255)


CLEAR = (0, 0, 0, 0)
INK = rgb("141e33")
# A letter's face, the row along its top and the row along its bottom.
CYAN = dict(face=rgb("6ce1e7"), top=rgb("b4f6f6"), bottom=rgb("3fb3c6"))
WHITE = dict(face=rgb("eef3fa"), top=rgb("ffffff"), bottom=rgb("aebfd6"))
# The logo's columns left of this are UNI, the rest CODE.
SPLIT = 89

# A button's face, the highlight along its top and the lip along its bottom.
GOLD = [dict(face=rgb("ffcf4a"), top=rgb("ffe594"), lip=rgb("d4952a")),   # normal
        dict(face=rgb("ffdb70"), top=rgb("fff0bd"), lip=rgb("dea338")),   # hover
        dict(face=rgb("f0bc36"), top=rgb("f6cb5c"), lip=rgb("c0841f"))]   # pressed
PLAIN = [dict(face=rgb("eef3fa"), top=rgb("ffffff"), lip=rgb("a7b6cc")),
         dict(face=rgb("ffffff"), top=rgb("ffffff"), lip=rgb("b6c4d8")),
         dict(face=rgb("dce4ef"), top=rgb("e8eef6"), lip=rgb("98a8c0"))]
CELL = 24
LIP = 4

ICONS = {
    "icon_play": ["X....",
                  "XX...",
                  "XXX..",
                  "XXXX.",
                  "XXXXX",
                  "XXXX.",
                  "XXX..",
                  "XX...",
                  "X...."],
    "icon_star": ["....X....",
                  "...XXX...",
                  "...XXX...",
                  "XXXXXXXXX",
                  ".XXXXXXX.",
                  "..XXXXX..",
                  "..XXXXX..",
                  ".XXX.XXX.",
                  ".XX...XX."],
    "icon_exit": ["XXXXX....",
                  "X........",
                  "X.....X..",
                  "X.....XX.",
                  "X.XXXXXXX",
                  "X.....XX.",
                  "X.....X..",
                  "X........",
                  "XXXXX...."],
}
ICON_SCALE = 2


def logo():
    w, h, px = pngtool.load(os.path.join(root, "menus/main/logo.png"))
    # Solid where the source is mostly opaque: its soft edges are dropped, so
    # the outline hugs a hard edge. Dark pixels are the letters; the few light
    # ones are lines drawn inside them, which become ink.
    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and px[y][x][3] >= 128

    def letter(x, y):
        return solid(x, y) and sum(px[y][x][:3]) < 384

    def near(x, y):
        return any(solid(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))

    # One pixel of outline round the letters, and a second along the bottom
    # for the shadow.
    W, H = w + 2, h + 3
    out = []
    for Y in range(H):
        row = []
        for X in range(W):
            x, y = X - 1, Y - 1
            if letter(x, y):
                tone = CYAN if x < SPLIT else WHITE
                if not letter(x, y + 1):
                    row.append(tone["bottom"])
                elif not letter(x, y - 1):
                    row.append(tone["top"])
                else:
                    row.append(tone["face"])
            elif solid(x, y) or near(x, y) or near(x, y - 1):
                row.append(INK)
            else:
                row.append(CLEAR)
        out.append(row)
    pngtool.save(os.path.join(OUT, "title_logo.png"), W, H, out)
    print("title_logo.png: %dx%d px" % (W, H))


def button(look):
    """One 9-slice: an ink outline with stepped corners, a highlight under the
    top edge and a lip over the bottom one. Its margins in main_theme.tres are
    4 px, and 8 px at the bottom for the lip."""
    cell = []
    for y in range(CELL):
        row = []
        for x in range(CELL):
            dx, dy = min(x, CELL - 1 - x), min(y, CELL - 1 - y)
            if dx < 2 and dy < 2:
                row.append(CLEAR)
            elif dx < 2 or dy < 2 or (dx < 4 and dy < 4):
                row.append(INK)
            elif y >= CELL - 2 - LIP:
                row.append(look["lip"])
            elif y < 4:
                row.append(look["top"])
            else:
                row.append(look["face"])
        cell.append(row)
    return cell


def buttons():
    # A row a button: gold, then plain. A column a state: normal, hover, pressed.
    rows = [GOLD, PLAIN]
    W, H = CELL * 3, CELL * len(rows)
    out = [[CLEAR] * W for _ in range(H)]
    for r, looks in enumerate(rows):
        for c, look in enumerate(looks):
            for y, line in enumerate(button(look)):
                out[r * CELL + y][c * CELL:(c + 1) * CELL] = line
    pngtool.save(os.path.join(OUT, "title_buttons.png"), W, H, out)
    print("title_buttons.png: %dx%d px" % (W, H))


def icons():
    for name, art in ICONS.items():
        W, H = len(art[0]) * ICON_SCALE, len(art) * ICON_SCALE
        out = [[INK if art[y // ICON_SCALE][x // ICON_SCALE] == "X" else CLEAR for x in range(W)]
               for y in range(H)]
        pngtool.save(os.path.join(OUT, name + ".png"), W, H, out)
        print("%s.png: %dx%d px" % (name, W, H))


os.makedirs(OUT, exist_ok=True)
logo()
buttons()
icons()
