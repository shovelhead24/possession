"""Quick elevation stats for a candidate bbox — no export, just a verify/scout pass
before adding a location to fetch_dem.py's LOCATIONS. Reuses fetch_dem's tile fetch.

Usage: python check_stats.py <lat_min> <lat_max> <lon_min> <lon_max> [zoom] [label]
"""
import sys
import numpy as np
from PIL import Image

import fetch_dem as fd


def main():
    lat_min, lat_max, lon_min, lon_max = (float(a) for a in sys.argv[1:5])
    zoom = int(sys.argv[5]) if len(sys.argv) > 5 else 12
    label = sys.argv[6] if len(sys.argv) > 6 else "candidate"

    x0f, y1f = fd.tile_xy(lat_min, lon_min, zoom)
    x1f, y0f = fd.tile_xy(lat_max, lon_max, zoom)
    x0, x1 = int(x0f), int(x1f)
    y0, y1 = int(y0f), int(y1f)
    cols, rows = x1 - x0 + 1, y1 - y0 + 1
    print(f"{label}: {cols}x{rows} tiles at z{zoom}")

    mosaic = Image.new("RGB", (cols * 256, rows * 256))
    cache = fd.OUT + "/tiles"
    import os
    os.makedirs(cache, exist_ok=True)
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            mosaic.paste(fd.fetch(zoom, tx, ty, cache), ((tx - x0) * 256, (ty - y0) * 256))

    arr = np.asarray(mosaic, dtype=np.float64)
    e = (arr[..., 0] * 256 + arr[..., 1] + arr[..., 2] / 256.0) - 32768.0
    sea = e < 0.5
    land = e[~sea]
    print(f"elev: min {e.min():.0f}m  max {e.max():.0f}m  p50 {np.percentile(e,50):.0f}m  "
          f"p99 {np.percentile(e,99):.0f}m  land-relief(p99-p1) {np.percentile(land,99)-np.percentile(land,1):.0f}m"
          if land.size else "all sea")
    print(f"sea fraction: {100.0*sea.mean():.1f}%")


if __name__ == "__main__":
    main()
