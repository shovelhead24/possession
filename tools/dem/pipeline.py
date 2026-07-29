"""Full splice pipeline for ring tiling: heights + satellite, one uniform patch size, resumable.

Runs fetch_dem -> export_to_game -> fetch_s2 for every location, with every bbox re-centred to a
uniform PATCH_SIZE_KM footprint (the authored boxes vary: millstreet is 84km, the Batch-4 scout
boxes ~22km, and tiling the ring needs one size).

RESUMABLE: skips any location whose outputs already exist, so it can be re-run after an
interruption, a rate-limit, or a crash without redoing hours of work. --force to redo anyway.

Recipe-not-artifact: this script is committed; game/mocks/dem/ and out/ are gitignored.

Usage:
  python pipeline.py                 # every location, heights + satellite
  python pipeline.py --no-s2         # heights only (much faster)
  python pipeline.py millstreet ...  # named subset
  python pipeline.py --size 84       # override patch size in km (default 84)
"""
import os
import sys
import time
import traceback

import fetch_dem as fd
import export_to_game
import fetch_s2

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "game", "mocks", "dem"))
DEFAULT_SIZE_KM = 84.0   # matches millstreet; 36 of these tile the 3000km ring


def done_heights(name):
    return (os.path.exists(os.path.join(DEST, f"{name}.r16"))
            and os.path.exists(os.path.join(DEST, f"{name}.json")))


def done_sat(name):
    p = os.path.join(DEST, f"{name}_sat.dat")
    # a token-size file means a failed/empty mosaic; treat as not done so a re-run retries it
    return os.path.exists(p) and os.path.getsize(p) > 200_000


def run(names, size_km, do_s2, force):
    fd.PATCH_SIZE_KM = size_km
    total = len(names)
    t_start = time.time()
    ok, skipped, failed = 0, 0, []

    for i, name in enumerate(names, 1):
        head = f"[{i}/{total}] {name}"
        need_h = force or not done_heights(name)
        need_s = do_s2 and (force or not done_sat(name))
        if not need_h and not need_s:
            print(f"{head}: already complete, skipping")
            skipped += 1
            continue

        t0 = time.time()
        try:
            if need_h:
                print(f"{head}: heights ...", flush=True)
                fd.set_location(name)
                fd.main()
                export_to_game.main(name)
            if need_s:
                print(f"{head}: sentinel-2 ...", flush=True)
                # fetch_s2.main() calls set_location itself; PATCH_SIZE_KM is module-level so the
                # widened bbox is reapplied there too -- heights and imagery stay aligned.
                fetch_s2.main(name)
            ok += 1
            print(f"{head}: done in {time.time() - t0:.0f}s "
                  f"(elapsed {(time.time() - t_start) / 60:.1f} min)", flush=True)
        except Exception:
            # one bad location must not kill an hour-long run
            failed.append(name)
            print(f"{head}: FAILED\n{traceback.format_exc()}", flush=True)

    print(f"\npipeline: {ok} processed, {skipped} skipped, {len(failed)} failed "
          f"in {(time.time() - t_start) / 60:.1f} min")
    if failed:
        print("failed: " + " ".join(failed))
        print("re-run the same command to retry just those (completed ones are skipped)")


def main():
    args = [a for a in sys.argv[1:]]
    do_s2 = "--no-s2" not in args
    force = "--force" in args
    size = DEFAULT_SIZE_KM
    if "--size" in args:
        size = float(args[args.index("--size") + 1])
        del args[args.index("--size"):args.index("--size") + 2]
    names = [a for a in args if not a.startswith("--")]
    if not names:
        names = list(fd.LOCATIONS)
    unknown = [n for n in names if n not in fd.LOCATIONS]
    if unknown:
        print("unknown locations: " + ", ".join(unknown))
        sys.exit(1)
    print(f"pipeline: {len(names)} locations @ {size:.0f}km, "
          f"satellite {'ON' if do_s2 else 'off'}, force={force}")
    run(names, size, do_s2, force)


if __name__ == "__main__":
    main()
