"""Export the stitched heightmap into the Godot mock as raw u16 + meta json.
Artifact stays out of git (game/mocks/dem/ is ignored) — recipe is source.
Run after fetch_dem.py: python export_to_game.py [location]

location must match whatever you last ran fetch_dem.py with (default
"millstreet" for both, so the old one-location workflow is unchanged).
Note: ring_vibes.gd currently only loads files named "millstreet.*" — to make
a different location the active one in the mock, either rename the exported
files or update the DEM_* constants at the top of ring_vibes.gd.
"""
import json
import math
import os
import sys

from PIL import Image

import fetch_dem as fd

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))


def main(name):
    fd.set_location(name)
    loc = fd.LOCATIONS[name]

    img = Image.open(os.path.join(HERE, "out", "heightmap_16bit.png"))
    if img.mode != "I;16":
        img = img.convert("I;16")
    w, h = img.size
    raw = img.tobytes()  # 16-bit little-endian, row-major, north-up, units 1/16 m

    x0 = int(fd.tile_xy(fd.LAT_MIN, fd.LON_MIN, fd.ZOOM)[0])
    y0 = int(fd.tile_xy(fd.LAT_MAX, fd.LON_MAX, fd.ZOOM)[1])
    center_lat = (fd.LAT_MIN + fd.LAT_MAX) / 2.0
    m_per_px = 156543.03392 * math.cos(math.radians(center_lat)) / (2 ** fd.ZOOM)

    cam_lat, cam_lon = loc["camera"]
    mx, my = fd.tile_xy(cam_lat, cam_lon, fd.ZOOM)
    cam_px = [int((mx - x0) * 256), int((my - y0) * 256)]

    os.makedirs(DEST, exist_ok=True)
    with open(os.path.join(DEST, f"{name}.r16"), "wb") as f:
        f.write(raw)

    # Detail texture: R/G = normal perturbation (east/north gradients), B = height/4m.
    # Saved as PNG bytes in a .dat so Godot's importer ignores it; loaded manually at runtime.
    import numpy as np
    arr = np.frombuffer(raw, dtype="<u2").reshape(h, w).astype(np.float64) / 16.0
    gpx = np.gradient(arr, axis=1) / m_per_px   # east+
    gpy = np.gradient(arr, axis=0) / m_per_px   # south+
    s = 1.2  # slope normalization (~50 deg full-scale)
    r_ch = np.clip(128 + (-gpx / s) * 127, 0, 255).astype(np.uint8)
    g_ch = np.clip(128 + (gpy / s) * 127, 0, 255).astype(np.uint8)
    b_ch = np.clip(arr / 4.0, 0, 255).astype(np.uint8)
    detail = Image.merge("RGB", [Image.fromarray(c) for c in (r_ch, g_ch, b_ch)])
    import io
    buf = io.BytesIO()
    detail.save(buf, format="PNG")
    with open(os.path.join(DEST, f"{name}_detail.dat"), "wb") as f:
        f.write(buf.getvalue())
    print("wrote %s_detail.dat (%d MB png-in-dat)" % (name, len(buf.getvalue()) // 1_000_000))
    meta = {"w": w, "h": h, "m_per_px": round(m_per_px, 3), "camera_px": cam_px,
            "name": "%s (Terrarium z%d)" % (loc["label"], fd.ZOOM)}
    with open(os.path.join(DEST, f"{name}.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("wrote %s (%d MB) + %s.json  m/px=%.2f  camera_px=%s"
          % (DEST, len(raw) // 1_000_000, name, m_per_px, cam_px))


if __name__ == "__main__":
    loc_name = sys.argv[1] if len(sys.argv) > 1 else fd.DEFAULT_LOCATION
    main(loc_name)
