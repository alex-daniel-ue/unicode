"""Draws the block textures with their connectors: a V notch cut into the top
of every block that stacks, and a V point hanging under it, so a block shows
where it fits. The point of one block sits in the notch of the block under it.

    python tools/blocks/gen_connectors.py <project root>

Writes, in puzzle/ui/block/templates/:
  block.png                  a statement block: notch on top, point under it
  nested/nested_texture.png  the for/while/if block, in three bands: the upper
                             lip (notch on top, a point into the mouth), the
                             body (the spine), the lower lip (a notch where the
                             last inner block's point lands, a point under it)
  nested/cap/BeginBlock.png  begin: its hat as drawn, a point under it

Every connector is CONNECTOR_X from the left of its block, and the blocks in a
for block's mouth start MOUTH_X in, so the inner ones sit at MOUTH_X +
CONNECTOR_X. The point hangs POINT_DEPTH under its block's rect: the scenes
draw it with an expand margin and keep it inside the 9-slice's fixed corner,
so a long block stretches only past it. The scenes' slices are printed.

The art is the blocks' own: a 4 px outline, a 4 px bevel, a white face that the
block's colour tints. Drawn from scratch each time, except the begin hat, whose
top is kept from the file and whose bottom is redrawn, so running this twice
gives the same files.
"""
import os, sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, "..", "arrays"))
import pngtool  # noqa: E402

TEMPLATES = os.path.join(root, "puzzle/ui/block/templates")

CONNECTOR_X = 16
CONNECTOR_W = 16
POINT_DEPTH = 8
MOUTH_X = 28
LINE = 4

CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)


def rgb(code):
    return (int(code[0:2], 16), int(code[2:4], 16), int(code[4:6], 16), 255)


# Each texture's own palette, as it was drawn.
BLOCK = dict(ink=rgb("222034"), bevel=rgb("a4a7ad"), corner=rgb("7a7d81"))
NESTED = dict(ink=rgb("141020"), bevel=rgb("9e9e9e"), corner=rgb("9e9e9e"))


def v_cells(x0, y0):
    """The V: CONNECTOR_W wide on its first row, narrowing 2 px a side every
    2 rows to a 4 px tip, POINT_DEPTH deep."""
    cells = set()
    for r in range(POINT_DEPTH):
        inset = r - r % 2
        for x in range(x0 + inset, x0 + CONNECTOR_W - inset):
            cells.add((x, y0 + r))
    return cells


def solid(img, x, y):
    return 0 <= y < len(img) and 0 <= x < len(img[0]) and img[y][x][3] > 0


def reshade(img, x0, x1, y0, y1, pal, up):
    """Recolours the block's pixels in columns x0..x1, rows y0..y1 by how far
    the nearest outside pixel is straight above (up) or below: ink within a
    line, bevel within two, face past that. On a 45-degree edge that gives the
    same 4 px outline and bevel as the straight ones."""
    step = -1 if up else 1
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not solid(img, x, y):
                continue
            gap = next((k for k in range(1, 2 * LINE + 1) if not solid(img, x, y + k * step)), None)
            if gap is None:
                img[y][x] = WHITE
            elif gap <= LINE:
                img[y][x] = pal["ink"]
            else:
                img[y][x] = pal["bevel"]


def notch(img, x0, top, pal):
    """Cuts the V into the edge whose first row is `top`, and runs the outline
    and bevel round it."""
    for x, y in v_cells(x0, top):
        img[y][x] = CLEAR
    reshade(img, x0 - LINE, x0 + CONNECTOR_W + LINE, top, top + POINT_DEPTH + 2 * LINE, pal, up=True)


def point(img, x0, below, pal):
    """Hangs the V under the edge whose last row is `below` - 1, filled with
    the block, and runs the outline and bevel round it."""
    for x, y in v_cells(x0, below):
        img[y][x] = WHITE
    reshade(img, x0 - LINE, x0 + CONNECTOR_W + LINE, below - 2 * LINE, below + POINT_DEPTH, pal, up=False)


def canvas(w, h):
    return [[CLEAR] * w for _ in range(h)]


def box(img, x0, y0, w, h, color):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            img[y][x] = color


def statement():
    """block.png: the 100 px block as it was, with the point's rows under it."""
    pal = BLOCK
    w, h = 100, 100
    img = canvas(w, h + POINT_DEPTH)
    box(img, LINE, 0, w - 2 * LINE, h, pal["ink"])
    box(img, 0, LINE, w, h - 2 * LINE, pal["ink"])
    box(img, LINE, LINE, w - 2 * LINE, h - 2 * LINE, pal["bevel"])
    box(img, 2 * LINE, 2 * LINE, w - 4 * LINE, h - 4 * LINE, WHITE)
    for cx in (LINE, w - 2 * LINE):
        for cy in (LINE, h - 2 * LINE):
            box(img, cx, cy, LINE, LINE, pal["corner"])
    notch(img, CONNECTOR_X, 0, pal)
    point(img, CONNECTOR_X, h, pal)
    path = os.path.join(TEMPLATES, "block.png")
    pngtool.save(path, w, h + POINT_DEPTH, img)
    print("block.png: %dx%d px" % (w, h + POINT_DEPTH))
    print("  statement_block.tscn: margins left %d, top %d, right 8, bottom %d; expand_margin_bottom %d" % (
        CONNECTOR_X + CONNECTOR_W + LINE, POINT_DEPTH + 2 * LINE, 2 * LINE + POINT_DEPTH, POINT_DEPTH))


def nested():
    """nested_texture.png: the upper lip, body and lower lip, each its own band
    with room for its point under it."""
    pal = NESTED
    ink, bevel = pal["ink"], pal["bevel"]
    w = 100
    upper_h, body_h, lower_h = 36, 40, 24
    upper_y, body_y = 0, 36 + POINT_DEPTH
    lower_y = body_y + body_h
    img = canvas(w, lower_y + lower_h + POINT_DEPTH)

    def spine(y, h):
        box(img, 0, y, LINE, h, ink)
        box(img, LINE, y, LINE, h, bevel)
        box(img, 2 * LINE, y, 12, h, WHITE)

    # The upper lip: the C's top arm, its mouth edge 32..35 from MOUTH_X on.
    box(img, LINE, upper_y, w - 2 * LINE, LINE, ink)
    box(img, 0, upper_y + LINE, LINE, 32, ink)
    box(img, w - LINE, upper_y + LINE, LINE, 28, ink)
    box(img, LINE, upper_y + LINE, w - 2 * LINE, LINE, bevel)
    box(img, LINE, upper_y + 8, LINE, 28, bevel)
    box(img, 2 * LINE, upper_y + 8, w - 4 * LINE, 20, WHITE)
    box(img, w - 2 * LINE, upper_y + 8, LINE, 20, bevel)
    box(img, 2 * LINE, upper_y + 28, 16, 4, WHITE)
    box(img, 24, upper_y + 28, w - 24 - LINE, 4, bevel)
    box(img, 2 * LINE, upper_y + 32, 12, 4, WHITE)
    box(img, 20, upper_y + 32, 8, 4, bevel)
    box(img, MOUTH_X, upper_y + 32, w - MOUTH_X - LINE, 4, ink)
    notch(img, CONNECTOR_X, upper_y, pal)
    point(img, MOUTH_X + CONNECTOR_X, upper_y + upper_h, pal)

    # The body: the spine, 40 px that stretch with the mouth.
    spine(body_y, body_h)
    box(img, 20, body_y, LINE, body_h, bevel)
    box(img, 24, body_y, LINE, body_h, ink)

    # The lower lip: the C's bottom arm, its top edge from MOUTH_X on.
    y = lower_y
    box(img, 0, y, LINE, 20, ink)
    box(img, LINE, y, LINE, 20, bevel)
    box(img, 2 * LINE, y, 12, 4, WHITE)
    box(img, 20, y, 8, 4, bevel)
    box(img, MOUTH_X, y, w - MOUTH_X, 4, ink)
    box(img, 2 * LINE, y + 4, 16, 4, WHITE)
    box(img, 24, y + 4, w - 24 - LINE, 4, bevel)
    box(img, w - LINE, y + 4, LINE, 16, ink)
    box(img, 2 * LINE, y + 8, w - 4 * LINE, 8, WHITE)
    box(img, w - 2 * LINE, y + 8, LINE, 8, bevel)
    box(img, LINE, y + 16, w - 2 * LINE, 4, bevel)
    box(img, LINE, y + 20, w - 2 * LINE, 4, ink)
    box(img, w - LINE, y, LINE, 4, CLEAR)
    # The shade in the arm's top-right corner, as drawn.
    for sx, sy in [(94, 4), (95, 4), (95, 5)]:
        img[y + sy][sx] = rgb("888b90")
    notch(img, MOUTH_X + CONNECTOR_X, lower_y, pal)
    point(img, CONNECTOR_X, lower_y + lower_h, pal)

    path = os.path.join(TEMPLATES, "nested/nested_texture.png")
    pngtool.save(path, w, len(img), img)
    left = MOUTH_X + CONNECTOR_X + CONNECTOR_W + LINE
    print("nested_texture.png: %dx%d px" % (w, len(img)))
    print("  UpperLip Rect2(0, %d, %d, %d): margins left %d, top %d, right 8, bottom %d; expand_margin_bottom %d" % (
        upper_y, w, upper_h + POINT_DEPTH, left, POINT_DEPTH + 2 * LINE, 2 * LINE + POINT_DEPTH, POINT_DEPTH))
    print("  Body Rect2(0, %d, %d, %d): margins left %d, right 8" % (body_y, w, body_h, MOUTH_X))
    print("  LowerLip Rect2(0, %d, %d, %d): margins left %d, top %d, right 8, bottom %d; expand_margin_bottom %d" % (
        lower_y, w, lower_h + POINT_DEPTH, left, POINT_DEPTH + 2 * LINE, 2 * LINE + POINT_DEPTH, POINT_DEPTH))


def begin():
    """BeginBlock.png: the hat and face as drawn (the first HAT_ROWS rows), its
    bottom bevel and outline redrawn, and the point under them."""
    pal = BLOCK
    path = os.path.join(TEMPLATES, "nested/cap/BeginBlock.png")
    w, h, px = pngtool.load(path)
    body_h = 125
    keep = body_h - 2 * LINE
    img = canvas(w, body_h + POINT_DEPTH)
    for y in range(keep):
        img[y] = list(px[y])
    box(img, 0, keep, LINE, LINE, pal["ink"])
    box(img, LINE, keep, LINE, LINE, pal["corner"])
    box(img, 2 * LINE, keep, w - 4 * LINE, LINE, pal["bevel"])
    box(img, w - 2 * LINE, keep, LINE, LINE, pal["corner"])
    box(img, w - LINE, keep, LINE, LINE, pal["ink"])
    box(img, 0, keep + LINE, w, LINE, pal["ink"])
    point(img, CONNECTOR_X, body_h, pal)
    pngtool.save(path, w, len(img), img)
    print("BeginBlock.png: %dx%d px" % (w, len(img)))
    print("  cap_block.tscn: Rect2(0, 0, %d, %d), bottom margin +%d, expand_margin_bottom %d" % (
        w, len(img), POINT_DEPTH, POINT_DEPTH))


statement()
nested()
begin()
