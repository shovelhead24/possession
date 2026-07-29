"""Batch scout pass: elevation stats for many candidate bboxes in one run.

check_stats.py does one box per process; for a 20-candidate sweep that's 20 interpreter
startups and no shared tile cache. This walks a list, reuses fetch_dem's on-disk tile cache,
and prints a table you can paste into docs/terrain/splice-portfolio.md.

Recipe-not-artifact: this script is committed, out/ is gitignored.

Usage: python scout_batch.py [name ...]      (no args = all)
"""
import sys

import numpy as np
from PIL import Image

import fetch_dem as fd

# name -> (lat_min, lat_max, lon_min, lon_max, biome intent)
# Boxes are scout-sized (~0.2 deg lat), not the full 84km export box -- enough to judge
# character/relief before committing a location to fetch_dem.LOCATIONS.
CANDIDATES = {
    # --- Conifer night-forest: the gap. Zero candidates before this pass, and it is one of
    # the two biomes the first slice needs (biomes.md).
    "schwarzwald":      (47.78, 47.98, 7.85, 8.20, "Conifer night-forest"),
    "olympic_forest":   (47.75, 47.95, -124.10, -123.75, "Conifer night-forest"),
    "tatra_spruce":     (49.08, 49.28, 19.95, 20.30, "Conifer night-forest"),
    # --- River Valley / ford-town corridor (10-15% arc)
    "wye_valley":       (51.60, 51.80, -2.80, -2.50, "River Valley"),
    "dordogne":         (44.80, 45.00, 1.05, 1.40, "River Valley"),
    # --- Grass steppe
    "great_plains":     (41.90, 42.10, -101.65, -101.30, "Grass steppe"),
    # --- Delta marsh (18-25% arc, the sea inflow)
    "camargue":         (43.40, 43.60, 4.35, 4.70, "Delta marsh"),
    "danube_delta":     (45.05, 45.25, 29.15, 29.50, "Delta marsh"),
    # --- Highland / wall-foot crags (60-75% arc)
    "dolomites":        (46.52, 46.72, 12.15, 12.50, "Highland/crags"),
    "cairngorms":       (56.98, 57.18, -3.85, -3.50, "Highland/crags"),
    "norwegian_fjord":  (62.00, 62.20, 6.95, 7.30, "Highland/crags + sea"),
    # --- Desert (enclave rain-shadow flank, 40-55% arc)
    "atacama":          (-23.00, -22.80, -68.35, -68.00, "Desert (preservation)"),
    "namib_dunes":      (-24.85, -24.65, 15.15, 15.50, "Desert (dunes)"),
    # --- Jungle
    "borneo_highland":  (5.98, 6.18, 116.40, 116.75, "Jungle (volcanic highland)"),
    # --- Temperate pastoral
    "tuscany_hills":    (42.95, 43.15, 11.45, 11.80, "Temperate pastoral"),
    # --- Lost-world pocket (80% arc, containment dome) -- Roraima is literally the
    # "lost world" tepui; flat-topped mesa walls are a natural dome/pocket grounding.
    "tepui":            (5.04, 5.24, -60.90, -60.60, "Lost-world pocket"),
    # --- Eroded/ancient, for the hub-spire approach (90-100%: "most degraded AND most ancient")
    "badlands_sd":      (43.75, 43.95, -102.50, -102.20, "Eroded badlands"),
    # --- Volcanic/glacial, alien-adjacent
    "iceland_highland": (63.88, 64.08, -19.25, -18.90, "Volcanic/glacial"),
    # --- Scarred-erosion references for the ALLOY BARRENS (30% arc). The barrens are alien
    # (erodibility 0) so they can't be spliced directly, but channeled-scabland flood scars and
    # a salt flat's dead flatness are the closest real analogues for that read.
    "scablands":        (46.56, 46.76, -118.40, -118.05, "Alloy-barrens analogue"),
    "salar_uyuni":      (-20.25, -20.05, -67.60, -67.25, "Alloy-barrens analogue (flat)"),
}


def scout(name, lat_min, lat_max, lon_min, lon_max, intent, zoom=12):
    x0f, y1f = fd.tile_xy(lat_min, lon_min, zoom)
    x1f, y0f = fd.tile_xy(lat_max, lon_max, zoom)
    x0, x1 = int(x0f), int(x1f)
    y0, y1 = int(y0f), int(y1f)
    cols, rows = x1 - x0 + 1, y1 - y0 + 1

    import os
    cache = os.path.join(fd.OUT, "tiles")
    os.makedirs(cache, exist_ok=True)
    mosaic = Image.new("RGB", (cols * 256, rows * 256))
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            mosaic.paste(fd.fetch(zoom, tx, ty, cache), ((tx - x0) * 256, (ty - y0) * 256))

    arr = np.asarray(mosaic, dtype=np.float64)
    e = (arr[..., 0] * 256 + arr[..., 1] + arr[..., 2] / 256.0) - 32768.0
    sea = e < 0.5
    land = e[~sea]
    if land.size == 0:
        return dict(name=name, intent=intent, note="ALL SEA", sea=100.0)
    return dict(
        name=name, intent=intent,
        lo=float(np.percentile(land, 1)), hi=float(np.percentile(land, 99)),
        raw_min=float(e.min()), raw_max=float(e.max()),
        p50=float(np.percentile(land, 50)),
        relief=float(np.percentile(land, 99) - np.percentile(land, 1)),
        sea=100.0 * float(sea.mean()), tiles=f"{cols}x{rows}",
    )


def main():
    names = sys.argv[1:] or list(CANDIDATES)
    rows = []
    for n in names:
        if n not in CANDIDATES:
            print(f"  ?? unknown candidate {n!r}")
            continue
        lat0, lat1, lon0, lon1, intent = CANDIDATES[n]
        try:
            r = scout(n, lat0, lat1, lon0, lon1, intent)
        except Exception as exc:                     # noqa: BLE001 - scouting, keep going
            print(f"  !! {n}: {type(exc).__name__}: {exc}")
            continue
        rows.append(r)
        if r.get("note") == "ALL SEA":
            print(f"  {n:<18} ALL SEA")
        else:
            print(f"  {n:<18} p1 {r['lo']:>6.0f}  p50 {r['p50']:>6.0f}  p99 {r['hi']:>6.0f}  "
                  f"relief {r['relief']:>6.0f}m  sea {r['sea']:>5.1f}%  "
                  f"(raw {r['raw_min']:.0f}..{r['raw_max']:.0f})  [{r['intent']}]")
    print(f"\nscouted {len(rows)}")


if __name__ == "__main__":
    main()
