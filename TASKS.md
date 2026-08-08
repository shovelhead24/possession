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

- [x] **Image-review patches 1–10** (alphabetical from `atacama`). For each: read
      `out/<name>_s2_preview.jpg`, confirm or correct `trees` / `tint` / `tree_hi` / `weather` in
      `PATCHES`, note seams or artefacts. Append findings to `docs/patch-review.md`.
- [x] **Image-review patches 11–20** — same.
- [x] **Image-review patches 21–30** — same.
- [x] **Image-review patches 31–39** — same.
- [x] **Verify hedgerows by screenshot** (`-- --shots <patch>`). Do they apply at all off the home
      patch; do junctions mesh or interpenetrate; do they follow the ground or float; do they sit on
      the correct side of the carriageway. Read the PNGs, do not assume.
- [x] **Hedge junctions.** Verified straight runs only -- no junction happened to be in frame.
      Where two roads meet, each lays its own ribbon and nothing merges them, so they almost
      certainly interpenetrate. Shoot a crossroads specifically.
- [x] **Hedge variety.** Four kinds by biome (bank / scrub / wall / none), width and height varying
      smoothly along a run, position-hashed gaps for gateways. Still one PROFILE and one texture —
      a stone wall currently differs from a hedge only in size and tint, which will not survive
      being looked at. Needs its own geometry when the vegetation import lands.
- [ ] **Vegetation model imports.** The fir pack is the only tree asset and it is doing Java, Cape
      fynbos and Lofoten birch scrub via a colour tint. Import proper species; check
      `assets/grass_pack_of_9_vars_lowpoly_game_ready.zip` and `low_poly_red_spruce_tree...zip`
      which are unused.
- [ ] **Triangle budget.** 727k tris / 13 fps at ground level in the home patch, trees dominating
      (24k instances, 24k billboards). Profile per system, then cut. Driving at 13 fps is not fun.
- [ ] **Rolling wheels.** The car's wheels do not turn or steer. Also suspension travel over the
      terrain it now follows correctly.
- [ ] **Vehicle variety.** One box car. `assets/halo_warthog.zip` exists and is unused.
- [ ] **Offroad feel.** Particle/dust when the car leaves the carriageway (`_road_at` already gives
      the trigger), plus grip and camera-shake difference on/off road. Off-roading is meant to be a
      real mode, not a punishment.
- [ ] **Refetch buildings for the 7 patches that have them** — they were fetched against the
      authored bbox, so they're 10–16% out. `fetch_osm_buildings.py` is fixed; just re-run with
      `--force`.
- [ ] **Hedgerows + verge everywhere.** Once `*_roadlines.dat` exists for all patches, the ribbon
      and the tree-clearing currently only run on the home patch — generalise past `millstreet`.
- [ ] **Measure drape QUALITY, not just coverage.** `salar_uyuni` is pure white (clipped),
      `palawan` is ~55% cloud, `guri_dam` is two seasons across a seam — and all three report 100%
      coverage, because coverage counts filled pixels. Scene selection sorts on the scene-wide STAC
      cloud figure, which says nothing about our bbox. Measure cloud/haze and clipping in the
      RESULT, reject, re-pick. Do this before the remaining 8192 refetches bake it in.
- [ ] **Per-patch sea level.** danube_delta renders 64% ocean because delta land sits at 0-2m
      under a global 0.5m SEA_LEVEL. Any low-lying patch has this. Needs a per-patch offset.
- [ ] **Colour-match scenes at paste time** in `fetch_s2.py`. CONFIRMED SYSTEMIC: 4 of 4
      multi-scene patches are visibly patchworked (`guri_dam` worst — two seasons either side of a
      hard vertical seam, then `danube_delta`, `mongolia_steppe`, `dolomites`). Only single-scene
      patches are clean. Normalise exposure per scene against the overlap before pasting.
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
