#!/usr/bin/env python3

# ========================================================================
# image2pcx.py -- convert image into 16-color planar *.PCX
# ========================================================================
# Usage: scripts/image2pcx.py <input.png|jpg|...> <output.pcx>
# ========================================================================

import argparse
import struct
import sys

try:
    import numpy as np
    from PIL import Image, ImageEnhance, ImageFilter
except ImportError:
    sys.stderr.write("error: this script requires Pillow and numpy. Install it pls\n")
    sys.exit(1)


EGA_PALETTE = np.array([
    [0,   0,   0],     # 0  black
    [0,   0,   170],   # 1  blue
    [0,   170, 0],     # 2  green
    [0,   170, 170],   # 3  cyan
    [170, 0,   0],     # 4  red
    [170, 0,   170],   # 5  magenta
    [170, 85,  0],     # 6  brown
    [170, 170, 170],   # 7  light gray
    [85,  85,  85],    # 8  dark gray
    [85,  85,  255],   # 9  light blue
    [85,  255, 85],    # 10 light green
    [85,  255, 255],   # 11 light cyan
    [255, 85,  85],    # 12 light red
    [255, 85,  255],   # 13 light magenta
    [255, 255, 85],    # 14 yellow
    [255, 255, 255],   # 15 white
], dtype=np.float64)

BAYER_8X8 = (
    np.array([
        [0,  32, 8,  40, 2,  34, 10, 42],
        [48, 16, 56, 24, 50, 18, 58, 26],
        [12, 44, 4,  36, 14, 46, 6,  38],
        [60, 28, 52, 20, 62, 30, 54, 22],
        [3,  35, 11, 43, 1,  33, 9,  41],
        [51, 19, 59, 27, 49, 17, 57, 25],
        [15, 47, 7,  39, 13, 45, 5,  37],
        [63, 31, 55, 23, 61, 29, 53, 21],
    ], dtype=np.float64) + 0.5
) / 64.0

SKY_ALLOWED = [1, 3, 6, 7, 9, 11, 12, 14, 15]
FIELD_ALLOWED = [0, 2, 4, 6, 12, 14, 15]
FORBID_SKY = {(6, 15), (6, 7), (6, 11), (6, 9), (6, 3), (6, 1), (12, 3), (12, 1), (12, 9)}


def patch_flare(arr, x0=902, y0=463, x1=916, y1=476):
    out = arr.copy()
    pw = x1 - x0
    left = out[y0:y1, x0 - pw:x0]
    right = out[y0:y1, x1:x1 + pw]
    out[y0:y1, x0:x1] = 0.5 * left + 0.5 * right
    return out


def dither_pair(rgb, pal, allowed, penalty=0.06, forbid_pairs=()):
    h, w = rgb.shape[:2]
    pairs = []
    for i, c1 in enumerate(allowed):
        for c2 in allowed[i:]:
            if (c1, c2) in forbid_pairs or (c2, c1) in forbid_pairs:
                continue
            steps = [0] if c1 == c2 else range(1, 8)
            pdist = np.sqrt(((pal[c1] - pal[c2]) ** 2).sum())
            for k in steps:
                t = k / 8.0
                mix = pal[c1] * (1.0 - t) + pal[c2] * t
                pairs.append((c1, c2, t, mix, pdist))

    mixes = np.array([p[3] for p in pairs], dtype=np.float64)
    pens = np.array([p[4] for p in pairs], dtype=np.float64) * penalty
    c1a = np.array([p[0] for p in pairs], dtype=np.uint8)
    c2a = np.array([p[1] for p in pairs], dtype=np.uint8)
    ta = np.array([p[2] for p in pairs], dtype=np.float64)

    out = np.zeros((h, w), dtype=np.uint8)
    for y0 in range(0, h, 32):
        y1 = min(h, y0 + 32)
        sub = rgb[y0:y1]
        diff = sub[:, :, None, :] - mixes[None, None, :, :]
        cost = np.sqrt((diff * diff).sum(axis=-1)) + pens[None, None, :]
        best = cost.argmin(axis=-1)
        bayer = np.tile(BAYER_8X8, ((y1 - y0) // 8 + 2, w // 8 + 2))[:y1 - y0, :w]
        out[y0:y1] = np.where(bayer < ta[best], c2a[best], c1a[best])
    return out


def convert_image(img, pal, width, height, crop_x=0.35, crop_y=0.50,
                  zoom=1.0, sky_warm=0.5, field_warm=1.0,
                  pen_sky=0.06, pen_fld=0.08, blur=0.8, sat=1.25):
    arr = np.asarray(img.convert("RGB"), dtype=np.float64)
    if arr.shape[:2] == (720, 1280):
        arr = patch_flare(arr)
    patched = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

    sw, sh = patched.size
    target_ratio = width / height
    ch = int(round(sh / zoom))
    cw = int(round(ch * target_ratio))
    if cw > sw:
        cw = sw
        ch = int(round(cw / target_ratio))

    x0 = int(round((sw - cw) * crop_x))
    y0 = int(round((sh - ch) * crop_y))
    im = patched.crop((x0, y0, x0 + cw, y0 + ch)).resize((width, height), Image.Resampling.LANCZOS)
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    im = ImageEnhance.Color(im).enhance(sat)

    a = np.asarray(im, dtype=np.float64)
    if width == 640 and height == 462:
        sky_a = a.copy()
        sky_a[..., 0] = np.clip(sky_a[..., 0] * (1.0 + 0.12 * sky_warm), 0, 255)
        sky_a[..., 1] = np.clip(sky_a[..., 1] * (1.0 + 0.04 * sky_warm), 0, 255)
        sky_a[..., 2] = np.clip(sky_a[..., 2] * (1.0 - 0.05 * sky_warm), 0, 255)

        fld_a = a.copy()
        fld_a[..., 0] = np.clip(fld_a[..., 0] * (1.18 + 0.15 * field_warm) + 12.0, 0, 255)
        fld_a[..., 1] = np.clip(fld_a[..., 1] * (0.95 + 0.05 * field_warm) + 4.0, 0, 255)
        fld_a[..., 2] = np.clip(fld_a[..., 2] * 0.45, 0, 255)

        idx_sky = dither_pair(sky_a[:228], pal, SKY_ALLOWED, penalty=pen_sky, forbid_pairs=FORBID_SKY)
        idx_fld = dither_pair(fld_a[204:], pal, FIELD_ALLOWED, penalty=pen_fld)

        out = np.zeros((height, width), dtype=np.uint8)
        out[:204] = idx_sky[:204]
        out[228:] = idx_fld[24:]
        bayer = np.tile(BAYER_8X8, (24 // 8 + 1, width // 8 + 1))[:24, :width]
        t = np.linspace(0.0, 1.0, 24)[:, None]
        out[204:228] = np.where(bayer < t, idx_fld[:24], idx_sky[204:228])
        return out

    a[..., 0] = np.clip(a[..., 0] * (1.0 + 0.12 * field_warm) + 6.0, 0, 255)
    a[..., 1] = np.clip(a[..., 1] * (1.0 + 0.03 * field_warm), 0, 255)
    a[..., 2] = np.clip(a[..., 2] * 0.75, 0, 255)
    return dither_pair(a, pal, list(range(16)), penalty=pen_sky)


def encode_pcx_rle(row_bytes):
    out = bytearray()
    i = 0
    n = len(row_bytes)
    while i < n:
        val = row_bytes[i]
        run = 1
        while i + run < n and row_bytes[i + run] == val and run < 63:
            run += 1
        if run > 1 or val >= 0xC0:
            out.append(0xC0 | run)
            out.append(val)
        else:
            out.append(val)
        i += run
    return out


def write_planar_pcx(out_path, idx, pal):
    h, w = idx.shape
    bpl = (w + 7) // 8
    if bpl & 1:
        bpl += 1

    pal_bytes = bytearray(48)
    for i in range(16):
        pal_bytes[i * 3 + 0] = int(round(pal[i, 0]))
        pal_bytes[i * 3 + 1] = int(round(pal[i, 1]))
        pal_bytes[i * 3 + 2] = int(round(pal[i, 2]))

    header = struct.pack(
        "<BBBBHHHHHH48sBBHHHH54s",
        0x0A,
        5,
        1,
        1,
        0, 0,
        w - 1, h - 1,
        w, h,
        bytes(pal_bytes),
        0,
        4,
        bpl,
        1,
        w, h,
        b"\x00" * 54,
    )

    pad = bpl * 8 - w
    body = bytearray()
    for y in range(h):
        row = idx[y]
        for p in range(4):
            bits = ((row >> p) & 1).astype(np.uint8)
            if pad:
                bits = np.pad(bits, (0, pad))
            packed = np.packbits(bits).tobytes()
            body.extend(encode_pcx_rle(packed))

    with open(out_path, "wb") as f:
        f.write(header)
        f.write(body)
    return len(header) + len(body)


def main():
    parser = argparse.ArgumentParser(
        description="Convert an image to a 16-color planar PCX file."
    )
    parser.add_argument("input", help="Input image path")
    parser.add_argument("output", help="Output .PCX path")
    parser.add_argument("-W", "--width", type=int, default=640, help="Target width")
    parser.add_argument("-H", "--height", type=int, default=462, help="Target height")
    parser.add_argument("--crop-x", type=float, default=0.35, help="Horizontal crop align")
    parser.add_argument("--crop-y", type=float, default=0.50, help="Vertical crop align")
    parser.add_argument("--zoom", type=float, default=1.0, help="Crop zoom factor")
    parser.add_argument("--sky-warm", type=float, default=0.5, help="Sky warmth")
    parser.add_argument("--field-warm", type=float, default=1.0, help="Field warmth")
    parser.add_argument("--sat", type=float, default=1.25, help="Saturation factor")
    parser.add_argument("--blur", type=float, default=0.8, help="Pre-dither blur radius")
    parser.add_argument("--preview", default=None, help="Optional PNG preview output")
    args = parser.parse_args()

    pal = EGA_PALETTE
    img = Image.open(args.input)
    idx = convert_image(
        img, pal, args.width, args.height,
        crop_x=args.crop_x, crop_y=args.crop_y, zoom=args.zoom,
        sky_warm=args.sky_warm, field_warm=args.field_warm,
        blur=args.blur, sat=args.sat,
    )
    size = write_planar_pcx(args.output, idx, pal)
    print(f"Wrote {args.width}x{args.height} 16-color PCX ({size} bytes) -> {args.output}")

    if args.preview:
        Image.fromarray(pal[idx].astype(np.uint8)).save(args.preview)
        print(f"Wrote preview -> {args.preview}")


if __name__ == "__main__":
    main()
