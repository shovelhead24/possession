"""Naive DEM fetch-and-stitch prototype (R8 research follow-up).
Pulls Terrarium elevation tiles for a lat/lon bbox, stitches, decodes to meters,
writes a 16-bit heightmap + an 8-bit preview (hillshade if numpy present).
Recipe-not-artifact rule: this script is committed; out/ is gitignored.

Usage: python fetch_dem.py  (defaults to the Cork->Millstreet->Kerry route bbox)
"""
import math
import os
import sys
import urllib.request

from PIL import Image, ImageDraw

URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
OUT = os.path.join(os.path.dirname(__file__), "out")

# Default: Cork -> Boggeraghs -> Millstreet -> north Kerry route, padded
LAT_MIN, LAT_MAX = 51.82, 52.50
LON_MIN, LON_MAX = -9.55, -8.42
ZOOM = 12

MARKERS = [  # (lat, lon, label)
    (51.8892, -8.5243, "start"),
    (52.0603, -9.0633, "Millstreet"),
    (52.4301, -9.4701, "end"),
]


def tile_xy(lat, lon, z):
    n = 2 ** z
    x = (lon + 180.0) / 360.0 * n
    y = (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n
    return x, y


def fetch(z, x, y, cache_dir):
    path = os.path.join(cache_dir, f"{z}_{x}_{y}.png")
    if not os.path.exists(path):
        urllib.request.urlretrieve(URL.format(z=z, x=x, y=y), path)
    return Image.open(path).convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    cache = os.path.join(OUT, "tiles")
    os.makedirs(cache, exist_ok=True)

    x0f, y1f = tile_xy(LAT_MIN, LON_MIN, ZOOM)  # note: y grows southward
    x1f, y0f = tile_xy(LAT_MAX, LON_MAX, ZOOM)
    x0, x1 = int(x0f), int(x1f)
    y0, y1 = int(y0f), int(y1f)
    cols, rows = x1 - x0 + 1, y1 - y0 + 1
    print(f"zoom {ZOOM}: tiles x {x0}..{x1} y {y0}..{y1} -> {cols}x{rows} = {cols*rows} tiles")

    mosaic = Image.new("RGB", (cols * 256, rows * 256))
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            mosaic.paste(fetch(ZOOM, tx, ty, cache), ((tx - x0) * 256, (ty - y0) * 256))
        sys.stdout.write(f"\r  row {ty - y0 + 1}/{rows}")
        sys.stdout.flush()
    print()

    w, h = mosaic.size
    src = mosaic.load()
    heights = Image.new("I", (w, h))
    dst = heights.load()
    lo, hi = 99999.0, -99999.0
    for py in range(h):
        for px in range(w):
            r, g, b = src[px, py]
            e = (r * 256 + g + b / 256.0) - 32768.0
            if e < -100:  # terrarium sea junk clamp
                e = 0.0
            lo, hi = min(lo, e), max(hi, e)
            dst[px, py] = int(max(e, 0.0) * 16)  # 1/16 m units in 16-bit range
    print(f"elevation range: {lo:.0f} m .. {hi:.0f} m over {w}x{h} px")

    heights.point(lambda v: v).convert("I;16").save(os.path.join(OUT, "heightmap_16bit.png"))

    # preview: hillshade via numpy if available, else affine-normalized grayscale
    scale = 255.0 / max(hi - lo, 1.0)
    try:
        import numpy as np
        arr = np.asarray(heights, dtype=np.float64) / 16.0
        gy, gx = np.gradient(arr)
        az, alt = math.radians(315), math.radians(45)
        slope = np.arctan(np.hypot(gx, gy) * 0.06)
        aspect = np.arctan2(-gx, gy)
        shade = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
        prev = Image.fromarray((np.clip(shade, 0, 1) * 255).astype("uint8"), "L")
        print("preview: hillshade (numpy)")
    except ImportError:
        prev = heights.point(lambda v: v * (scale / 16.0) - lo * scale).convert("L")
        print("preview: grayscale only (no numpy)")

    prev = prev.convert("RGB")
    draw = ImageDraw.Draw(prev)
    for lat, lon, label in MARKERS:
        mx, my = tile_xy(lat, lon, ZOOM)
        px, py = int((mx - x0) * 256), int((my - y0) * 256)
        draw.line([(px - 8, py), (px + 8, py)], fill=(255, 60, 40), width=2)
        draw.line([(px, py - 8), (px, py + 8)], fill=(255, 60, 40), width=2)
        draw.text((px + 10, py - 14), label, fill=(255, 60, 40))
    prev.save(os.path.join(OUT, "preview.png"))
    print(f"wrote {OUT}\\heightmap_16bit.png and preview.png")


if __name__ == "__main__":
    main()
