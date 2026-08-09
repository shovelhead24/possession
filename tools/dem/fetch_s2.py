"""Fetch Sentinel-2 true-color imagery for the DEM bbox via Earth Search STAC (no auth).
Reads windowed/downsampled data straight from COGs on AWS; mosaics the least-cloudy
scenes onto a canvas aligned with the DEM grid; exports to the Godot mock.
License: free incl. commercial — credit line "Contains modified Copernicus Sentinel data".

Usage: python fetch_s2.py [location]
  location defaults to "millstreet" if omitted. Must match fetch_dem.py's LOCATIONS.
"""
import io
import json
import os
import sys
import urllib.request

import numpy as np
import rasterio
from rasterio.warp import transform_bounds
from rasterio.windows import from_bounds
from PIL import Image

import fetch_dem as fd

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))
STAC = "https://earth-search.aws.element84.com/v1/search"

# Sentinel-2 is 10 m/px native and a patch is ~84-97km, so ~8400px is the real information
# content of the source. At 4096 we were storing ~24 m/px -- discarding well over half of what
# the satellite actually resolves, and no amount of runtime upscaling gets it back (measured:
# asking the runtime for 8192 off a 4096 canvas cost memory and time for nothing).
# 8192 is ~11 m/px, essentially native. Costs ~4x the download and disk; as an S3TC texture it
# still uses less VRAM than the 4096 raw drape did.
OUT_W, OUT_H = 8192, 8192

# Quality, not just coverage. The STAC eo:cloud_cover we sort on is a scene-WIDE figure and says
# nothing about our little bbox: the least-cloudy scene overall can still be solid haze over the
# patch (palawan came out half grey sheet). So we grade every pixel we actually paste and re-pick.
# Clouds and haze read bright AND desaturated; a blown highlight is near-white in every channel.
CLOUD_BRIGHT = 155   # mean channel value above which a colourless pixel reads as cloud/haze
CLOUD_SAT = 28       # max-min channel spread below which "bright" means grey, not real colour
CLIP_LEVEL = 250     # every channel at/above this -- highlight blown, no detail to recover
MAX_SCENES = 10      # COG reads to spend hunting clean pixels; bounds an all-white / all-haze patch


def _cloud_clip(rgb):
    """(cloud/haze mask, clipped-white mask) over an HxWx3 uint8 true-colour block.

    Bright natural ground -- salt flats, snow, pale sand -- trips the cloud test too, on purpose:
    it routes those pixels to the fallback tier so a genuinely clearer scene wins where one exists,
    and they still get painted when none does (salar_uyuni is white because the ground is white)."""
    a = rgb.astype(np.int16)
    bright = a.mean(axis=2)
    sat = a.max(axis=2) - a.min(axis=2)
    cloud = (bright > CLOUD_BRIGHT) & (sat < CLOUD_SAT)
    clip = a.min(axis=2) >= CLIP_LEVEL
    return cloud, clip


def stac_search():
    body = {
        "collections": ["sentinel-2-l2a"],
        "bbox": [fd.LON_MIN, fd.LAT_MIN, fd.LON_MAX, fd.LAT_MAX],
        "datetime": "2023-04-01T00:00:00Z/2026-06-30T23:59:59Z",
        "query": {"eo:cloud_cover": {"lt": 45}},
        "sortby": [{"field": "properties.eo:cloud_cover", "direction": "asc"}],
        # 30 was too few for a patch spanning more than one MGRS tile: sorted purely by cloud
        # cover, all 30 can come from the SAME tile and the rest of the bbox never gets filled.
        # Cape Peninsula straddles two and came out 57.9% covered, the remainder falling back to
        # flat tint. The loop stops early once every pixel is clean-covered (or MAX_SCENES reads
        # in), so a bigger pool costs nothing when the first few scenes are enough.
        "limit": 120,
    }
    req = urllib.request.Request(
        STAC, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["features"]


def main(name):
    fd.set_location(name)
    # MATCH THE HEIGHTFIELD, ALWAYS. set_location() gives the AUTHORED bbox, but the exported patch
    # was re-centred to a uniform footprint by pipeline.py (which sets fd.PATCH_SIZE_KM before
    # calling). Running this script directly therefore silently fetched imagery for a different --
    # usually far smaller -- piece of ground than the heights cover: for most patches the authored
    # box is ~22km against a ~90km patch, so the drape came out 4x too zoomed and geographically
    # wrong everywhere but the centre. It looked like a successful fetch, and overwrote good data.
    # Deriving the span from the exported .json makes the two agree by construction rather than by
    # the caller remembering a flag.
    meta_path = os.path.join(DEST, f"{name}.json")
    if os.path.exists(meta_path):
        meta = json.load(open(meta_path))
        span_km = meta["w"] * meta["m_per_px"] / 1000.0
        fd._expand_bbox(span_km)
        print(f"bbox matched to the exported heightfield: {span_km:.1f} km across")
    else:
        print("WARNING: no {name}.json — using the authored bbox, which may not match any export")
    items = stac_search()
    print(f"{len(items)} candidate scenes (sorted by cloud cover)")
    canvas = np.zeros((OUT_H, OUT_W, 3), dtype=np.uint8)
    filled = np.zeros((OUT_H, OUT_W), dtype=bool)   # any pixel written -- clean OR fallback
    good = np.zeros((OUT_H, OUT_W), dtype=bool)      # written with a clean (cloud/clip-free) pixel
    # canvas geographic extent = the DEM bbox; simple lat/lon linear mapping (fine at this scale)
    reads = 0
    for it in items:
        if good.all():
            break
        href = it["assets"]["visual"]["href"]
        cc = it["properties"].get("eo:cloud_cover", -1)
        try:
            with rasterio.open(href) as src:
                l, b, rgt, t = transform_bounds("EPSG:4326", src.crs,
                                                fd.LON_MIN, fd.LAT_MIN, fd.LON_MAX, fd.LAT_MAX)
                win = from_bounds(max(l, src.bounds.left), max(b, src.bounds.bottom),
                                  min(rgt, src.bounds.right), min(t, src.bounds.top), src.transform)
                if win.width <= 0 or win.height <= 0:
                    continue
                # which part of the canvas does this scene's overlap cover?
                ol, ob, orr, ot = transform_bounds(src.crs, "EPSG:4326",
                                                   *rasterio.windows.bounds(win, src.transform))
                x0 = int((ol - fd.LON_MIN) / (fd.LON_MAX - fd.LON_MIN) * OUT_W)
                x1 = int((orr - fd.LON_MIN) / (fd.LON_MAX - fd.LON_MIN) * OUT_W)
                y0 = int((fd.LAT_MAX - ot) / (fd.LAT_MAX - fd.LAT_MIN) * OUT_H)
                y1 = int((fd.LAT_MAX - ob) / (fd.LAT_MAX - fd.LAT_MIN) * OUT_H)
                x0, y0 = max(x0, 0), max(y0, 0)
                x1, y1 = min(x1, OUT_W), min(y1, OUT_H)
                if x1 <= x0 or y1 <= y0:
                    continue
                gwin = good[y0:y1, x0:x1]
                if gwin.all():
                    continue        # already clean here; don't spend a COG read to reconfirm it
                data = src.read([1, 2, 3], window=win, out_shape=(3, y1 - y0, x1 - x0))
                rgb = np.transpose(data, (1, 2, 0))
                reads += 1
                valid = rgb.sum(axis=2) > 10          # skip nodata-black
                cl, cp = _cloud_clip(rgb)
                clean = valid & ~cl & ~cp
                fwin = filled[y0:y1, x0:x1]
                wg = clean & ~gwin                    # clean pixels upgrade whatever is there
                wf = valid & ~fwin & ~clean           # dirty pixels only fill an untouched hole
                canvas[y0:y1, x0:x1][wg] = rgb[wg]
                canvas[y0:y1, x0:x1][wf] = rgb[wf]
                gwin |= wg
                fwin |= wg | wf
                print(f"  {it['id']}  stac_cloud={cc:.1f}%  clean {wg.sum()//1000}k  "
                      f"fill {wf.sum()//1000}k  now {100.0*good.mean():.1f}% clean / "
                      f"{100.0*filled.mean():.1f}% filled")
        except Exception as e:  # naive prototype: skip bad scenes, keep going
            print(f"  {it['id']} skipped: {e}")
            continue
        # Coverage first, quality second. A window that still has un-clean pixels keeps getting
        # read so a later, clearer scene can re-pick it -- but an all-white salt flat or a
        # permanently-hazy coast has no clean pixel to find, so cap the reads or it walks the whole
        # 120-deep pool. Filling stays complete because dirty scenes still patch holes above.
        if reads >= MAX_SCENES:
            break

    img = Image.fromarray(canvas)
    img.save(os.path.join(HERE, "out", f"{name}_s2_preview.jpg"), quality=88)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    os.makedirs(DEST, exist_ok=True)
    with open(os.path.join(DEST, f"{name}_sat.dat"), "wb") as f:
        f.write(buf.getvalue())
    # Record what this drape actually covers AND how good it is. Resolution alone is not enough to
    # tell whether a sat.dat is current: every patch was briefly 8192 AND wrong, fetched against the
    # authored bbox instead of the exported one. A driver that checks only pixel count would skip
    # all of them as done. clean/cloud/clip grade the RESULT so a triage pass can find the drapes
    # worth re-picking (heavy cloud) versus the ones that are simply white ground (nothing to fix).
    fc, fp = _cloud_clip(canvas)
    n = int(filled.sum()) or 1
    json.dump({"px": OUT_W, "span_km": round((fd.LAT_MAX - fd.LAT_MIN) * 111.32, 2),
               "coverage": round(100.0 * float(filled.mean()), 1),
               "clean": round(100.0 * float(good.sum()) / n, 1),
               "cloud": round(100.0 * float((fc & filled).sum()) / n, 1),
               "clip": round(100.0 * float((fp & filled).sum()) / n, 1)},
        open(os.path.join(DEST, f"{name}_sat.json"), "w"))

    print(f"coverage {100.0*filled.mean():.1f}%  clean {100.0*good.sum()/n:.1f}%  "
          f"cloud {100.0*(fc & filled).sum()/n:.1f}%  clip {100.0*(fp & filled).sum()/n:.1f}%  "
          f"wrote {name}_sat.dat ({len(buf.getvalue())//1_000_000} MB) + out/{name}_s2_preview.jpg")


if __name__ == "__main__":
    loc_name = sys.argv[1] if len(sys.argv) > 1 else fd.DEFAULT_LOCATION
    main(loc_name)
