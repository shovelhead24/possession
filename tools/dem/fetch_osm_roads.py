"""Fetch OSM roads for the DEM bbox via Overpass, rasterize to a road mask
aligned with the sat/detail UVs (8192px ~ 9.3 m/px so regional roads hold width).
Export as PNG-in-dat for the mock. License: ODbL — attribution '(c) OpenStreetMap contributors'.

Usage: python fetch_osm_roads.py
"""
import io
import json
import os
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw

import fetch_dem as fd

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))
SIZE = 8192

QUERY = """
[out:json][timeout:180];
way["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified)$"]
  (%f,%f,%f,%f);
out geom;
""" % (fd.LAT_MIN, fd.LON_MIN, fd.LAT_MAX, fd.LON_MAX)

WIDTHS = {"motorway": 3, "trunk": 3, "primary": 2, "secondary": 2, "tertiary": 1, "unclassified": 1}


def to_px(lat, lon):
    x = (lon - fd.LON_MIN) / (fd.LON_MAX - fd.LON_MIN) * SIZE
    y = (fd.LAT_MAX - lat) / (fd.LAT_MAX - fd.LAT_MIN) * SIZE
    return x, y


def main():
    req = urllib.request.Request(
        "https://overpass-api.de/api/interpreter",
        ("data=" + urllib.parse.quote(QUERY)).encode(),
        {"User-Agent": "possession-game-dem-prototype/0.1 (solo dev tooling)",
         "Content-Type": "application/x-www-form-urlencoded"})
    print("querying Overpass...")
    with urllib.request.urlopen(req, timeout=300) as r:
        ways = json.loads(r.read())["elements"]
    print(f"{len(ways)} road ways")

    img = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(img)
    for way in ways:
        wdt = WIDTHS.get(way.get("tags", {}).get("highway", ""), 1)
        pts = [to_px(g["lat"], g["lon"]) for g in way.get("geometry", [])]
        if len(pts) > 1:
            draw.line(pts, fill=255, width=wdt, joint="curve")

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    os.makedirs(DEST, exist_ok=True)
    with open(os.path.join(DEST, "millstreet_roads.dat"), "wb") as f:
        f.write(buf.getvalue())
    img.resize((2048, 2048)).save(os.path.join(HERE, "out", "roads_preview.png"))
    print(f"wrote millstreet_roads.dat ({len(buf.getvalue())//1_000_000} MB) + out/roads_preview.png")


if __name__ == "__main__":
    main()
