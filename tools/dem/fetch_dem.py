"""Naive DEM fetch-and-stitch prototype (R8 research follow-up).
Pulls Terrarium elevation tiles for a lat/lon bbox, stitches, decodes to meters,
writes a 16-bit heightmap + an 8-bit preview (hillshade if numpy present).
Recipe-not-artifact rule: this script is committed; out/ is gitignored.

Usage: python fetch_dem.py [location]
  location defaults to "millstreet" if omitted (unchanged behavior).
  See LOCATIONS below for the full candidate list.
"""
import math
import os
import sys
import urllib.request

from PIL import Image, ImageDraw

URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
OUT = os.path.join(os.path.dirname(__file__), "out")

# Splice candidates: bbox (padded to a single-viewpoint patch), zoom, marker
# pins for the preview image, and the camera anchor export_to_game.py spawns
# above. Add new candidates here as they're scouted/verified.
LOCATIONS = {
    "millstreet": dict(
        lat_min=51.82, lat_max=52.50, lon_min=-9.55, lon_max=-8.42, zoom=12,
        camera=(52.0603, -9.0633),
        markers=[
            (51.8892, -8.5243, "start"),
            (52.0603, -9.0633, "Millstreet"),
            (52.4301, -9.4701, "end"),
        ],
        label="Millstreet (Cork-Kerry route)",
    ),
    "priests_leap": dict(
        # Cork/Kerry border mountain pass overlooking Bantry Bay; verified peak
        # 690m (~ Hungry Hill 685m), bay inlet visible in-frame.
        lat_min=51.640, lat_max=51.795, lon_min=-9.505, lon_max=-9.220, zoom=12,
        camera=(51.7186, -9.3606),
        markers=[
            (51.772483, -9.239598, "NE corner"),
            (51.660478, -9.483205, "SW corner"),
            (51.7186, -9.3606, "Priest's Leap"),
        ],
        label="Priest's Leap / Caha Mountains over Bantry Bay",
    ),
    "mizen_head": dict(
        # SW tip of Ireland; verified peak 456m, 82% sea in-frame.
        lat_min=51.351, lat_max=51.551, lon_min=-10.023, lon_max=-9.623, zoom=12,
        camera=(51.4508, -9.8229),
        markers=[(51.4508, -9.8229, "Mizen Head")],
        label="Mizen Head",
    ),
    "slea_head": dict(
        # Dingle Peninsula, west of Kerry; verified peak 771m, 69% sea in-frame.
        lat_min=52.006, lat_max=52.186, lon_min=-10.668, lon_max=-10.228, zoom=12,
        camera=(52.0964, -10.4478),
        markers=[(52.0964, -10.4478, "Slea Head")],
        label="Slea Head / Dingle Peninsula",
    ),
    "loop_head": dict(
        # Clare, mouth of the Shannon Estuary; verified peak 655m (likely
        # inland hills within the padded box, not the headland itself),
        # 78% sea in-frame.
        lat_min=52.469, lat_max=52.649, lon_min=-10.106, lon_max=-9.746, zoom=12,
        camera=(52.5589, -9.9257),
        markers=[(52.5589, -9.9257, "Loop Head")],
        label="Loop Head",
    ),
    "monument_valley": dict(
        # Desert biome candidate; verified elev 1430-2063m (632m relief), 0% sea.
        lat_min=36.909, lat_max=37.089, lon_min=-110.2375, lon_max=-109.9575, zoom=12,
        camera=(36.9990, -110.0975),
        markers=[(36.9990, -110.0975, "Monument Valley")],
        label="Monument Valley, UT/AZ",
    ),
    "mongolia_steppe": dict(
        # Grass steppe biome candidate. RE-CENTERED 2026-07-23: original Orkhon
        # Valley box had 1043m relief (river-valley hills, not flat steppe).
        # This box is open steppe east of the Khangai foothills — verified
        # elev 1302-1749m, only 326m relief (p99-p1), 0% sea. Genuine flat
        # steppe read.
        lat_min=46.90, lat_max=47.10, lon_min=106.20, lon_max=106.80, zoom=12,
        camera=(47.00, 106.50),
        markers=[(47.00, 106.50, "Open steppe")],
        label="Mongolian steppe (central, east of Khangai)",
    ),
    "costa_rica_jungle": dict(
        # Jungle candidate — not yet in the biome catalog (closest is
        # Conifer night-forest, which is temperate/cold, wrong fit). Verified
        # elev 73-2134m (2061m relief) — Arenal volcano massif in-frame,
        # mountainous rainforest rather than flat basin jungle.
        lat_min=10.36, lat_max=10.54, lon_min=-84.88, lon_max=-84.62, zoom=12,
        camera=(10.45, -84.75),
        markers=[(10.45, -84.75, "Arenal area")],
        label="Costa Rica (Arenal), mountainous rainforest",
    ),
    "ebro_delta": dict(
        # Delta marsh biome candidate. RE-CENTERED 2026-07-23: original box
        # caught Els Ports foothills (p99 575m). This box sits on the actual
        # delta plain — verified elev -8 to 100m, p99 37m, 85% sea/wetland.
        # Genuine clean flat-marsh reference now.
        lat_min=40.630, lat_max=40.740, lon_min=0.680, lon_max=0.870, zoom=12,
        camera=(40.685, 0.775),
        markers=[(40.685, 0.775, "Ebro Delta plain")],
        label="Ebro Delta, Spain",
    ),
    "vermont": dict(
        # Temperate rolling-hill country — not yet in the biome catalog as
        # its own entry (River Valley is the closest but that's tuned toward
        # the frontier/ford-town flavor, not pastoral). Verified elev
        # 86-1338m (1253m relief), 0% sea.
        lat_min=44.38, lat_max=44.56, lon_min=-72.88, lon_max=-72.62, zoom=12,
        camera=(44.47, -72.75),
        markers=[(44.47, -72.75, "Stowe/Mad River Valley")],
        label="Vermont (Stowe/Mad River Valley)",
    ),
    "cork_city": dict(
        # Metro candidate — small city (~200k metro), real hill relief around
        # the center. Verified elev 1-176m (175m relief), ~0% sea.
        lat_min=51.8535, lat_max=51.9435, lon_min=-8.5556, lon_max=-8.3956, zoom=12,
        camera=(51.8985, -8.4756),
        markers=[(51.8985, -8.4756, "Cork City")],
        label="Cork City, Ireland",
    ),
    "savannah": dict(
        # Metro candidate — historic planned grid, contrast to Cork's organic
        # layout. Verified flat (p99 elev 21m over a 7x8km box) — the 318m
        # single-pixel max is a Terrarium decode artifact, not real terrain;
        # ~11% sea/marsh in-frame is real (coastal Georgia lowland).
        lat_min=32.0509, lat_max=32.1109, lon_min=-81.1312, lon_max=-81.0512, zoom=12,
        camera=(32.0809, -81.0912),
        markers=[(32.0809, -81.0912, "Savannah")],
        label="Savannah, GA",
    ),
}
DEFAULT_LOCATION = "millstreet"

# Active bbox — mutated by set_location(); siblings (export_to_game.py,
# fetch_osm_roads.py, fetch_s2.py) import these as module attributes, so
# set_location() must run before they read them. Defaults preserve the
# original Millstreet-only behavior for anything that doesn't call it.
LAT_MIN, LAT_MAX = LOCATIONS[DEFAULT_LOCATION]["lat_min"], LOCATIONS[DEFAULT_LOCATION]["lat_max"]
LON_MIN, LON_MAX = LOCATIONS[DEFAULT_LOCATION]["lon_min"], LOCATIONS[DEFAULT_LOCATION]["lon_max"]
ZOOM = LOCATIONS[DEFAULT_LOCATION]["zoom"]
MARKERS = LOCATIONS[DEFAULT_LOCATION]["markers"]
LOCATION_NAME = DEFAULT_LOCATION


def set_location(name):
    global LAT_MIN, LAT_MAX, LON_MIN, LON_MAX, ZOOM, MARKERS, LOCATION_NAME
    loc = LOCATIONS[name]
    LAT_MIN, LAT_MAX = loc["lat_min"], loc["lat_max"]
    LON_MIN, LON_MAX = loc["lon_min"], loc["lon_max"]
    ZOOM = loc["zoom"]
    MARKERS = loc["markers"]
    LOCATION_NAME = name


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
    print(f"location: {LOCATION_NAME} ({LOCATIONS[LOCATION_NAME]['label']})")
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
    name = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_LOCATION
    if name not in LOCATIONS:
        print(f"unknown location {name!r}. options: {', '.join(LOCATIONS)}")
        sys.exit(1)
    set_location(name)
    main()
