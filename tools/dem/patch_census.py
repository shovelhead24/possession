#!/usr/bin/env python3
"""Measure every patch against the intent it was scouted for, and against the biome numbers the
game is currently using for it.

Why this exists. Patches were scouted at ~22km with a specific character in mind, then expanded to
~90km for uniform tiling -- 16x the area -- and several stopped being the place we picked.
ebro_delta and savannah have sat in TODO as "drifted out of character" for weeks, not because the
fix is hard but because CHECKING means looking at 35 images and nobody does that.

Separately, and worth more: every biome parameter in ring_vibes.gd's PATCHES table -- tint, trees,
tree_hi, weather -- is a number that was guessed from the place name. The imagery can measure them.

This script does the cheap half: statistics, in bulk, from the heightfield, the drape and the road
centrelines. It does NOT judge. It writes out/patch_census.json plus a table, and lists the preview
images to be read alongside it -- because statistics cannot tell a delta from a floodplain (same
histogram, different place) and an image can.

It proposes nothing and changes nothing. Re-centring a patch costs a 33-minute refetch and destroys
the old one; that decision is not this script's to make.

usage:  python patch_census.py [names...]
"""
import json
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))
OUT = os.path.join(HERE, "out")
SEA = 0.5
RING_W_KM = 50.0


def heights(name, meta):
    w, h, hs = int(meta["w"]), int(meta["h"]), float(meta.get("h_scale", 16.0))
    a = np.fromfile(os.path.join(DEST, name + ".r16"), dtype="<u2", count=w * h)
    if a.size < w * h:
        return None
    return a.reshape(h, w).astype(np.float32) / hs


def height_stats(a, mpp, hs):
    # only the strip that lands on the ring: the rest is fetched but never rendered, and including
    # it skews relief and sea fraction for any patch whose interest is off the midline
    rows = a.shape[0]
    keep = int(min(rows, (RING_W_KM * 1000.0 / mpp)))
    lo = (rows - keep) // 2
    s = a[lo:lo + keep]
    land = s[s > SEA]
    p1, p99 = (np.percentile(land, [1, 99]) if land.size else (0.0, 0.0))
    gy, gx = np.gradient(s, mpp)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    ceiling = 65535.0 / hs
    return {
        "relief_m": round(float(p99 - p1), 1),
        "max_m": round(float(s.max()), 1),
        "sea_pct": round(100.0 * float((s <= SEA).mean()), 1),
        "slope_med": round(float(np.median(slope)), 1),
        "slope_p95": round(float(np.percentile(slope, 95)), 1),
        # ground you could actually drive on, which now matters
        "drivable_pct": round(100.0 * float(((slope < 12.0) & (s > SEA)).mean()), 1),
        "at_ceiling_pct": round(100.0 * float((s >= ceiling * 0.999).mean()), 4),
    }


def drape_stats(name):
    """Mean colour and cover fractions off the S2 preview -- the evidence for tint / trees."""
    p = os.path.join(OUT, name + "_s2_preview.jpg")
    if not os.path.exists(p):
        return {}
    from PIL import Image
    im = np.asarray(Image.open(p).convert("RGB").resize((256, 256))).astype(np.float32) / 255.0
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    nodata = lum < 0.02
    v = ~nodata
    if v.sum() < 100:
        return {"drape": "empty"}
    # excess green: vegetation index that survives JPEG and needs no NIR band
    exg = (2.0 * g - r - b)
    veg = (exg > 0.06) & v
    water = (b > r + 0.02) & (lum < 0.35) & v
    snow = (lum > 0.72) & (np.abs(r - b) < 0.06) & v
    bare = v & ~veg & ~water & ~snow
    return {
        "mean_rgb": [round(float(r[v].mean()), 3), round(float(g[v].mean()), 3),
                     round(float(b[v].mean()), 3)],
        "veg_pct": round(100.0 * float(veg.sum()) / float(v.sum()), 1),
        "bare_pct": round(100.0 * float(bare.sum()) / float(v.sum()), 1),
        "water_pct": round(100.0 * float(water.sum()) / float(v.sum()), 1),
        "snow_pct": round(100.0 * float(snow.sum()) / float(v.sum()), 1),
        "brightness": round(float(lum[v].mean()), 3),
        "nodata_pct": round(100.0 * float(nodata.mean()), 1),
    }


def road_stats(name, meta):
    p = os.path.join(DEST, name + "_roadlines.dat")
    if not os.path.exists(p):
        return {"road_km": None}
    b = open(p, "rb").read()
    if len(b) < 8 or b[:4] != b"RDL1":
        return {"road_km": None}
    n = struct.unpack("<I", b[4:8])[0]
    o, total, ways = 8, 0.0, 0
    for _ in range(n):
        if o + 4 > len(b):
            break
        _wdt, cnt = struct.unpack("<HH", b[o:o + 4])
        o += 4
        pts = []
        for _k in range(cnt):
            if o + 8 > len(b):
                break
            pts.append(struct.unpack("<2f", b[o:o + 8]))
            o += 8
        for i in range(len(pts) - 1):
            total += ((pts[i + 1][0] - pts[i][0]) ** 2 + (pts[i + 1][1] - pts[i][1]) ** 2) ** 0.5
        ways += 1
    area_km2 = (meta["w"] * meta["m_per_px"] / 1000.0) * (RING_W_KM)
    return {"road_km": round(total / 1000.0, 1), "road_ways": ways,
            "road_km_per_km2": round(total / 1000.0 / area_km2, 3)}


def marker_offset(name, meta, fd):
    """How far the feature we CHOSE now sits from the patch centre. A patch whose named landmark is
    30km off-centre is centred on something else -- which is precisely what 'drifted' means."""
    loc = fd.LOCATIONS.get(name, {})
    ms = loc.get("markers") or []
    if not ms:
        return {}
    fd.set_location(name)
    fd.match_export(name, DEST)
    clat = (fd.LAT_MIN + fd.LAT_MAX) * 0.5
    clon = (fd.LON_MIN + fd.LON_MAX) * 0.5
    out = []
    for m in ms:
        dy = (m[0] - clat) * 111.32
        dx = (m[1] - clon) * 111.32 * np.cos(np.radians(clat))
        out.append({"name": m[2], "km_from_centre": round(float(np.hypot(dx, dy)), 1)})
    return {"markers": out,
            "worst_marker_km": round(max(o["km_from_centre"] for o in out), 1)}


def main():
    sys.path.insert(0, HERE)
    import fetch_dem as fd
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not names:
        names = sorted(n for n in fd.LOCATIONS
                       if os.path.exists(os.path.join(DEST, n + ".json")))

    rows = {}
    for n in names:
        meta = json.load(open(os.path.join(DEST, n + ".json")))
        a = heights(n, meta)
        if a is None:
            print("skip %s (short r16)" % n)
            continue
        row = {"label": fd.LOCATIONS.get(n, {}).get("label", ""),
               "span_km": round(meta["w"] * meta["m_per_px"] / 1000.0, 1),
               "m_per_px": meta["m_per_px"]}
        row.update(height_stats(a, float(meta["m_per_px"]), float(meta.get("h_scale", 16.0))))
        row.update(drape_stats(n))
        row.update(road_stats(n, meta))
        row.update(marker_offset(n, meta, fd))
        side = os.path.join(DEST, n + "_sat.json")
        if os.path.exists(side):
            row["drape"] = json.load(open(side))
        rows[n] = row
        print("%-18s relief %6.0fm  sea %4.1f%%  veg %4s%%  bare %4s%%  drive %4.1f%%  "
              "roads %6s km  marker %5s km"
              % (n, row["relief_m"], row["sea_pct"], row.get("veg_pct", "-"),
                 row.get("bare_pct", "-"), row["drivable_pct"],
                 row.get("road_km", "-"), row.get("worst_marker_km", "-")))

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "patch_census.json"), "w") as f:
        json.dump(rows, f, indent=1)
    print("\nwrote out/patch_census.json for %d patches" % len(rows))
    print("images to read alongside it:")
    for n in rows:
        for suf in ("_s2_preview.jpg", "_roads_preview.png"):
            p = os.path.join(OUT, n + suf)
            if os.path.exists(p):
                print("  " + p)


if __name__ == "__main__":
    main()
