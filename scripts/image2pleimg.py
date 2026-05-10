#!/usr/bin/env python3

# ========================================================================
# img2pleimg.py -- convert images into PLE 64x64 logo (.raw) files
# ========================================================================
# Usage: scripts/img2pleimg.py <input.png|jpg|...> <output.raw>
# ========================================================================

import sys
import os

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("error: this script requires Pillow (pip install Pillow)\n")
    sys.exit(1)


EGA_PALETTE = [
    (0,   0,   0),     # 0  black
    (0,   0,   170),   # 1  blue
    (0,   170, 0),     # 2  green
    (0,   170, 170),   # 3  cyan
    (170, 0,   0),     # 4  red
    (170, 0,   170),   # 5  magenta
    (170, 85,  0),     # 6  brown
    (170, 170, 170),   # 7  light gray
    (85,  85,  85),    # 8  dark gray
    (85,  85,  255),   # 9  light blue
    (85,  255, 85),    # 10 light green
    (85,  255, 255),   # 11 light cyan
    (255, 85,  85),    # 12 light red
    (255, 85,  255),   # 13 light magenta
    (255, 255, 85),    # 14 yellow
    (255, 255, 255),   # 15 white
]


def nearest_ega(rgb):
    """Return the index of the EGA colour closest to rgb (squared distance)."""
    r, g, b = rgb
    best_i = 0
    best_d = 1 << 30
    for i, (pr, pg, pb) in enumerate(EGA_PALETTE):
        dr = r - pr
        dg = g - pg
        db = b - pb
        d = dr*dr + dg*dg + db*db
        if d < best_d:
            best_d = d
            best_i = i
    return best_i


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("usage: img2pleimg.py <input> <output.raw>\n")
        sys.exit(1)

    in_path, out_path = sys.argv[1], sys.argv[2]

    if not os.path.exists(in_path):
        sys.stderr.write(f"error: input file not found: {in_path}\n")
        sys.exit(1)

    img = Image.open(in_path).convert("RGB")
    img = img.resize((64, 64), Image.LANCZOS)

    data = bytearray(64 * 64)
    px = img.load()
    for y in range(64):
        for x in range(64):
            data[y * 64 + x] = nearest_ega(px[x, y])

    with open(out_path, "wb") as f:
        f.write(data)

    print(f"wrote {len(data)} bytes -> {out_path}")


if __name__ == "__main__":
    main()
