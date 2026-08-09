# Work queue

Durable queue for scheduled/resumed sessions. The cron schedule dies with a session; this file
doesn't. A session that wakes takes the **top unchecked item**, does it, ticks it, commits.

Rules:
- One item per wake. Finish it or leave a note saying where it stopped.
- Read images before changing biome numbers. `tools/dem/patch_census.py` proposes; the image decides.
- **Every screenshot session gets an entry in `logs/shots/JOURNAL.md`** — what it was taken to
  check, what was actually there, what tasks fell out. Shots go in a timestamped folder and are
  never overwritten. A shot with no stated purpose is not worth taking.
- Never re-centre or refetch a patch unprompted â€” that destroys the old one.
- Don't write more docs unless the item asks for one.

---

## Now

- [x] **Image-review patches 1â€“10** (alphabetical from `atacama`). For each: read
      `out/<name>_s2_preview.jpg`, confirm or correct `trees` / `tint` / `tree_hi` / `weather` in
      `PATCHES`, note seams or artefacts. Append findings to `docs/patch-review.md`.
- [x] **Image-review patches 11â€“20** â€” same.
- [x] **Image-review patches 21â€“30** â€” same.
- [x] **Image-review patches 31â€“39** â€” same.
- [x] **Verify hedgerows by screenshot** (`-- --shots <patch>`). Do they apply at all off the home
      patch; do junctions mesh or interpenetrate; do they follow the ground or float; do they sit on
      the correct side of the carriageway. Read the PNGs, do not assume.
- [x] **Hedge junctions.** Verified straight runs only -- no junction happened to be in frame.
      Where two roads meet, each lays its own ribbon and nothing merges them, so they almost
      certainly interpenetrate. Shoot a crossroads specifically.
- [x] **Hedge variety.** Four kinds by biome (bank / scrub / wall / none), width and height varying
      smoothly along a run, position-hashed gaps for gateways. Still one PROFILE and one texture â€”
      a stone wall currently differs from a hedge only in size and tint, which will not survive
      being looked at. Needs its own geometry when the vegetation import lands.
- [x] **Vegetation model imports.** Both unused packs opened. Grass pack is now close-range ground
      cover (42m bubble, ~3k instances, +12k tris) â€” the biggest win, since the drape is 11 m/px at
      best and the near field had no shape at all.
- [x] **Species variety — GENERATED (palm/broadleaf/scrub), not blocked. Old note: STILL NO SPECIES VARIETY â€” blocked on assets.** The spruce pack is a second CONIFER, so it
      does not help. There is no teak, palm, fynbos or birch in `assets/`, which means Java, Cape
      and Lofoten are still tinted Irish firs. This needs downloading models, not code. Candidates:
      a broadleaf, a palm, a low scrub bush.
- [x] **Triangle budget.** 700k -> 316k. Trees were 71%; the fir pack's billboard tier cost ~16 tris, now 4. Next largest is the far band at 96k. Was: 727k / 13 fps, trees dominating
      (24k instances, 24k billboards). Profile per system, then cut. Driving at 13 fps is not fun.
- [x] **Rolling wheels.** The car's wheels do not turn or steer. Also suspension travel over the
      terrain it now follows correctly.
- [x] **Vehicle variety.** Box car + warthog model, [L] swaps between them in DRIVE. The halo_warthog
      GLTF now loads as a second vehicle (scale and length-axis measured from its AABB; the box stays
      the fallback when the gitignored asset is absent). NOT eyeballed: this sandbox can't launch the
      Godot binary (it lives outside the repo) to run `-- --shots`. The shot harness now writes
      vehicle_box/warthog.png at the end of a run — do a shot pass, and if the warthog drives
      tail-first, set `WARTHOG_YAW = PI` in ring_vibes.gd (the only un-derivable bit).
- [x] **Offroad feel.** Particle/dust when the car leaves the carriageway (`_road_at` already gives
      the trigger), plus grip and camera-shake difference on/off road. Off-roading is meant to be a
      real mode, not a punishment.
- [x] **Refetch buildings for the 7 patches that have them** â€” they were fetched against the
      authored bbox, so they're 10â€“16% out. `fetch_osm_buildings.py` is fixed; just re-run with
      `--force`.
- [x] **Hedgerows + verge everywhere.** The live streaming landing path re-scattered trees and
      rebuilt the ribbon but never reloaded the centrelines for the streamed patch, so in play both
      stayed pinned to millstreet. The shot harness already swapped `_roadline_patch` per patch;
      copied that swap into the stream-land path so the ribbon and tree-clearing follow you. Not
      shot-verified: the sandbox can't launch the out-of-repo Godot binary, and `--shots` wouldn't
      distinguish this anyway (that path had its own per-patch swap already).
- [x] **Measure drape QUALITY, not just coverage.** `fetch_s2.py` now grades every pasted pixel
      (`_cloud_clip`: bright+desaturated = cloud/haze, all-channels>=250 = clipped). Clean pixels
      upgrade whatever's there; dirty ones only fill untouched holes, so a later clearer scene
      re-picks the hazy left half of `palawan`. Read cap (10 scenes) bounds an all-white salt flat.
      `_sat.json` gains clean/cloud/clip % for triage. Verified by the detector reading right on the
      three cited previews (palawan haze, salar clip, guri_dam is a SEASONAL seam not cloud -> the
      colour-match item, correctly not flagged here). NOT run-verified: python is gated in this
      sandbox, and the 8192 batch already reports 0-to-fetch, so no live refetch exercised it.
- [ ] **Per-patch sea level.** danube_delta renders 64% ocean because delta land sits at 0-2m
      under a global 0.5m SEA_LEVEL. Any low-lying patch has this. Needs a per-patch offset.
- [ ] **Colour-match scenes at paste time** in `fetch_s2.py`. CONFIRMED SYSTEMIC: 4 of 4
      multi-scene patches are visibly patchworked (`guri_dam` worst â€” two seasons either side of a
      hard vertical seam, then `danube_delta`, `mongolia_steppe`, `dolomites`). Only single-scene
      patches are clean. Normalise exposure per scene against the overlap before pasting.
- [ ] **Reject building sites on cliffs.** `--align` says 8,235 of 119,703 sit on ground steeper
      than their undercroft covers, worst a 1,195 m drop. Add a slope limit at placement.
- [ ] **Regression sweep script.** Run `--align`, `--selftest`, `--texprobe`, diff against the last
      known-good, report only what changed. This session's worst bugs were silent successes.
- [ ] **Fix marker displacement** in the census â€” it takes the worst marker, so any patch with
      route-spanning markers scores badly by design. Use the camera anchor.

## Vehicles — the 40+ programme

Framing, because this only works one way. **40 vehicles is not 40 models.** It is a small set of
locomotion models, each parameterised, with generated or kitbashed meshes over the top. Done as
bespoke assets it is forty art tasks and it never ships; done as ~7 movement classes x parameters
it is a fortnight and the count falls out for free. Same argument as the tree species: the project
already generates its houses, hedges, palms and textures.

Prerequisite for everything below.

- [ ] **Locomotion abstraction.** `_drive_tick` is one hardcoded wheeled model: fixed accel, fixed
      grip, a heading integrated on the ring surface. Pull it into a `Locomotion` interface with
      one implementation per class, and a `VehicleDef` resource carrying mass, power, grip,
      turn rate, ride height, buoyancy, lift, and which locomotion drives it. Every item below is
      then a data row plus a mesh, not new movement code.
- [ ] **Vehicle definition table + `[L]` cycling through all of them**, with the census-style
      discipline: each entry states what it is FOR, not just what it is.

### Ground
- [ ] **Wheeled variants** — the boreen runabout we have, a fast road car, a heavy 6x6, a bike, a
      tractor, an articulated hauler. Differ by grip, mass, ride height, and how badly they lose off
      the tarmac (the `_road_cells` test already exists).
- [ ] **Tracked** — slow, unbothered by slope, ignores the road/offroad distinction that everything
      else obeys. The `--align` slope data says where this actually matters.
- [ ] **Hover / ground-effect** — ignores ground roughness, hates gradients, crosses water. The one
      class that makes the coastal patches drivable.

### Mounts and legged
- [ ] **Legged locomotion**, shared by mounts and mechs: gait over terrain, step height, can climb
      what wheels cannot. This is the one genuinely new movement model.
- [ ] **Horses** — fast, tires, spooks. Creatures already exist (`[K]` deer, `[J]` wolves) so herd
      behaviour and the mount are closer than they look.
- [ ] **Elephants** — slow, unstoppable, flattens hedgerows and small trees. A reason for the
      hedge/tree systems to be destructible.
- [ ] **Mechs** — bipedal and quadrupedal, scale from 3m to 15m. Legged locomotion with a different
      mass and step height.
- [ ] **Powered suits** — the player IS the vehicle. Jump height, sprint, hard landings. Blurs into
      the on-foot mode rather than being a separate thing to get into.

### Water
- [ ] **Boats** — the ocean is a flat clamp at `SEA_LEVEL` with no surface simulation, so this needs
      a water plane with motion before a boat means anything. Coastal patches are 64-89% sea and
      currently unreachable: palawan is 5% drivable, cape 8%, lofoten 10%.
- [ ] **Amphibious + submersible** — the sea floor is real heightfield data below the clamp, so
      there is already somewhere to go down to.

### Air
- [ ] **Rotary and fixed-wing** — FLY mode exists as a noclip camera; this needs actual flight with
      stall, lift and ground effect. The atmosphere-exit work already models thinning air.
- [ ] **Ring-specific flight.** Lift falls off as the atmosphere thins with altitude, and "up" is
      toward the axis everywhere — a long enough climb crosses to the far side. Worth doing properly
      because no other setting has this.

### Orbital and beyond
- [ ] **Leaving the atmosphere.** Already have the visual transition at 14-48km. Needs the flight
      model to hand over to ballistic, and reaction control instead of aerodynamics.
- [ ] **Ring-relative orbital mechanics.** You cannot orbit a ringworld the way you orbit a planet —
      the mass distribution is wrong and the ring is spinning under you at ~2.1 km/s. Match the
      spin and you hover over one spot; do not and the ring moves beneath you. That is a genuinely
      novel traversal mechanic and probably the most interesting item on this list.
- [ ] **Docking / boarding** at axis structures, which `docs/terrain/substrate.md` already places
      for the leave-ending.

### Cross-cutting
- [ ] **Wear, fuel and damage** — the reason to change vehicle rather than keep the best one.
- [ ] **Where vehicles COME from.** Found, salvaged, stolen, traded. Ties into the draws work:
      a vehicle two valleys away is a reason to go there.
- [ ] **Test harness for all of them** — extend `--shots` to spawn each vehicle, drive a fixed
      course over road / offroad / slope / water, and report speed, tris and fps per vehicle so the
      set can be compared rather than eyeballed one at a time.

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



