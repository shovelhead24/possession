"""Export the stitched heightmap into the Godot mock as raw u16 + meta json.
Artifact stays out of git (game/mocks/dem/ is ignored) — recipe is source.
Run after fetch_dem.py: python export_to_game.py
"""
import json
import math
import os

from PIL import Image

import fetch_dem as fd

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))


def main():
    img = Image.open(os.path.join(HERE, "out", "heightmap_16bit.png"))
    if img.mode != "I;16":
        img = img.convert("I;16")
    w, h = img.size
    raw = img.tobytes()  # 16-bit little-endian, row-major, north-up, units 1/16 m

    x0 = int(fd.tile_xy(fd.LAT_MIN, fd.LON_MIN, fd.ZOOM)[0])
    y0 = int(fd.tile_xy(fd.LAT_MAX, fd.LON_MAX, fd.ZOOM)[1])
    center_lat = (fd.LAT_MIN + fd.LAT_MAX) / 2.0
    m_per_px = 156543.03392 * math.cos(math.radians(center_lat)) / (2 ** fd.ZOOM)

    mill_lat, mill_lon, _ = fd.MARKERS[1]
    mx, my = fd.tile_xy(mill_lat, mill_lon, fd.ZOOM)
    cam_px = [int((mx - x0) * 256), int((my - y0) * 256)]

    os.makedirs(DEST, exist_ok=True)
    with open(os.path.join(DEST, "millstreet.r16"), "wb") as f:
        f.write(raw)
    meta = {"w": w, "h": h, "m_per_px": round(m_per_px, 3), "camera_px": cam_px,
            "name": "Millstreet (Cork-Kerry route, Terrarium z%d)" % fd.ZOOM}
    with open(os.path.join(DEST, "millstreet.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("wrote %s (%d MB) + millstreet.json  m/px=%.2f  camera_px=%s"
          % (DEST, len(raw) // 1_000_000, m_per_px, cam_px))


if __name__ == "__main__":
    main()
