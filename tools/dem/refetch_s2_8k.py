#!/usr/bin/env python3
"""Bring every patch's satellite drape up to the 8192 canvas, resumably.

~30-35 min per patch regardless of patch size -- COG read bandwidth dominates, not pixel count --
so the full set is most of a day. It therefore has to survive being interrupted: a patch whose
_sat.dat is already 8192 is skipped, so re-running picks up where it stopped.

usage:  python refetch_s2_8k.py [--dry] [names...]
"""
import json
import os
import struct
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))
TARGET = 8192


def png_size(path):
    """(w, h) from a PNG header, without decoding the image."""
    try:
        with open(path, "rb") as f:
            head = f.read(26)
        if head[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        return struct.unpack(">II", head[16:24])
    except OSError:
        return None


def current(name, dem_km):
    """Is this patch's drape both 8192 AND covering the ground its heightfield covers?

    Checking resolution alone is not enough. Every patch was briefly 8192 and wrong, because
    fetch_s2.py run directly uses the AUTHORED bbox while the heights were exported against a
    re-centred ~90km one -- so the drape was the central ~22km stretched over the whole patch. A
    driver that only looked at pixel count skipped all 39 as finished.
    """
    side = os.path.join(DEST, name + "_sat.json")
    if not os.path.exists(side):
        return False
    try:
        d = json.load(open(side))
    except (OSError, ValueError):
        return False
    return int(d.get("px", 0)) >= TARGET and abs(float(d.get("span_km", 0)) - dem_km) < 5.0


def main():
    import fetch_dem as fd
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not names:
        names = sorted(fd.LOCATIONS.keys())

    todo, done = [], []
    for n in names:
        if not os.path.exists(os.path.join(DEST, n + ".json")):
            continue                       # never exported; nothing to drape
        meta = json.load(open(os.path.join(DEST, n + ".json")))
        dem_km = meta["w"] * meta["m_per_px"] / 1000.0
        (done if current(n, dem_km) else todo).append(n)

    print("already at %d: %d  (%s)" % (TARGET, len(done), ", ".join(done) or "-"))
    print("to fetch: %d  (~%.1f h at 33 min each)\n" % (len(todo), len(todo) * 33 / 60.0))
    if "--dry" in sys.argv:
        return

    t0 = time.time()
    for i, n in enumerate(todo, 1):
        print("[%d/%d] %s ..." % (i, len(todo), n), flush=True)
        r = subprocess.run([sys.executable, os.path.join(HERE, "fetch_s2.py"), n],
                           capture_output=True, text=True, cwd=HERE)
        tail = [l for l in r.stdout.splitlines() if "coverage" in l or "wrote" in l]
        print("      %s" % (tail[-1] if tail else "FAILED rc=%d %s"
                            % (r.returncode, r.stderr.strip()[-200:])), flush=True)
        el = (time.time() - t0) / 60.0
        print("      elapsed %.0f min, ~%.0f min left\n"
              % (el, el / i * (len(todo) - i)), flush=True)
        time.sleep(5)
    print("done in %.1f h" % ((time.time() - t0) / 3600.0))


if __name__ == "__main__":
    main()
