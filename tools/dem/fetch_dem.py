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
    "guri_dam": dict(
        # Engineered water infrastructure candidate — Embalse de Guri /
        # Simon Bolivar Dam, Guiana Highlands, Venezuela. First candidate
        # that's a real dam+reservoir at scale, not natural terrain — direct
        # grounding for lore.md's reactivatable ancient systems / civilization.md's
        # still-open surviving-enclave-economy question.
        # Elevation stats: 207m median, 313m relief (p99-p1) -- plausible for
        # highland terrain around a ~270m ASL reservoir. CAVEATS (2026-07-23,
        # not yet resolved): -1048m minimum in the raw scan is almost certainly
        # a Terrarium decode artifact (same class as the Savannah glitch), not
        # real terrain. And elevation-based "sea fraction" can't detect a lake
        # sitting well above sea level -- whether the reservoir is actually
        # in-frame needs a Sentinel-2 visual check, not asserted here.
        lat_min=7.62, lat_max=8.02, lon_min=-63.30, lon_max=-62.80, zoom=12,
        camera=(7.8211, -63.0301),
        markers=[(7.8211, -63.0301, "Guri Dam")],
        label="Guri Dam / Embalse de Guri, Venezuela",
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

    # ---------------------------------------------------------------------------------------
    # Batch 4 (2026-07-29): portfolio expansion toward tiling the ring. 36 patches of the
    # Millstreet size (84km) circle the 3000km ring; ~10 fetchable biomes x ~3 variants avoids
    # visible repetition. All boxes below verified via scout_batch.py -- stats in
    # docs/terrain/splice-portfolio.md. NOTE: these boxes are scout-sized (~0.2 deg / ~22km),
    # NOT Millstreet's 84km export box; widening them for a real ring patch needs re-verification
    # (character can drift out of the biome at 4x the footprint).
    # ---------------------------------------------------------------------------------------

    # --- Conifer night-forest: the gap this batch was built to close. Zero candidates before
    # now, despite being one of the two biomes the first slice needs (biomes.md).
    "schwarzwald": dict(
        # Black Forest around Feldberg. Verified relief 1001m, p50 961m, 0% sea -- crucially the
        # whole box sits BELOW the ~1400m local treeline, so it is genuinely forested highland
        # rather than bare rock. The archetypal dark-conifer landscape.
        lat_min=47.78, lat_max=47.98, lon_min=7.85, lon_max=8.20, zoom=12,
        camera=(47.88, 8.025),
        markers=[(47.8736, 8.0044, "Feldberg")],
        label="Schwarzwald / Black Forest, Germany",
    ),
    "olympic_forest": dict(
        # Hoh valley, Olympic Peninsula. Verified relief 1755m, 0% sea. Temperate rainforest
        # under big mountain relief -- wetter and more dramatic than Schwarzwald, same biome slot.
        lat_min=47.75, lat_max=47.95, lon_min=-124.10, lon_max=-123.75, zoom=12,
        camera=(47.85, -123.925),
        markers=[(47.8606, -123.9348, "Hoh Rainforest")],
        label="Olympic Peninsula (Hoh), WA",
    ),

    # --- River Valley / ford-town corridor (geography.md ~10-15% arc)
    "wye_valley": dict(
        # Wye at Tintern. Verified relief 252m, 8.8% water (the Wye is tidal here -- real river
        # crossings, which is the ford-town read).
        lat_min=51.60, lat_max=51.80, lon_min=-2.80, lon_max=-2.50, zoom=12,
        camera=(51.70, -2.65),
        markers=[(51.6975, -2.6772, "Tintern")],
        label="Wye Valley, Wales/England border",
    ),
    "dordogne": dict(
        # Sarlat/Dordogne. Verified relief 252m, 0% sea -- same gentleness as the Wye without the
        # tidal water; the drier, more settled variant of the same biome.
        lat_min=44.80, lat_max=45.00, lon_min=1.05, lon_max=1.40, zoom=12,
        camera=(44.90, 1.225),
        markers=[(44.8909, 1.2166, "Sarlat")],
        label="Dordogne valley, France",
    ),

    # --- Grass steppe
    "great_plains": dict(
        # Nebraska Sandhills. Verified relief 147m over the box -- genuinely flat, huge sightlines
        # (biomes.md's "where the softmax runs coldest"). Flatter read than mongolia_steppe's 326m.
        lat_min=41.90, lat_max=42.10, lon_min=-101.65, lon_max=-101.30, zoom=12,
        camera=(42.00, -101.475),
        markers=[(42.00, -101.475, "Sandhills")],
        label="Nebraska Sandhills, USA",
    ),

    # --- Delta marsh (geography.md ~18-25% arc, the sea inflow)
    "camargue": dict(
        # Rhone delta. Verified p99 16m, relief 15m, 63% water -- the flattest candidate in the
        # whole portfolio bar the salar. Reed geometry is the point (routes-as-knowledge).
        lat_min=43.40, lat_max=43.60, lon_min=4.35, lon_max=4.70, zoom=12,
        camera=(43.50, 4.525),
        markers=[(43.50, 4.525, "Camargue")],
        label="Camargue / Rhone delta, France",
    ),
    "danube_delta": dict(
        # Danube delta. Verified p99 28m, 58% water. Larger-channel character than the Camargue.
        lat_min=45.05, lat_max=45.25, lon_min=29.15, lon_max=29.50, zoom=12,
        camera=(45.15, 29.325),
        markers=[(45.15, 29.325, "Danube Delta")],
        label="Danube Delta, Romania",
    ),

    # --- Highland / wall-foot crags (geography.md ~60-75% arc)
    "dolomites": dict(
        # Tre Cime. Verified relief 1848m, max 3139m -- the most vertical candidate found.
        # Direct grounding for the glider/hookshot playground and scree-and-snow at altitude.
        lat_min=46.52, lat_max=46.72, lon_min=12.15, lon_max=12.50, zoom=12,
        camera=(46.62, 12.325),
        markers=[(46.6183, 12.3053, "Tre Cime")],
        label="Dolomites (Tre Cime), Italy",
    ),
    "cairngorms": dict(
        # Verified relief 948m -- plateau-and-corrie rather than spire; the gentler highland read.
        lat_min=56.98, lat_max=57.18, lon_min=-3.85, lon_max=-3.50, zoom=12,
        camera=(57.08, -3.675),
        markers=[(57.1117, -3.6444, "Cairn Gorm")],
        label="Cairngorms, Scotland",
    ),
    "tatra_spruce": dict(
        # Scouted as a conifer candidate; RECLASSIFIED to highland on the numbers -- p50 1057m
        # against a ~1500m treeline and a 2606m max means most of the box is above the trees.
        # Kept as a crags candidate rather than mislabelled as forest.
        lat_min=49.08, lat_max=49.28, lon_min=19.95, lon_max=20.30, zoom=12,
        camera=(49.18, 20.125),
        markers=[(49.1639, 20.1338, "Gerlachovsky")],
        label="High Tatras, Slovakia/Poland",
    ),
    "norwegian_fjord": dict(
        # Geirangerfjord. Verified relief 1604m with 5.8% water -- mountains dropping straight
        # into deep water. The strongest "wall meets sea" candidate found (beats slea_head).
        lat_min=62.00, lat_max=62.20, lon_min=6.95, lon_max=7.30, zoom=12,
        camera=(62.10, 7.125),
        markers=[(62.10, 7.0067, "Geiranger")],
        label="Geirangerfjord, Norway",
    ),

    # --- Desert (enclave rain-shadow flank, geography.md ~40-55% arc)
    "atacama": dict(
        # San Pedro / Valle de la Luna. Verified relief 1797m, 0% sea -- but note the floor sits
        # at 2335m and peaks at 4629m: this is ANDEAN ALTIPLANO desert, not low desert. Still the
        # literal driest place on Earth (the preservation paradox), just read it as high desert.
        lat_min=-23.00, lat_max=-22.80, lon_min=-68.35, lon_max=-68.00, zoom=12,
        camera=(-22.90, -68.175),
        markers=[(-22.91, -68.20, "San Pedro de Atacama")],
        label="Atacama (San Pedro), Chile",
    ),
    "namib_dunes": dict(
        # Sossusvlei. Verified relief 395m -- dune-field character, the low-desert counterpart to
        # Atacama's altiplano.
        lat_min=-24.85, lat_max=-24.65, lon_min=15.15, lon_max=15.50, zoom=12,
        camera=(-24.75, 15.325),
        markers=[(-24.7333, 15.3333, "Sossusvlei")],
        label="Namib dunes (Sossusvlei), Namibia",
    ),

    # --- Jungle
    "borneo_highland": dict(
        # Kinabalu massif. Verified relief 3302m (max 4051m) -- even more vertical than the Costa
        # Rica splice; rainforest running from 100m to alpine in one box.
        lat_min=5.98, lat_max=6.18, lon_min=116.40, lon_max=116.75, zoom=12,
        camera=(6.08, 116.575),
        markers=[(6.0753, 116.5583, "Kinabalu")],
        label="Mount Kinabalu, Borneo",
    ),

    # --- Temperate pastoral
    "tuscany_hills": dict(
        # Val d'Orcia. Verified relief 594m -- the cultivated/settled read, drier and more
        # sculpted than Vermont's wooded version of the same slot.
        lat_min=42.95, lat_max=43.15, lon_min=11.45, lon_max=11.80, zoom=12,
        camera=(43.05, 11.625),
        markers=[(43.05, 11.625, "Val d'Orcia")],
        label="Val d'Orcia, Tuscany",
    ),

    # --- Lost-world pocket (geography.md ~80% arc, the containment dome / off-mainline pocket)
    "tepui": dict(
        # Mount Roraima -- the literal "Lost World" tepui. Verified relief 1514m; the flat-topped
        # mesa with sheer walls is a natural real-world grounding for a sealed pocket ecology.
        lat_min=5.04, lat_max=5.24, lon_min=-60.90, lon_max=-60.60, zoom=12,
        camera=(5.14, -60.75),
        markers=[(5.1431, -60.7625, "Roraima")],
        label="Mount Roraima tepui, Venezuela",
    ),

    # --- Eroded/ancient, for the hub-spire approach (geography.md 90-100%: "the last stretch of
    # arc is the most degraded AND the most ancient")
    "badlands_sd": dict(
        # Verified relief 183m -- modest height but intensely dissected; erosion character, not
        # mountain character, which is exactly the "degraded and ancient" read.
        lat_min=43.75, lat_max=43.95, lon_min=-102.50, lon_max=-102.20, zoom=12,
        camera=(43.85, -102.35),
        markers=[(43.855, -102.34, "Badlands")],
        label="Badlands, South Dakota",
    ),
    "iceland_highland": dict(
        # Landmannalaugar. Verified relief 549m -- volcanic/glacial, the least Earth-familiar of
        # the natural candidates; rhyolite colour and no vegetation.
        lat_min=63.88, lat_max=64.08, lon_min=-19.25, lon_max=-18.90, zoom=12,
        camera=(63.98, -19.075),
        markers=[(63.9836, -19.0608, "Landmannalaugar")],
        label="Landmannalaugar, Iceland",
    ),

    # --- Alloy-barrens ANALOGUES (geography.md ~30% arc). The barrens are the one deliberately
    # alien biome (erodibility 0) so they can't be spliced from Earth directly -- these are
    # reference reads for the shape language, not drop-in patches.
    "scablands": dict(
        # Channeled Scablands / Palouse Falls. Verified relief 354m. Catastrophic-flood scour
        # channels cut into basalt -- erosion that looks engineered, which is the barrens' read.
        lat_min=46.56, lat_max=46.76, lon_min=-118.40, lon_max=-118.05, zoom=12,
        camera=(46.66, -118.225),
        markers=[(46.6639, -118.2247, "Palouse Falls")],
        label="Channeled Scablands, WA",
    ),
    "salar_uyuni": dict(
        # Verified relief 10m across the whole box -- the flattest terrain in the portfolio by an
        # order of magnitude. Dead-flat, featureless, wrong-looking: the closest Earth gets to a
        # builder-alloy plain.
        lat_min=-20.25, lat_max=-20.05, lon_min=-67.60, lon_max=-67.25, zoom=12,
        camera=(-20.15, -67.425),
        markers=[(-20.15, -67.425, "Salar de Uyuni")],
        label="Salar de Uyuni, Bolivia",
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
