"""Fetch OSM building positions for a DEM patch and write them as instance records the mock can
place directly. Companion to fetch_osm_roads.py.

Why `out center` and not `out geom`: a full-geometry building query over an 84 km patch returns
every footprint vertex in a populated area -- tens of MB, minutes of Overpass CPU, and a very good
way to get an IP banned (the risk already logged against the roads fetch for the other 32 patches).
`out center` returns one point per building plus tags, roughly a tenth of the payload. Real
POSITION is the thing that has to be true here; footprint size and orientation are synthesised from
tags, which is fine for rudimentary houses and can be upgraded to true footprints per-patch later
if a hero area earns it.

Output: game/mocks/dem/<name>_bldg.dat
  "BLD1" | u32 count | count x 6 x float32  (arc_local, lat_local, width, depth, yaw, height)
  arc_local/lat_local are metres from the PATCH CENTRE, matching _patch_rects in ring_vibes.gd:
  arc  = (px/w - 0.5) * w * m_per_px      lat = (0.5 - py/h) * h * m_per_px

License: ODbL -- attribution "(c) OpenStreetMap contributors".

Usage:
  python fetch_osm_buildings.py [location] [--limit N] [--force]
"""
import math
import os
import random
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import fetch_dem as fd

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))
CACHE = os.path.join(HERE, "out", "osm_cache")

ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
UA = "possession-game-dem-prototype/0.1 (solo dev tooling; contact via repo)"

# Footprint guesses by building tag: (width, depth, storeys). Deliberately coarse -- these are
# stand-ins until a patch earns real footprints.
KINDS = {
    "house":       (9.0, 11.0, 1.6),
    "detached":    (10.0, 12.0, 1.8),
    "residential": (11.0, 13.0, 2.2),
    "apartments":  (18.0, 22.0, 4.0),
    "terrace":     (6.5, 14.0, 2.0),
    "bungalow":    (11.0, 13.0, 1.0),
    "farm":        (12.0, 16.0, 1.6),
    "farm_auxiliary": (9.0, 18.0, 1.2),
    "barn":        (12.0, 22.0, 1.4),
    "shed":        (4.0, 5.0, 1.0),
    "garage":      (3.2, 6.0, 1.0),
    "hut":         (4.0, 5.0, 1.0),
    "church":      (14.0, 30.0, 2.5),
    "school":      (24.0, 44.0, 2.0),
    "industrial":  (28.0, 48.0, 1.6),
    "warehouse":   (32.0, 55.0, 1.5),
    "commercial":  (20.0, 28.0, 2.0),
    "retail":      (22.0, 30.0, 1.5),
    "yes":         (10.0, 12.0, 1.7),
}
STOREY_M = 3.1


# The ring is 50km wide but a patch box is ~84-97km tall, so the top and bottom of every bbox lands
# outside the world and is thrown away at load. Asking for it anyway wastes the query cap on
# buildings that cannot exist: Cape Peninsula kept 1,383 of 59,999 because Cape Town sits in the
# discarded band. Clip the request to the strip that survives.
RING_WIDTH_KM = 50.0


def ring_strip():
    """(lat_min, lat_max) narrowed to the part of the box that lands on the ring."""
    span_km = (fd.LAT_MAX - fd.LAT_MIN) * 111.32
    if span_km <= RING_WIDTH_KM:
        return fd.LAT_MIN, fd.LAT_MAX
    mid = (fd.LAT_MIN + fd.LAT_MAX) * 0.5
    half = (fd.LAT_MAX - fd.LAT_MIN) * 0.5 * (RING_WIDTH_KM * 0.94 / span_km)
    return mid - half, mid + half


def build_query(limit):
    # nwr rather than way: a fair number of buildings are multipolygon relations, and node-only
    # buildings exist in sparsely mapped areas. center gives one point for each regardless.
    lo, hi = ring_strip()
    return (
        "[out:json][timeout:180];"
        'nwr["building"](%f,%f,%f,%f);'
        "out center %d;" % (lo, fd.LON_MIN, hi, fd.LON_MAX, limit)
    )


def overpass(query, tries=4):
    """One query, backing off politely. Overpass is a donated public service and this tool is a
    guest on it -- 429/504 means slow down, not retry harder."""
    body = ("data=" + urllib.parse.quote(query)).encode()
    delay = 12.0
    for attempt in range(tries):
        url = ENDPOINTS[attempt % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(
                url, body, {"User-Agent": UA,
                            "Content-Type": "application/x-www-form-urlencoded"})
            with urllib.request.urlopen(req, timeout=300) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code not in (429, 502, 503, 504):
                raise
            print("  %s -> HTTP %d, waiting %.0fs" % (url.split("/")[2], e.code, delay))
        except Exception as e:                                  # timeouts, resets
            print("  %s -> %s, waiting %.0fs" % (url.split("/")[2], type(e).__name__, delay))
        time.sleep(delay)
        delay *= 2.0
    raise SystemExit("Overpass would not answer after %d tries -- try again later, do not hammer it"
                     % tries)


def centre_of(el):
    if "center" in el:
        return el["center"]["lat"], el["center"]["lon"]
    if "lat" in el:
        return el["lat"], el["lon"]
    return None


def footprint(tags, rng):
    kind = tags.get("building", "yes")
    w, d, storeys = KINDS.get(kind, KINDS["yes"])
    # explicit tags win over the guess
    if "building:levels" in tags:
        try:
            storeys = max(1.0, float(str(tags["building:levels"]).split(";")[0]))
        except ValueError:
            pass
    height = storeys * STOREY_M
    if "height" in tags:
        try:
            height = max(2.0, float(str(tags["height"]).split()[0]))
        except ValueError:
            pass
    j = lambda v: v * rng.uniform(0.78, 1.28)
    return j(w), j(d), height * rng.uniform(0.9, 1.15)


def main(name, limit, force):
    fd.set_location(name)
    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(DEST, exist_ok=True)
    raw_path = os.path.join(CACHE, "%s_bldg.json" % name)

    if os.path.exists(raw_path) and not force:
        print("using cached %s (--force to refetch)" % os.path.relpath(raw_path, HERE))
        raw = open(raw_path, "rb").read()
    else:
        print("querying Overpass for buildings in %s (%.3f,%.3f)-(%.3f,%.3f)..."
              % (name, fd.LAT_MIN, fd.LON_MIN, fd.LAT_MAX, fd.LON_MAX))
        raw = overpass(build_query(limit))
        open(raw_path, "wb").write(raw)

    import json
    elements = json.loads(raw)["elements"]
    print("%d building elements" % len(elements))

    # patch geometry, straight out of the DEM meta so this cannot drift from the game's mapping
    meta_path = os.path.join(DEST, "%s.json" % name)
    if not os.path.exists(meta_path):
        raise SystemExit("no %s.json -- run the DEM export for this location first" % name)
    meta = json.load(open(meta_path))
    W, H, MPP = int(meta["w"]), int(meta["h"]), float(meta["m_per_px"])

    rng = random.Random(hash(name) & 0xFFFF)
    recs = []
    for el in elements:
        c = centre_of(el)
        if c is None:
            continue
        lat, lon = c
        if not (fd.LAT_MIN <= lat <= fd.LAT_MAX and fd.LON_MIN <= lon <= fd.LON_MAX):
            continue
        px = (lon - fd.LON_MIN) / (fd.LON_MAX - fd.LON_MIN) * W
        py = (fd.LAT_MAX - lat) / (fd.LAT_MAX - fd.LAT_MIN) * H
        arc = (px / W - 0.5) * W * MPP
        lt = (0.5 - py / H) * H * MPP
        w, d, h = footprint(el.get("tags", {}), rng)
        recs.append((arc, lt, w, d, rng.uniform(0.0, math.tau), h))

    out = os.path.join(DEST, "%s_bldg.dat" % name)
    with open(out, "wb") as f:
        f.write(b"BLD1")
        f.write(struct.pack("<I", len(recs)))
        for r in recs:
            f.write(struct.pack("<6f", *r))
    print("wrote %s: %d buildings, %d KB"
          % (os.path.basename(out), len(recs), os.path.getsize(out) // 1024))
    if len(recs) >= limit:
        print("  NOTE: hit the %d cap -- this patch has more buildings than that" % limit)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    loc = args[0] if args else fd.DEFAULT_LOCATION
    lim = 60000
    if "--limit" in sys.argv:
        lim = int(sys.argv[sys.argv.index("--limit") + 1])
    main(loc, lim, "--force" in sys.argv)
