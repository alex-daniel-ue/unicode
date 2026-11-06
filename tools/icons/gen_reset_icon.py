"""Draws the room's Reset button icon, a loop arrow (one arrow coming round
back to itself), into puzzle/ui/side panel/bottom buttons/reset/reset.png.

    python tools/icons/gen_reset_icon.py <project root>

Drawn the way the side panel's pixelarticons are: white, 512 px square, on a
12-pixel grid with 1-pixel strokes and a solid arrowhead like the undo icon's,
so the theme tints it as it does the run, speed and stop buttons.
"""
import os, sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, "..", "arrays"))
import pngtool  # noqa: E402

OUT = os.path.join(root, "puzzle/ui/side panel/bottom buttons/reset/reset.png")

ART = ["............",
       "......#.....",
       "......##....",
       "....#####...",
       "...#..##....",
       "..#...#.....",
       "..#......#..",
       "..#......#..",
       "..#......#..",
       "...#....#...",
       "....####....",
       "............"]
SIZE = 512
CELL = 42  # 12 cells of 42 px, centred: whole pixels, so the edges stay hard


def main():
    margin = (SIZE - len(ART) * CELL) // 2
    img = [[(0, 0, 0, 0)] * SIZE for _ in range(SIZE)]
    for gy, row in enumerate(ART):
        for gx, cell in enumerate(row):
            if cell != "#":
                continue
            for y in range(margin + gy * CELL, margin + (gy + 1) * CELL):
                for x in range(margin + gx * CELL, margin + (gx + 1) * CELL):
                    img[y][x] = (255, 255, 255, 255)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    pngtool.save(OUT, SIZE, SIZE, img)
    print("reset.png: %dx%d px" % (SIZE, SIZE))


main()
