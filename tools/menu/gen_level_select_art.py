"""Draws level select's art into menus/level select/art/: the 9-slices its
buttons and level tiles are skinned with (pixel_panels.png, for main_theme.tres's
PixelButton, PixelButtonDark, LevelTile, LevelTileNext and AssistantBubble),
the stars and lock on the tiles, the arrow over the next level to play, and the
buttons' icons. The win card's summary (level_complete.tscn) sits in the bubble,
beside the assistant's badge, with the bubble's tail.

    python tools/menu/gen_level_select_art.py <project root>

On a 4 px grid: a panel's outline is 4 px on its four sides, with the 4x4
corners left empty so they look notched, and a darker band along the bottom
of its face. Hovered, the band is 4 px taller; pressed, it moves to the top.
The stars, lock and house are drawn at 3x, the chevrons and arrow at 4x; the
white ones are tinted by the theme.
"""
import os, sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, "..", "arrays"))
import pngtool  # noqa: E402

OUT = os.path.join(root, "menus/level select/art")


def rgb(code):
    return (int(code[0:2], 16), int(code[2:4], 16), int(code[4:6], 16), 255)


CLEAR = (0, 0, 0, 0)
NAVY = rgb("0e1733")
PAPER = rgb("f4f8fd")
PAPER_BAND = rgb("b9c8de")
DARK = rgb("1b2742")
DARK_LINE = rgb("2e3f63")
DARK_BAND = rgb("131c32")
CYAN = rgb("5ef0f2")
WHITE = rgb("ffffff")
DIM = rgb("4a6385")
GOLD = rgb("ffd14d")
GOLD_HI = rgb("ffeca0")
GOLD_LO = rgb("e0a028")
BUBBLE = rgb("121a2e")
EMPTY = rgb("d6e0ee")

LINE = 4
CELL = (16, 32)
RING_CELL = (24, 40)
# (name, face, outline, band, band height, state, ring). A state is normal,
# hover (the band 4 px taller) or pressed (the band along the top instead).
PANELS = [
    ("light_normal", PAPER, NAVY, PAPER_BAND, 6, "normal", False),
    ("light_hover", PAPER, NAVY, PAPER_BAND, 6, "hover", False),
    ("light_pressed", PAPER, NAVY, PAPER_BAND, 6, "pressed", False),
    ("dark_normal", DARK, DARK_LINE, DARK_BAND, 6, "normal", False),
    ("dark_hover", DARK, DARK_LINE, DARK_BAND, 6, "hover", False),
    ("dark_pressed", DARK, DARK_LINE, DARK_BAND, 6, "pressed", False),
    ("tile_normal", PAPER, NAVY, PAPER_BAND, 8, "normal", False),
    ("tile_hover", PAPER, NAVY, PAPER_BAND, 8, "hover", False),
    ("tile_pressed", PAPER, NAVY, PAPER_BAND, 8, "pressed", False),
    ("tile_locked", DARK, DARK_LINE, DARK_BAND, 8, "normal", False),
    ("next_normal", PAPER, NAVY, PAPER_BAND, 8, "normal", True),
    ("next_hover", PAPER, NAVY, PAPER_BAND, 8, "hover", True),
    ("next_pressed", PAPER, NAVY, PAPER_BAND, 8, "pressed", True),
    ("bubble", BUBBLE, DARK_LINE, BUBBLE, 0, "normal", False),
]

# At 3x. O is the navy outline, Y gold, H its highlight, S its shade, X the
# icon's one colour.
STAR = ["....O....",
        "...OHO...",
        "OOOOHOOOO",
        "OHHHYYYYO",
        ".OHYYYSO.",
        "..OYYYO..",
        ".OYYOYSO.",
        ".OYO.OSO.",
        ".OO...OO."]
LOCK = ["..XXX..",
        ".X...X.",
        ".X...X.",
        "XXXXXXX",
        "XXX.XXX",
        "XXX.XXX",
        "XXXXXXX"]
HOME = ["....X....",
        "...X.X...",
        "..X...X..",
        ".X.....X.",
        "XX.....XX",
        ".X.....X.",
        ".X.XXX.X.",
        ".X.X.X.X.",
        ".XXX.XXX."]
CHEVRON = ["..X",
           ".XX",
           "XX.",
           ".XX",
           "..X"]
# At 4x, like the panels: the chevron above, and this over the next level to play.
ARROW = ["OOOOOOO",
         "OCCCCCO",
         ".OCCCO.",
         "..OCO..",
         "...O..."]


# At 4x: the assistant, on its badge.
ROBOT = ["....X....",
         ".XXXXXXX.",
         ".X.....X.",
         "XX.X.X.XX",
         ".X.....X.",
         ".XXXXXXX."]
# At 4x: the bubble's tail, pointing left at the badge. Its right column lies
# on the bubble's outline, opening it where the tail joins.
TAIL = ["..O",
        ".OF",
        "OFF",
        ".OF",
        "..O"]
BADGE = 52


def notched(img, x0, y0, w, h, color):
    """A filled `w` x `h` box with its LINE x LINE corners left empty."""
    for y in range(h):
        for x in range(w):
            if (x < LINE or x >= w - LINE) and (y < LINE or y >= h - LINE):
                continue
            img[y0 + y][x0 + x] = color


def panel(img, x0, y0, w, h, face, outline, band, band_h, state):
    notched(img, x0, y0, w, h, outline)
    if state == "hover":
        band_h += 4
    for y in range(LINE, h - LINE):
        if state == "pressed":
            in_band = y < LINE + band_h
        else:
            in_band = y >= h - LINE - band_h
        for x in range(LINE, w - LINE):
            img[y0 + y][x0 + x] = band if in_band else face


def panels():
    W = sum(RING_CELL[0] if p[6] else CELL[0] for p in PANELS)
    H = RING_CELL[1]
    img = [[CLEAR] * W for _ in range(H)]
    x = 0
    print("pixel_panels.png regions (margins are left, top, right, bottom):")
    for name, face, outline, band, band_h, state, ring in PANELS:
        w, h = RING_CELL if ring else CELL
        pad = LINE if ring else 0
        if ring:
            # The ring: a notched box a line bigger all round, under the panel,
            # so the panel's own notches show it.
            notched(img, x, 0, w, h, CYAN)
        panel(img, x + pad, pad, w - 2 * pad, h - 2 * pad, face, outline, band, band_h, state)
        grown = band_h + (4 if state == "hover" else 0)
        top = pad + LINE + (grown if state == "pressed" else 0)
        bottom = pad + LINE + (0 if state == "pressed" else grown)
        print("  %-14s Rect2(%d, 0, %d, %d)  margins %d, %d, %d, %d" % (
            name, x, w, h, pad + LINE, top, pad + LINE, bottom))
        x += w
    pngtool.save(os.path.join(OUT, "pixel_panels.png"), W, H, img)


def icon(name, art, palette, scale, even=False):
    """`even` pads an odd side by a clear pixel, so a button centring the icon
    puts it on whole pixels."""
    w, h = len(art[0]) * scale, len(art) * scale
    W, H = (w + w % 2, h + h % 2) if even else (w, h)
    out = [[palette.get(art[y // scale][x // scale], CLEAR) if x < w and y < h else CLEAR
            for x in range(W)] for y in range(H)]
    pngtool.save(os.path.join(OUT, name + ".png"), W, H, out)
    print("%s.png: %dx%d px" % (name, W, H))


os.makedirs(OUT, exist_ok=True)
panels()
icon("star_full", STAR, {"O": NAVY, "Y": GOLD, "H": GOLD_HI, "S": GOLD_LO}, 3)
icon("star_empty", STAR, {"O": NAVY, "Y": EMPTY, "H": EMPTY, "S": EMPTY}, 3)
icon("lock", LOCK, {"X": DIM}, 3)
icon("icon_home", HOME, {"X": WHITE}, 3, even=True)
icon("chevron_left", CHEVRON, {"X": WHITE}, 4)
icon("chevron_right", [row[::-1] for row in CHEVRON], {"X": WHITE}, 4)
icon("next_arrow", ARROW, {"O": NAVY, "C": CYAN}, 4)
icon("bubble_tail", TAIL, {"O": DARK_LINE, "F": BUBBLE}, 4)


def badge():
    """The assistant's badge: a notched box in a cyan outline, the robot in it."""
    img = [[CLEAR] * BADGE for _ in range(BADGE)]
    notched(img, 0, 0, BADGE, BADGE, CYAN)
    for y in range(LINE, BADGE - LINE):
        for x in range(LINE, BADGE - LINE):
            img[y][x] = BUBBLE
    w, h = len(ROBOT[0]) * 4, len(ROBOT) * 4
    x0, y0 = (BADGE - w) // 2, (BADGE - h) // 2
    for y in range(h):
        for x in range(w):
            if ROBOT[y // 4][x // 4] == "X":
                img[y0 + y][x0 + x] = CYAN
    pngtool.save(os.path.join(OUT, "assistant_badge.png"), BADGE, BADGE, img)
    print("assistant_badge.png: %dx%d px" % (BADGE, BADGE))


badge()


# The assistant beside its messages in the chat, at 3x: a notched box in the
# blue of its bubbles (ai_assistant.tscn's bubble_theme_ai), the robot in it.
CHAT_BLUE = rgb("63cbf7")
CHAT_ROBOT = ["....X....",
              ".XXXXXXX.",
              ".X.....X.",
              "XX.X.X.XX",
              ".X.....X.",
              ".X.XXX.X.",
              ".XXXXXXX."]


def chat_avatar():
    side = 13
    art = [["F"] * side for _ in range(side)]
    for y in range(side):
        for x in range(side):
            edge_x, edge_y = x in (0, side - 1), y in (0, side - 1)
            if edge_x and edge_y:
                art[y][x] = "."
            elif edge_x or edge_y:
                art[y][x] = "O"
    x0, y0 = (side - len(CHAT_ROBOT[0])) // 2, (side - len(CHAT_ROBOT)) // 2
    for y, row in enumerate(CHAT_ROBOT):
        for x, cell in enumerate(row):
            if cell == "X":
                art[y0 + y][x0 + x] = "O"
    icon("chat_avatar", ["".join(row) for row in art], {"O": CHAT_BLUE, "F": BUBBLE}, 3)


chat_avatar()
