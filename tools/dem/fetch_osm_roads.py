"""Fetch OSM roads for the DEM bbox via Overpass, rasterize to a road mask
aligned with the sat/detail UVs (8192px ~ 9.3 m/px so regional roads hold width).
Export as PNG-in-dat for the mock. License: ODbL — attribution '(c) OpenStreetMap contributors'.

Usage: python fetch_osm_roads.py [location]
  location defaults to "millstreet" if omitted. Must match fetch_dem.py's LOCATIONS.
"""
import io
import struct
import json
import os
import sys
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw

import fetch_dem as fd

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))
SIZE = 8192
# PIL draws ALIASED lines, so every road that is not axis-aligned came out as a literal staircase
# at 11 m/px -- visible in game as jagged roads and a jagged hedgerow following them. Rasterise at
# SS times the output and box-filter down, which is proper antialiasing and costs one resize.
SS = 3
CACHE = os.path.join(HERE, "out", "osm_cache")

WIDTHS = {"motorway": 3, "trunk": 3, "primary": 2, "secondary": 2, "tertiary": 1, "unclassified": 1}


def build_query():
    # built at call time (post set_location), not import time — the previous
    # module-level version silently always queried whatever location loaded first
    return """
[out:json][timeout:180];
way["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified)$"]
  (%f,%f,%f,%f);
out geom;
""" % (fd.LAT_MIN, fd.LON_MIN, fd.LAT_MAX, fd.LON_MAX)


def to_px(lat, lon):
    x = (lon - fd.LON_MIN) / (fd.LON_MAX - fd.LON_MIN) * SIZE
    y = (fd.LAT_MAX - lat) / (fd.LAT_MAX - fd.LAT_MIN) * SIZE
    return x, y


def main(name):
    fd.set_location(name)
    span = fd.match_export(name)   # authored bbox != exported patch; see fetch_dem.match_export
    print("bbox matched to the exported heightfield: %s"
          % ("%.1f km" % span if span else "NO EXPORT — using authored bbox"))
    req = urllib.request.Request(
        "https://overpass-api.de/api/interpreter",
        ("data=" + urllib.parse.quote(build_query())).encode(),
        {"User-Agent": "possession-game-dem-prototype/0.1 (solo dev tooling)",
         "Content-Type": "application/x-www-form-urlencoded"})
    os.makedirs(CACHE, exist_ok=True)
    raw_path = os.path.join(CACHE, "%s_roads.json" % name)
    if os.path.exists(raw_path) and "--force" not in sys.argv:
        print("using cached %s (--force to refetch)" % os.path.relpath(raw_path, HERE))
        raw = open(raw_path, "rb").read()
    else:
        print("querying Overpass...")
        with urllib.request.urlopen(req, timeout=300) as r:
            raw = r.read()
        open(raw_path, "wb").write(raw)
    ways = json.loads(raw)["elements"]
    print(f"{len(ways)} road ways")

    big = SIZE * SS
    img = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(img)
    for way in ways:
        wdt = WIDTHS.get(way.get("tags", {}).get("highway", ""), 1) * SS
        pts = [(x * SS, y * SS) for x, y in
               (to_px(g["lat"], g["lon"]) for g in way.get("geometry", []))]
        if len(pts) > 1:
            draw.line(pts, fill=255, width=wdt, joint="curve")
            # round caps: joint="curve" only rounds interior joints, so without this every way
            # ends in a square stub that reads as a notch where two ways meet at an angle
            r = wdt // 2
            if r > 0:
                for x, y in pts:
                    draw.ellipse([x - r, y - r, x + r, y + r], fill=255)
    img = img.resize((SIZE, SIZE), Image.BOX)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    os.makedirs(DEST, exist_ok=True)
    with open(os.path.join(DEST, f"{name}_roads.dat"), "wb") as f:
        f.write(buf.getvalue())
    img.resize((2048, 2048)).save(os.path.join(HERE, "out", f"{name}_roads_preview.png"))

    # POLYLINES as well as the raster. The mask is right for drape and for "is this point on a road",
    # but roadside hedging is a continuous ribbon following the centreline, and reconstructing a line
    # by scattering objects over a blurred bitmap gives exactly what it sounds like: a dotted line of
    # separate bushes. Written in the same patch-local metres the building records use.
    meta_path = os.path.join(DEST, f"{name}.json")
    if os.path.exists(meta_path):
        meta = json.load(open(meta_path))
        W, H, MPP = int(meta["w"]), int(meta["h"]), float(meta["m_per_px"])
        lines = []
        for way in ways:
            g = way.get("geometry", [])
            if len(g) < 2:
                continue
            pts = []
            for node in g:
                x, y = to_px(node["lat"], node["lon"])       # in SIZE-space
                pts.append(((x / SIZE - 0.5) * W * MPP, (0.5 - y / SIZE) * H * MPP))
            lines.append((WIDTHS.get(way.get("tags", {}).get("highway", ""), 1), pts))
        out = os.path.join(DEST, f"{name}_roadlines.dat")
        with open(out, "wb") as f:
            f.write(b"RDL1")
            f.write(struct.pack("<I", len(lines)))
            for wdt, pts in lines:
                f.write(struct.pack("<HH", wdt, len(pts)))
                for px, py in pts:
                    f.write(struct.pack("<2f", px, py))
        print(f"wrote {name}_roadlines.dat: {len(lines)} ways, "
              f"{sum(len(p) for _, p in lines)} points, {os.path.getsize(out)//1024} KB")
    print(f"wrote {name}_roads.dat ({len(buf.getvalue())//1_000_000} MB) + out/{name}_roads_preview.png")


if __name__ == "__main__":
    loc_name = sys.argv[1] if len(sys.argv) > 1 else fd.DEFAULT_LOCATION
    main(loc_name)
