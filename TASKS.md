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
- [x] **Per-patch sea level.** danube_delta renders 64% ocean because delta land sits at 0-2m
      under a global 0.5m SEA_LEVEL. Any low-lying patch has this. Needs a per-patch offset.
      Done via the existing `patch_offset[]` path (already applied before the sea clamp in both
      shader and CPU across all three tiers). New optional `sea_pct` field on a patch: at load the
      offset is derived from that patch's own height distribution so the DEM sea fraction matches
      the imagery. danube_delta set to 25% (census: 63.8% sea at 0.5m; human read ~25% water).
      Self-calibrating, so it generalises to any low-lying splice. NOT run-verified: Godot binary
      is out-of-repo/gated and python is gated in this sandbox, so no `--shots` and no offset
      recompute exercised. Shoot danube_delta to confirm the reed bed now reads as land.
- [x] **Colour-match scenes at paste time** in `fetch_s2.py`. CONFIRMED SYSTEMIC: 4 of 4
      multi-scene patches are visibly patchworked (`guri_dam` worst â€” two seasons either side of a
      hard vertical seam, then `danube_delta`, `mongolia_steppe`, `dolomites`). Only single-scene
      patches are clean. Normalise exposure per scene against the overlap before pasting.
      Done via `_match_exposure`: where an incoming scene's clean pixels land on ground an earlier
      scene already painted clean, a per-channel mean/std map is fit over that overlap and applied
      to the whole block before pasting, so the new scene matches its neighbour. First scene in a
      region is the anchor (no overlap); contrast gain clamped [0.5,2.0]; overlaps below 5000 px are
      left untouched. NOT run-verified: python is gated in this sandbox and regenerating a preview
      means re-running fetch_s2 (a refetch, which the rules forbid). Shoot/re-preview guri_dam to
      confirm the vertical season seam is gone.
- [x] **Reject building sites on cliffs.** `--align` said 8,235 of 119,703 sat on ground steeper
      than their undercroft covers, worst a 1,195 m drop. `_load_bldg_file` now runs the ALIGN float
      test (max corner drop vs building height) per building before placing it, and skips the ones
      that fail; the per-patch load line now reports the cliff count alongside the ring-width count.
      Same `_terrain_h` the align check uses, and `_dem_hf`/`_patch_rects` are both loaded first, so
      the sample is valid at load. NOT run-verified: the Godot binary is out-of-repo/gated here, so
      no `--align` re-run — that count is the confirmation, and it should now drop toward 0.
- [x] **Regression sweep script.** `scripts/regression-sweep.ps1` runs each of `--align`,
      `--selftest`, `--texprobe`, pulls the deterministic signal lines from the run's godot.log
      (per-patch ALIGN/SELFTEST/TEXPROBE lines, the two ALIGN summary counts, the streamed-OK
      count, plus the one-time startup census of trees/buildings/centrelines/splice list), strips
      volatile timings (`(1082 ms)`, `(2.5s)`) so a slow run isn't a false positive, and diffs each
      against a blessed baseline in `logs/regression/baseline/`, printing ONLY changed lines.
      Value moved = old->new (numbers masked to match line shape); patch added/removed = a whole
      line. `-Accept` blesses the current output as the new known-good; exit 1 on any change so the
      queue task can gate on it. align/selftest quit themselves (WaitForExit); texprobe never does,
      so it waits for the TEXPROBE line then kills the process. NOT run-verified: the Godot binary
      is out-of-repo/gated here and launching even the .ps1 needs interactive approval, so no live
      sweep exercised it. Parse-reviewed by hand for PS5.1 (no ternary/`&&`, collection-unroll
      guarded with `@()`). First run on the laptop seeds the baseline; bless once with `-Accept`.
- [x] **Fix marker displacement** in the census â€” it takes the worst marker, so any patch with
      route-spanning markers scores badly by design. Use the camera anchor.

## Vehicles — the 40+ programme

Framing, because this only works one way. **40 vehicles is not 40 models.** It is a small set of
locomotion models, each parameterised, with generated or kitbashed meshes over the top. Done as
bespoke assets it is forty art tasks and it never ships; done as ~7 movement classes x parameters
it is a fortnight and the count falls out for free. Same argument as the tree species: the project
already generates its houses, hedges, palms and textures.

Prerequisite for everything below.

- [x] **Proving ground** (`-- --proving [vehicle,...]`). Scripted identical course per vehicle --
      accel, brake, full-lock circle, offroad, climb -- reporting top speed, distance, turning
      radius, jolt and grade. Mechanics before looks: handling cannot be judged from a screenshot.
- [x] **INVESTIGATE: offroad is FASTER than on-road in the proving numbers.** box tops 9.8 m/s in
      the accel phase (on a road) and 17.5 m/s in the rough phase (deliberately 60m off it). That is
      backwards. CONFIRMED — but not the wrapping guess. `_road_cells` is built from the SAME
      `_roadlines` pts the phase reads for its start, so the start cell IS marked and the car DOES
      begin on tarmac. The handling physics is right: on-road drag 0.35 -> ~22 m/s (clamp), off-road
      0.90 -> 9*(1-0.9dt)/0.9 = 9.86, matching the measured 9.8. Two separate HARNESS faults:
      (1) accel drove `heading = 0` straight off the 8m ribbon within a car length, so `_offroad`
      ramped to 1 and it recorded the OFF-road terminal; (2) `_offroad` was never reset between
      phases, so "rough" inherited the on-road value from the preceding circle and ramped down over
      1/3s — the 17.5 was a transition OVERSHOOT, not steady state. Fixed in the harness only
      (handling model untouched, per the gate): on-road phases now start pointed along the road
      tangent, and every phase seeds `_offroad` from the cell it starts on. NOT run-verified: Godot
      binary is out-of-repo/gated here, so no live `--proving`.
- [x] **Suspension + calibrated bump strip.** Per-wheel spring, body pitch/roll from the contact
      plane, and a 700m test surface (washboard, swell, kerbs, ramp-and-drop, potholes) so rough
      ground is repeatable rather than whatever the patch happens to have.
- [x] **Make the bump strip visible.** It is CPU-side only, so the shader does not draw it — the
      exact drawn-vs-driven mismatch this project keeps hitting. Mirror `_proving_surface` into
      cdlod_ring.gdshader, or accept it and gate it behind a loud HUD warning.
      Mirrored, not HUD-gated (the title asks for VISIBLE, and the HUD warning the old comment
      claimed existed was never actually written). `proving_surface()` in cdlod_ring.gdshader is a
      line-for-line copy of `_proving_surface`, folded into `sample_h` AFTER the sea clamp — so h and
      its four normal-neighbours all carry the bumps, and geometry + shading match the physics ground
      (`_terrain_h` clamps, then adds the strip, exactly the same order). Added unconditionally, like
      the physics, so it's parity in DRIVE too, not just --proving. Constants are now one source split
      CPU/GPU; both comments say MUST stay in sync. Caveat: washboard/swell/kerbs/ramp (0–560m) are
      exact; the 560m+ potholes are a large-argument sin() hash, so a cell or two may differ float32
      vs float64 — cosmetic, off-course. NOT run-verified: the Godot binary is out-of-repo/gated here,
      so no `--shots`; and `--shots <patch>` wouldn't frame arc 900k anyway. Drive to PROVE_STRIP_ARC
      to eyeball the strip once on the laptop.
- [x] **Locomotion abstraction.** `_drive_tick` is one hardcoded wheeled model: fixed accel, fixed
      grip, a heading integrated on the ring surface. Pull it into a `Locomotion` interface with
      one implementation per class, and a `VehicleDef` resource carrying mass, power, grip,
      turn rate, ride height, buoyancy, lift, and which locomotion drives it. Every item below is
      then a data row plus a mesh, not new movement code.
- [ ] **HARNESS STILL LYING in two places, found while proving the abstraction.** (a) The box's
      accel phase reads 9.8 m/s, which is exactly its OFF-road terminal (9.0 power / 0.9 combined
      drag) -- so it is still leaving the 8m ribbon within a car length despite the earlier fix, and
      the on-road figure has never actually been measured. The warthog's 20.8 sits between its
      on-road and off-road terminals, same cause. (b) The box's bump-strip jolt fell from 1.50m to
      0.18m across this change with nothing touching the strip, so the phase is probably no longer
      starting on it. Fix the harness before trusting any handling number.
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

## Weapons, HUD and on-foot — the tech-tree programme

Same framing as the vehicles, for the same reason. **A tech tree from a sharpened stick to a
backpack MLRS is not 40 weapon models.** It is ~7 mechanics classes, each parameterised, with
placeholder shapes over the top. Mechanics first: a weapon that looks right and feels wrong is
worse than a grey box that feels right, and feel is measurable.

The carbine already exists as a model with FP arms (`.decisions/` and `assets/`), so this is about
behaviour, not art.

### Test harness first — same lesson as the proving ground
- [ ] **Firing range** (`-- --range [weapon,...]`). Targets at 5/10/25/50/100/200/400m, scripted
      fire, reporting: time-to-first-hit, group size at each range, sustained rate, recoil recovery
      time, projectile drop, and time-to-kill against a standard target. Identical course per weapon
      so the table compares, exactly like `--proving`. **Build this before any weapon.**
- [ ] **Ballistics on a ring.** Spin gravity is not gravity: a projectile in flight is in free fall
      while the ring rotates under it, so long shots drift sideways and the drop is not symmetric.
      At 2.1 km/s surface speed this is a real, measurable, novel effect. Worth getting right rather
      than approximating with a gravity constant -- it is the kind of thing this setting can own.

### Mechanics classes (each is a parameter set, not a weapon)
- [ ] **Melee** — reach, wind-up, commitment. Spear, blade, club, improvised.
- [ ] **Thrown** — arc, weight, fuse. Rock, spear, grenade, molotov, sticky charge.
- [ ] **Tensioned** — draw time, hold penalty, drop. Sling, bow, crossbow, speargun.
- [ ] **Chemical projectile** — the big family. Rate, recoil, magazine, reload, heat, spread growth.
      Musket, bolt-action, carbine (exists), SMG, LMG, autocannon.
- [ ] **Directed energy** — no drop, no lead, but heat and charge. Should feel unlike the others,
      not just be a rifle with a beam.
- [ ] **Guided / indirect** — mortar, rocket, the backpack MLRS. Fire-and-forget vs steered, minimum
      arming range, and a real reason not to carry it everywhere.
- [ ] **Deployable** — mines, sensors, a tripod turret. Placed, then persistent.

### The tree itself
- [ ] **Progression rules.** The player ARRIVES from a spacefaring civilisation and gets stripped of
      it (`the-toll` in docs/vignettes.md). The tree is therefore about RECOVERING capability, not
      inventing it -- a spear is what you use when they took your rifle. That inverts the usual
      shape and is worth exploiting.
- [ ] **Ammunition and scarcity** as the real balance lever, not damage numbers.
- [ ] **Where weapons come from** — found, salvaged, traded, taken. Same hook as the vehicles;
      ties into draws.

### On foot
- [ ] **FPS controls proper.** WALK mode is a camera with a speed. Needs: acceleration, crouch,
      sprint with a cost, jump, fall damage, stance affecting spread, and the ring frame handled
      correctly (up points at the axis, which the camera already does and the movement does not).
- [ ] **HUD.** Currently a debug wall of text. Needs a real one -- and per
      `.decisions/design-laws.md#diegetic-tools-not-hud`, **information must be a physical ownable
      tool, not free overlay**. Ammo count comes from looking at the weapon; bearing comes from a
      compass you found. That law makes this design work, not just layout work.
- [ ] **Damage model** — locational, on the player and on NPCs, shared with the creature system that
      already exists.

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



