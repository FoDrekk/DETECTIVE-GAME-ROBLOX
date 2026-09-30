#!/usr/bin/env python3
"""
Plot the walkable floor's clearance from entry_layout_metrics.luau's grid.

  luau metrics.luau -a map > cells.txt
  python3 plot_clearance.py cells.txt clearance.png

Solid cells are dark red; walkable floor runs from a tight orange (a stud clear
either side) through yellow to green (six or more studs clear); floor the
spawn can't reach is left grey. Requires pillow.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 12


def main(cells_path, out_path):
    cells = []
    origin = None
    for line in Path(cells_path).read_text().splitlines():
        f = line.split("|")
        if f[0] == "CELL":
            cells.append((int(f[1]), int(f[2]), int(f[3])))
        elif f[0] == "ORIGIN":
            origin = (int(f[1]), int(f[2]), int(f[3]), int(f[4]))
    x0, z0, nx, nz = origin
    img = Image.new("RGB", (nx * SCALE, nz * SCALE), (30, 30, 34))
    draw = ImageDraw.Draw(img)
    for ix, iz, value in cells:
        if value == -1:
            color = (120, 36, 36)
        elif value == 0:
            color = (52, 52, 58)
        elif value < 2:
            color = (232, 120, 40)
        elif value < 3:
            color = (232, 196, 60)
        elif value < 4:
            color = (170, 210, 70)
        elif value < 6:
            color = (80, 190, 90)
        else:
            color = (40, 150, 170)
        draw.rectangle([ix * SCALE, iz * SCALE, (ix + 1) * SCALE - 1, (iz + 1) * SCALE - 1], fill=color)
    for gx in range(0, nx, 10):
        draw.line([(gx * SCALE, 0), (gx * SCALE, nz * SCALE)], fill=(80, 80, 90))
        draw.text((gx * SCALE + 2, 2), str(x0 + gx), fill=(200, 200, 210))
    for gz in range(0, nz, 10):
        draw.line([(0, gz * SCALE), (nx * SCALE, gz * SCALE)], fill=(80, 80, 90))
        draw.text((2, gz * SCALE + 2), str(z0 + gz), fill=(200, 200, 210))
    img.save(out_path)
    print("wrote", out_path, img.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
