#!/usr/bin/env python3
"""Read a chain.gd transcript and line up what the player BELIEVED against what was true.

The mock writes three channels into one file:
  plain lines   what the player was shown
  #STATE        what was actually underneath, once per cycle
  #NOTE         what the player thought was going on, when they thought it

Readability is the gap between the last two. A note saying "Corrin is about to raid" next to a
next-cycle distribution of lift=0.08 means the routines mis-telegraphed; the same note next to
lift=0.71 means they worked. Nothing else measures this -- see .decisions/design-laws.md
#meat-model-arbitrates.

usage:  python tools/read_chain_log.py [run_number|last]   (default: last)
"""
import json
import os
import sys

PATH = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "HaloTest",
                    "chain_transcript.txt")


def runs(path):
    out, cur = [], None
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("#RUN"):
            cur = {"started": line[5:].strip(), "lines": []}
            out.append(cur)
        elif cur is not None:
            cur["lines"].append(line)
    return out


def main():
    if not os.path.exists(PATH):
        sys.exit("no transcript at %s -- play a run first" % PATH)
    rs = runs(PATH)
    if not rs:
        sys.exit("transcript has no runs in it")

    which = sys.argv[1] if len(sys.argv) > 1 else "last"
    r = rs[-1] if which == "last" else rs[int(which) - 1]
    print("run %d of %d, started %s\n" % (rs.index(r) + 1, len(rs), r["started"]))

    notes, states, prose = [], [], 0
    for line in r["lines"]:
        if line.startswith("#NOTE"):
            notes.append(json.loads(line[6:]))
        elif line.startswith("#STATE"):
            states.append(json.loads(line[7:]))
        elif line.startswith("#KHAIBIT"):
            print(line)
        elif line.strip():
            prose += 1

    print("%d cycles, %d lines of prose, %d notes\n" % (len(states), prose, len(notes)))

    if not notes:
        print("No notes in this run. Type ';' followed by a thought while playing -- it is free\n"
              "and changes nothing, and it is the only channel that says what you believed.")
        return

    for n in notes:
        print("=" * 78)
        print("cycle %-3d in %-9s purse %d" % (n["cycle"], n["here"], n["purse"]))
        print("  ✎ %s" % n["note"])
        print("  -- what was actually true --")
        for p, d in n["places"].items():
            flag = " KNOWN" if d.get("known") else ""
            print("     %-9s cattle %-4d pressure %-5.2f standing %-5.2f last %-11s act %d%s"
                  % (p, d["cattle"], d["pressure"], d["standing"], d["last"] or "-",
                     d["activity"], flag))
        print("  -- what each was about to do (next-cycle distribution) --")
        for p, dist in n["about_to"].items():
            top = sorted(dist.items(), key=lambda kv: -kv[1])[:4]
            print("     %-9s %s" % (p, "  ".join("%s %.0f%%" % (k, v * 100) for k, v in top)))
        print()

    # a run's arc, so a note can be placed in it
    if states:
        print("=" * 78)
        print("arc of the run (cattle / pressure)")
        places = list(states[0]["places"].keys())
        print("  cycle  " + "".join("%-20s" % p for p in places))
        for s in states:
            row = "  %-7s" % s["cycle"]
            for p in places:
                d = s["places"][p]
                row += "%-20s" % ("%d / %.2f" % (d["cattle"], d["pressure"]))
            print(row)


if __name__ == "__main__":
    main()
