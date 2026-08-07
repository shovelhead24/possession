# Work queue

Durable queue for scheduled/resumed sessions. The cron schedule dies with a session; this file
doesn't. A session that wakes takes the **top unchecked item**, does it, ticks it, commits.

Rules:
- One item per wake. Finish it or leave a note saying where it stopped.
- Read images before changing biome numbers. `tools/dem/patch_census.py` proposes; the image decides.
- Never re-centre or refetch a patch unprompted — that destroys the old one.
- Don't write more docs unless the item asks for one.

---

## Now

- [ ] **Image-review patches 1–10** (alphabetical from `atacama`). For each: read
      `out/<name>_s2_preview.jpg`, confirm or correct `trees` / `tint` / `tree_hi` / `weather` in
      `PATCHES`, note seams or artefacts. Append findings to `docs/patch-review.md`.
- [ ] **Image-review patches 11–20** — same.
- [ ] **Image-review patches 21–30** — same.
- [ ] **Image-review patches 31–39** — same.
- [ ] **Offroad feel.** Particle/dust when the car leaves the carriageway (`_road_at` already gives
      the trigger), plus grip and camera-shake difference on/off road. Off-roading is meant to be a
      real mode, not a punishment.
- [ ] **Refetch buildings for the 7 patches that have them** — they were fetched against the
      authored bbox, so they're 10–16% out. `fetch_osm_buildings.py` is fixed; just re-run with
      `--force`.
- [ ] **Hedgerows + verge everywhere.** Once `*_roadlines.dat` exists for all patches, the ribbon
      and the tree-clearing currently only run on the home patch — generalise past `millstreet`.
- [ ] **Colour-match scenes at paste time** in `fetch_s2.py`. `mongolia_steppe` shows obvious
      rectangular seams where scenes of different balance were pasted.
- [ ] **Reject building sites on cliffs.** `--align` says 8,235 of 119,703 sit on ground steeper
      than their undercroft covers, worst a 1,195 m drop. Add a slope limit at placement.
- [ ] **Regression sweep script.** Run `--align`, `--selftest`, `--texprobe`, diff against the last
      known-good, report only what changed. This session's worst bugs were silent successes.
- [ ] **Fix marker displacement** in the census — it takes the worst marker, so any patch with
      route-spanning markers scores badly by design. Use the camera anchor.

## Blocked / waiting

- 8192 refetch: running via the Startup task. ~36 patches left of awake time.
- Roads fetch: running. Hedgerows everywhere depends on it.

## Done

- Coastal batch, ring now 35/35 unique
- Atmosphere exit, star rotation on the sun's axis
- Roads: trees off carriageway, hedge ribbon, verge
- Height tier box-filtering; `--align` reports 0/4235 mismatches
- S3TC/BPTC compression, `[U]`
- `[Y]` probe, `patch_census.py`
