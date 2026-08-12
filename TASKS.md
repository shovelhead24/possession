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
- [x] **HARNESS STILL LYING in two places, found while proving the abstraction.** (a) The box's
      accel phase reads 9.8 m/s, which is exactly its OFF-road terminal (9.0 power / 0.9 combined
      drag) -- so it is still leaving the 8m ribbon within a car length despite the earlier fix, and
      the on-road figure has never actually been measured. The warthog's 20.8 sits between its
      on-road and off-road terminals, same cause. (b) The box's bump-strip jolt fell from 1.50m to
      0.18m across this change with nothing touching the strip, so the phase is probably no longer
      starting on it. Fix the harness before trusting any handling number.
      Both were harness faults, not physics. (a) `_offroad` was derived from live position every
      frame, so a straight tangent leaving the curving ribbon settled every on-road phase at the
      off-road terminal; the earlier per-phase seed was overwritten each tick. Now the proving course
      PINS `_offroad` per phase (`_prove_offroad`): 0 for accel/brake/circle/bumps, 1 for rough/climb,
      and `_drive_tick` honours the pin instead of the position test while proving. accel/brake/circle
      now read the on-road terminal (box ~22, clamped by `top`); rough/climb the off-road one. (b) The
      root cause was the jolt metric sampling `_terrain_h` ALONE — the calibrated strip is added via
      `_proving_surface`, so it never showed in the jolt column at all. Both `h_start` and the loop `h`
      now add `_proving_surface`, and the strip phase is pinned on-road so it carries speed to cross
      every obstacle (ramp/drop, potholes) in 40s rather than stalling in the washboard at ~10 m/s.
      NOT run-verified: the Godot binary is out-of-repo/gated here, so no live `--proving`.
- [x] **Vehicle definition table + `[L]` cycling through all of them**, with the census-style
      discipline: each entry states what it is FOR, not just what it is.
      The `VEHICLE_ROWS` table is now the ROSTER, not just a params lookup: `_build_vehicles` iterates
      it and builds one cyclable entry per row, so `[L]` (and `--proving`, `--shots`) cover every
      vehicle that exists as DATA, not only the ones with art. A row with a bespoke mesh (the warthog
      GLTF) gets it; every other row — and the warthog on a machine without the gitignored pack — gets
      a placeholder box sized and tinted from its def (`length`/`tint` added to `VehicleDef`), still
      fully drivable on its own handling. Before this, a warthog-less machine dropped to `_vehicles=[box]`
      and `[L]` did nothing; now the whole roster cycles regardless of art. Census discipline: each row
      carries a `purpose` string stating what it is FOR, shown in the DRIVE HUD as you cycle. Roster
      stays box + warthog — filling it (fast car, 6x6, bike, tractor, hauler...) is the next items, each
      now just a data row. NOT run-verified: the Godot binary is out-of-repo/gated here, so no `--shots`
      to eyeball the two placeholders cycling. Drive and press [L] on the laptop to confirm.

### Ground
- [x] **Wheeled variants** — the boreen runabout we have, a fast road car, a heavy 6x6, a bike, a
      tractor, an articulated hauler. Differ by grip, mass, ride height, and how badly they lose off
      the tarmac (the `_road_cells` test already exists).
      Five new `VEHICLE_ROWS` (sportscar/sixby/bike/tractor/hauler), pure data on the existing
      `_loco_wheeled` model — no movement code, exactly the abstraction's payoff. They spread the two
      axes the class actually has: on-road speed (top 42 sportscar → 12 tractor) vs how hard they wash
      out once the carriageway ends (offroad_drag 0.95 sportscar/0.85 hauler → 0.18 tractor/0.22
      sixby, plus matching offroad_turn), with ride height 0.26→0.75 and mass 220→14000 spread across
      them. Each carries a census `purpose` (shown in the DRIVE HUD) arguing what it is FOR, not just
      its numbers. Mesh-less rows get the sized+tinted placeholder box already built by `_build_vehicles`;
      distinct tints so `[L]` reads as a change. Roster consumers (`[L]`, `--proving`, `--shots`, HUD)
      all iterate `_vehicles`, so the six wheeled + warthog appear with no other edits. NOT run-verified:
      the Godot binary is out-of-repo/gated here, so no `--proving`/`--shots`. Run `-- --proving` on the
      laptop to confirm the table differentiates (sportscar fastest on-road, tractor/sixby best off it).
- [x] **Tracked** — slow, unbothered by slope, ignores the road/offroad distinction that everything
      else obeys. The `--align` slope data says where this actually matters.
      First class that is NOT `_loco_wheeled`: a sibling `_loco_tracked` + a `"tracked"` dispatch case,
      exactly the abstraction's shape (new movement code for a new class; the wheeled variants were
      pure data). Two departures ARE the class: (1) ONE drag term, no `offroad_drag` — it never reads
      `_offroad`, so tarmac and field damp the same (the road/offroad split it ignores); (2) skid-steer,
      full turn authority at any speed (no `grip_speed` ramp), so it pivots on the spot and keeps
      steering while crawling. On the climb phase the harness pins `_offroad=1`; the wheeled model
      washes out there, tracked simply doesn't consult it and keeps its speed uphill — which is where
      "unbothered by slope" becomes measurable in `--proving` (grade column). Slow is data (`top` 9.0);
      `offroad_drag`/`offroad_turn`/`grip_speed` set to 0 to SAY the model doesn't read them. Wheeled
      physics untouched (the no-change gate holds); one new row `crawler` (placeholder box, sized+tinted
      per def like the rest), so `[L]`/`--proving`/`--shots`/HUD pick it up with no other edits. NOT
      run-verified: the Godot binary is out-of-repo/gated here, so no `--proving`/`--shots`. Run
      `-- --proving` on the laptop to confirm crawler holds speed on `rough`/`climb` where the wheeled
      rows shed it. Placeholder box still shows steering front wheels (a skid-steer tell) — geometry is
      a mesh job, same caveat as sixby's four-instead-of-six.
- [x] **Hover / ground-effect** — ignores ground roughness, hates gradients, crosses water. The one
      class that makes the coastal patches drivable.
      The scaffolding was already in the tree (dispatch case, body-leveling that skips the bump strip,
      the `skiff` row, `lift`/`buoyancy` on VehicleDef) but `_loco_hover` was CALLED and never DEFINED
      — it would have crashed the instant you cycled to the skiff. Wrote the function, the third
      movement class after wheeled/tracked. Its three traits, each earning the class: (1) ONE drag
      term, no road/offroad split, so sea/flat/tarmac glide alike; (2) full turn authority at any
      speed like tracked; (3) it HATES gradients — central-differences `_terrain_h`, bleeds speed on
      the along-track slope (cannot climb, `HOVER_SLOPE_PULL`) and slides bodily down cross-slopes
      (`HOVER_SLOPE_SLIDE`), the exact inverse of the crawler. "Crosses water" falls out for free:
      `_terrain_h` clamps to SEA_LEVEL so `_car_pos` already floats the body ON the sea, and a flat
      sea has zero gradient so it glides — owns the coast, wallows in the mountains. Wheeled/tracked
      physics untouched (no-change gate holds). NOT run-verified: the Godot binary is out-of-repo/gated
      here, so no `--proving` — and handling can't be judged from a screenshot anyway (the whole reason
      the proving ground exists). Run `-- --proving` on the laptop: the skiff should top the accel/
      circle phases and bog on `climb` where the crawler holds speed.

### Mounts and legged
- [x] **Legged locomotion**, shared by mounts and mechs: gait over terrain, step height, can climb
      what wheels cannot. This is the one genuinely new movement model.
      The FOURTH movement class, `_loco_legged` + a `"legged"` dispatch case — genuinely new code, not a
      data row (the wheeled variants were data; tracked/hover were siblings). Three traits, each earning
      it: (1) it CLIMBS — like tracked it reads ONE drag term and never consults `_offroad`, so on the
      climb phase (pinned `_offroad=1`) it holds speed uphill where every wheeled row washes out — "climbs
      what wheels cannot" made measurable in the grade column. (2) full turn authority at any speed
      (pivots in place, no `grip_speed` ramp). (3) GAIT not roll: a new `_gait_phase` accumulates with
      DISTANCE, and `_drive_tick` poses the body's bob (`LEGGED_BOB`) and fore-aft rock (`LEGGED_ROCK`)
      from it — a walker, not a rolling wheel. STEP HEIGHT is the new `step_height` VehicleDef field: the
      body feels only the part of the calibrated strip that exceeds it (`strip - clamp(strip, ±step)`), so
      feet stride over a washboard and climb onto a kerb. New fields `step_height`/`gait` on VehicleDef
      (0/2.4 default, unread by other classes). One `strider` row as the class exemplar — the mount/mech/
      suit rows are the following items, each now pure data on this model. `[L]`/`--proving`/`--shots`/HUD
      pick it up via the generic `VEHICLE_ROWS` iteration, no other edits. Wheeled/tracked/hover physics
      untouched (no-change gate holds). Caveats: jolt measures the GROUND (`_terrain_h+_proving_surface`),
      so the step-smoothing is a body/visual effect that won't show in that column; the placeholder box
      still shows spinning wheels (geometry is a mesh job, same as sixby's four-not-six). NOT run-verified:
      the Godot binary is out-of-repo/gated here, so no `--proving` — and handling can't be judged from a
      screenshot anyway (the reason the proving ground exists). Run `-- --proving` on the laptop to confirm
      the strider holds speed on `climb` where the wheeled rows shed it.
- [x] **Horses** — fast, tires, spooks. Creatures already exist (`[K]` deer, `[J]` wolves) so herd
      behaviour and the mount are closer than they look.
      The first MOUNT: pure data on `_loco_legged` (one `horse` row) EXCEPT for the two traits that make
      it a horse and not a strider — and both are switched on by DATA, so the strider/mech rows stay
      untouched (the no-change gate holds). New `VehicleDef` fields `stamina`/`winded_top`/`spooks`, all
      default off (0/false, unread by every other row and class, like buoyancy/lift). TIRES: galloping
      above the trot line (`top*0.45`) spends `_stamina` at 1/`stamina`/s so it blows after ~14s of hard
      running; walking restores it slower than it drains; effective top lerps down to `winded_top` (6 m/s)
      as it empties, so it loses its legs smoothly, not off a cliff. SPOOKS: reuses the EXISTING
      `_threat_active` hook (the `[J]` wolf pack in APPROACH already sets it) — while spooked the horse
      throws in its own throttle (bolts) and shies its heading, and bolting drains stamina, so flee and
      tire interact for free. FAST is data (`top` 18, out-sprints every wheeled row off-road). `_stamina`/
      `_spooked` reset per-vehicle-cycle and per-proving-phase so the table compares; DRIVE HUD shows
      `stamina %` / `WINDED` / `SPOOKED`. NOT run-verified: the Godot binary is out-of-repo/gated here, so
      no `--proving` — and tiring/spooking can't be judged from a screenshot anyway (the reason the proving
      ground exists). Run `-- --proving` on the laptop: the horse should top the sprint phases then wind
      down; press `[J]` while riding to see it bolt.
- [x] **Elephants** — slow, unstoppable, flattens hedgerows and small trees. A reason for the
      hedge/tree systems to be destructible.
      One `elephant` row, pure data on `_loco_legged` (like strider/horse) EXCEPT for one new switch,
      `trample` on VehicleDef — the ONLY thing genuinely its own, and it is what makes the hedge/tree
      systems destructible at all. Slow/unstoppable is the handling table (mass 5200, top 7.5, one drag
      term, tireless `stamina 0`, fearless `spooks false` — the horse's opposite). `_do_trample` runs
      only when `d.trample > 0` (so every other row/class is a single float compare and unchanged): it
      flattens what the body walks over in each system's OWN terms — trees by marking the index in
      `_tree_down`, which `_update_tree_lod` already rebuilds its MultiMesh buckets from every few metres,
      so it just skips them (no parallel geometry); hedges by recording the crush POINT in `_hedge_down`
      and rebuilding the ribbon with that span gapped (`_hedge_trampled`). Only SMALL trees go
      (`TRAMPLE_TREE_MAX_H` 9.6m — the fir pack has no canopy giants, so height is the proxy for "too big
      to push over"; ~the tallest quarter stand). `_tree_down` clears on rescatter (indices point at a
      different forest 700m on); `_hedge_down` is capped so old crushes regrow. Scan throttled to ~one
      crush-width of travel; ribbon rebuilt only when a new point lands near a road. Roster consumers
      (`[L]`/`--proving`/`--shots`/HUD) pick it up via the generic `VEHICLE_ROWS` iteration, no other edits.
      NOT run-verified: the Godot binary is out-of-repo/gated here (C:\Godot denied), so no live drive —
      and `--shots <patch>` frames a patch, not an elephant mid-trample. Ride the elephant ([L] to it) into
      a roadside hedge and through woodland on the laptop to confirm the ribbon gaps and small firs vanish
      in its wake while the big ones stand.
- [x] **Mechs** — bipedal and quadrupedal, scale from 3m to 15m. Legged locomotion with a different
      mass and step height.
      Two rows, pure data on `_loco_legged` (like strider/horse/elephant) — no movement code, the
      abstraction's payoff. The item names exactly two axes and both resolve to fields the class already
      reads: form and scale become mass + step_height. `mech_biped` is the 3m agile end (mass 3600,
      step 1.5, top 13, turn 1.5 — climbs onto walls a strider only steps over); `mech_quad` the 15m
      walking-fortress end (mass 42000 — heaviest in the roster past the hauler, step 3.2, top 6, turn
      0.6, strides over walls/buildings). Machines, so tireless/fearless: stamina 0, spooks false,
      trample 0 (the item asks only for mass + step height, so the elephant keeps destructibility to
      itself). offroad_*/grip_speed/susp_* left 0 to say the model reads none of them. Roster consumers
      (`[L]`/`--proving`/`--shots`/HUD) iterate `VEHICLE_ROWS`, so both appear with no other edits.
      Placeholder box still shows wheels — a mesh job, same caveat as strider/sixby. NOT run-verified:
      the Godot binary is out-of-repo/gated here, so no `--proving`, and handling can't be judged from a
      screenshot anyway. Run `-- --proving` on the laptop: the quad should hold speed uphill on `climb`
      like the strider while topping out slowest, the biped sit between strider and quad.
- [x] **Powered suits** — the player IS the vehicle. Jump height, sprint, hard landings. Blurs into
      the on-foot mode rather than being a separate thing to get into.
      The LAST legged row, `suit`: pure data on `_loco_legged` like the strider/mech EXCEPT for the two
      traits this item names that nothing else in the roster has — it JUMPS and it SPRINTS — and both are
      switched on by DATA (`jump`/`sprint` on VehicleDef, default 0/1, unread by every other row and class,
      so the no-change gate holds). JUMP is the one piece of genuinely new movement (nothing else leaves the
      ground under power): a ballistic hop along ring-up in `_drive_tick`, launched at `sqrt(2 g jump)` so the
      peak lands on `jump` metres, plain gravity (`SUIT_GRAVITY`; the ring-frame ballistics subtlety is the
      WEAPONS programme's job, not a 3m hop), returning as a HARD LANDING — a body crouch (`_land_dip`) plus a
      bite out of forward speed, both scaled by impact speed. SPRINT lifts the effective top by `sprint` while
      held (two lines in `_loco_legged`). "Blurs into on-foot" is literal: the controls ARE the WALK/FLY keys
      — Shift sprints (WALK's run), Space jumps (FLY's rise) — and the HUD shows them + AIRBORNE/SPRINT. Jump
      state resets on `[L]` cycle so you never strand the suit mid-air. NOT run-verified: the Godot binary is
      out-of-repo/gated here (C:\Godot denied), so no live drive — and jump/sprint/landing can't be judged from
      a screenshot anyway (the reason the proving ground exists), and like the horse's spook they are
      player-triggered so `--proving` doesn't exercise them. Drive to the suit ([L]) on the laptop and press
      Space/Shift to confirm it hops onto ledges and bursts, and lands hard off the ramp on the bump strip.

### Water
- [x] **Boats** — the ocean is a flat clamp at `SEA_LEVEL` with no surface simulation, so this needs
      a water plane with motion before a boat means anything. Coastal patches are 64-89% sea and
      currently unreachable: palawan is 5% drivable, cape 8%, lofoten 10%.
      Two halves, both done. (1) THE SWELL, because a boat means nothing on a flat clamp: rather than
      a second water mesh (z-fight, extra draw), the sea clamp becomes `sea_level + wave_h()` — the
      ocean IS the terrain surface, one mesh, so the swell gets lit normals and glint for free through
      `sample_h`'s gradient neighbours. Three directional sines (~1m crest-to-trough), vertical only —
      no Gerstner pinch, because every metre of horizontal displacement is a metre the CPU twin must
      reproduce and this project has been bitten by CPU/GPU divergence enough. `wave_h`/`wave_fade` in
      cdlod_ring.gdshader and `_wave_h`/`_wave_fade` in ring_vibes.gd are line-for-line twins; faded
      out in the shallows (keeps coastlines from flooding) and beyond 1200m of the camera (a 68m wave
      sampled on a distant node's hundreds-of-metres gradient step just aliases). New `_surface_h`
      (live water) split from `_terrain_h` (STATIC placement authority — trees/buildings/road cells/
      align must not bob). (2) THE FIFTH movement class `_loco_boat` + two rows: `launch` (planing —
      climbs its bow wave over `plane_speed`, sheds drag, skates through turns via `drift`, shallow
      draft) and `barge` (displacement — held to hull speed, tracks straight, deep draft grounds far
      off the beach). Four traits are the class: needs water (grounds and loses the rudder when the
      keel touches, `_sea_depth < draft`), rudder-not-steering (turn authority ∝ steerage way, inverse
      of tracked/hover pivot), it DRIFTS (`_boat_vel` vector chases the heading, `drift=0` reproduces
      the land classes exactly), planing-vs-displacement is a data row not a function. `_boat_trim`
      lies the hull on the wave slope off `_surface_h`. New VehicleDef fields `draft`/`plane_speed`/
      `drift` all default to no-op so every other row is unchanged (no-change gate holds). `_boat_vel`
      resets on `[L]` cycle and per proving phase like stamina/jump. NOT fully run-verified: the Godot
      binary is out-of-repo/gated for the unattended runs. It has since been run: SIX shot runs across
      palawan, halong_bay, mizen_head and slea_head, and the GPU displacement STILL has not been seen.
      The CPU twin is verified numerically (-2.07m/-3.36m/-4.04m across 40m at 6x amplitude), so the
      side a hull floats on is correct. See logs/shots/JOURNAL.md 2026-08-10 for the four defects those
      runs turned up and fixed on the way — no bathymetry, the phantom ocean, per-arc daylight, and the
      fps column being fiction. The three items below are the unfinished half of this.
- [x] **The near sea is not drawn by the terrain shader.** It WAS drawn by it. The real fault was
      `_select_lod` testing `_cam.position` (BENT world space) against `ox`/`oz` (absolute ring
      coordinates). `_ring_pos` maps arc to r*sin(arc/R), so at arc -1,485,690 the camera's world x is
      about -14,600 — the two only agree near arc 0. Everywhere else the distance came out enormous,
      no node ever subdivided, and the entire ring away from home rendered at 65km ROOT nodes, ~2km
      between vertices. A 68m swell sampled every 2km is far below Nyquist, which is why the sea was
      flat however correct the wave function was. Same coordinate-space fault as the shader's cam_pos
      morph term, which is fixed in the same change (both now take `_cam_ring`, the camera in ring
      space). Verified: slea_head's sea framing went 110,260 -> 169,624 triangles and mizen_head now
      shows actual wave crests rolling onto the shore. This was never a water bug — it degraded LOD
      on every patch except home, and is very likely the tail of the "buildings sank away from home"
      family.
- [x] **The colour-vs-geometry wave fade made slea_head worse.** It didn't — the LOD fault above
      did, and the fade split was innocent. With subdivision working, slea_head reads as teal water
      with legible crest/trough banding. Keeping the split: geometry must still stop at ~1.2km (the
      gradient neighbours are node_size/grid apart out there) while colour is per-fragment and
      shouldn't. Left here as the record that the suspected cause was wrong.
- [x] **Phantom ocean outside patch data.** Decided: the void is NOT sea (recorded as
      .decisions/terrain.md#void-is-not-sea). Off every patch the sampler floors to a procedural
      value whose low half sits below SEA_LEVEL — identical by value to real coastal water, but
      nothing backs it. The discriminator is DATA, not a value or a distance-to-shore heuristic:
      new `_has_terrain_data` (home DEM in bounds OR a patch owns the point) mirrors `_terrain_h_raw`'s
      real-data branches, and `_sea_depth` now returns dry (-1) for any point that fails it, BEFORE
      the shore probe. That kills the "12 m of ocean by walking off the data" that broke the framing
      search and would float a boat on empty space; the framing search's existing `_land_in_sight`
      guard now has a void-proof depth test under it too. Scope: fixed on the authoritative CPU test
      side (`_sea_depth` → framing + boat grounding). The far band shader draws NO water, so "ocean to
      the horizon" is bounded to the CDLOD bubble's inter-patch gaps; aligning the GPU
      `sample_h`/`is_water` clamp and `_terrain_h`'s placement clamp to the same predicate is left for
      a shot-verified pass — the Godot binary is out-of-repo/gated here, so a render change can't be
      eyeballed (and this fix is logic, verifiable by reading, not a picture). Retire the whole
      void/synthetic-shelf distinction when a bathymetric source lands.
- [x] **Amphibious + submersible** — the precondition (GEBCO vs synthesise) is DECIDED: synthesise,
      consistent with everything else this project generates (recorded .decisions/terrain.md#synthetic-seabed).
      `_sea_depth` now builds a descendable floor from the ONE real datum it has, the coastline: the
      shore-distance probe keeps the shallow-near-beach trend UNCHANGED (so boat grounding is untouched),
      then past the shelf edge the floor keeps falling toward SEA_ABYSS (60m) with `_noise` laying banks
      and trenches (SEA_RELIEF ±9m) over it — varied ground, not a smooth bowl, faded in with offshore
      distance (off² for the abyss so the slope steepens). The SIXTH movement class `_loco_sub` +
      dispatch case is amphibious by construction (crawls ashore at SUB_LAND_FRAC of its water speed
      where a hull grounds — the inverse of `_loco_boat`, which loses way the moment it beaches) with
      full turn authority at any speed like tracked/hover. DEPTH is the first driven vertical axis: `_dive`
      is integrated in `_drive_tick` where the suit's jump lives, Shift descends / Space surfaces (the
      WALK-run/FLY-rise keys), gated on `dive_max` and floored SUB_KEEL above the synthesised seabed, and
      forced back to 0 with no water under it (surfaces onto land). Two rows split the pairing: `duck`
      (surface amphibian, dive_max 2.5) and `sub` (deep, dive_max 55). Body levels when submerged (no wave
      over it) / trims on the swell at the surface; chase cam drops with `_dive`; HUD reads DIVE/ASHORE/keys.
      New VehicleDef field `dive_max` defaults 0 (a data contract like draft/lift — every other row and
      class unchanged, no-change gate holds). Caveats: on land the crawl sits on terrain, not the calibrated
      bump strip (matters only on the proving-strip arc); the synthesised floor is not real bathymetry (no
      named trenches, no true shelf break) — a GEBCO source would refine it, not replace the approach. NOT
      run-verified: the Godot binary is out-of-repo/gated here, so no `--proving`/`--shots`, and diving is
      player-triggered (Shift/Space) so `--proving` wouldn't exercise it and a screenshot can't judge
      handling anyway. Cycle to `duck`/`sub` ([L]) on the laptop, drive off a beach and press Shift to
      confirm it floats off, descends the synthesised floor, and crawls out the far side.

### Air
- [x] **Rotary and fixed-wing** — FLY mode exists as a noclip camera; this needs actual flight with
      stall, lift and ground effect. The atmosphere-exit work already models thinning air.
      The SEVENTH movement class, `_loco_air` + an `"air"` dispatch case — genuinely new code (the first
      class to leave the surface and STAY off it; the suit only hops), with `_altitude`/`_vspeed` a new
      driven vertical axis alongside `_dive`/`_jump_h`, lifted along ring-up in the same `pos` offset the
      bump strip and dive already use (0 for every other class, so a no-op for them). Four traits ARE the
      class: (1) LIFT not drive — a fixed-wing's lift is airspeed², a rotor makes its own airflow from
      throttle so it HOVERS at zero speed, and that ONE difference is why rotary vs fixed-wing are two DATA
      rows, not two functions (`stall_speed` 0 = rotary); (2) STALL — below `stall_speed` the wing lets go
      (`AIR_STALL_LIFT`) and it drops, and a climb TRADES airspeed (`AIR_TRADE`), so pulling up too hard
      stalls you — the coupling that makes stall live; (3) GROUND EFFECT — a wingspan of extra lift at the
      deck, faded out with height, so it floats on take-off/landing (the item names it); (4) THINNING AIR
      — lift scales by `_air_density`, the SAME atmosphere-exit `smoothstep(SPACE_LO, SPACE_HI)` the sky
      thins by, so the ceiling is where the air runs out, not a clamp — the item's payoff ("the
      atmosphere-exit work already models thinning air"). Turn: rotor pivots freely (like tracked/hover),
      fixed-wing banks with airspeed-scaled authority (the boat's rudder rule). Two rows — `rotor` (hovers,
      climbs vertically, pivots) and `airplane` (fast/far, must hold airspeed, wide banked turn). New
      VehicleDef field `stall_speed` defaults 0 (a data contract like draft/dive_max; every other row/class
      unchanged — no-change gate holds). Roster consumers (`[L]`/`--proving`/`--shots`/HUD) iterate
      `VEHICLE_ROWS`, so both appear with no other edits; HUD reads ALT / STALL / climb keys. Placeholder
      box still shows wheels, and the body bank/pitch SIGNS are cosmetic and NOT eyeballed (same caveat as
      strider/sixby). NOT run-verified: the Godot binary is out-of-repo/gated here, so no `--proving` — and
      flight handling can't be judged from a screenshot anyway (the reason the proving ground exists). Cycle
      to `rotor`/`airplane` ([L]) on the laptop: the rotor should lift on the spot with Space, the airplane
      should need a run-up to unstick and stall (nose-drop) if you climb too steep and bleed airspeed.
- [x] **Ring-specific flight.** Lift falls off as the atmosphere thins with altitude, and "up" is
      toward the axis everywhere — a long enough climb crosses to the far side. Worth doing properly
      because no other setting has this.
      Two of the three parts already existed and were confirmed, not rebuilt: thinning-air lift is
      `_air_density` (`SPACE_LO..SPACE_HI`, the same smoothstep the sky thins by), and "up toward the
      axis" is the `_ring_up(base)` offset the flyer already rides. The MISSING ring-specific piece was
      gravity: `AIR_GRAVITY` was a flat 9.0 "plain down-pull" (its old comment deferred all ring-frame
      physics to the weapons programme). Now it is SPIN gravity — `g = AIR_GRAVITY*(1 - _altitude/R)`
      in `_loco_air` — so the pull weakens as you climb toward the axis (r = R−alt), hits zero at the
      axis (alt = R, weightless), and goes NEGATIVE past it, flipping the term so it pulls you on across
      to the FAR surface. That is "a long enough climb crosses to the far side", now true in the model
      rather than aspirational. `AIR_GRAVITY` is redocumented as the value at the surface. Scoped to
      `_loco_air` only (no other class reads air gravity, so the no-change gate holds); the sideways
      Coriolis drift of an UNPOWERED projectile stays the weapons programme's job — a wing under power
      doesn't feel it. Honest limit: within atmosphere lift dies at ~48km, far below the ~477km axis, so
      a wing physically can't reach the crossing — that handoff is the two orbital items below. NOT
      run-verified: the Godot binary is out-of-repo/gated here, so no live flight — and flight handling
      can't be judged from a screenshot anyway (the reason the proving ground exists), and the effect
      only bites near the axis, far past any shot. Fly the `rotor`/`airplane` ([L]) high on the laptop
      to feel climb get easier as gravity thins with the air.

### Orbital and beyond
- [x] **Leaving the atmosphere.** Already have the visual transition at 14-48km. Needs the flight
      model to hand over to ballistic, and reaction control instead of aerodynamics.
      Done as ONE CONTINUOUS BLEND, not a mode switch: `q = _air_density(alt)` is how much air there
      is, so it is also exactly how much of the aerodynamic class still applies. Lift, stall, ground
      effect, the energy trade, the bank and the rudder's steerage requirement all scale by q; drag
      goes with them, which IS the ballistic handover (no drag, no terminal velocity -- speed
      persists and becomes a momentum problem). Reaction control scales by (1-q): the same throttle
      and stick drive thrusters instead of propeller and elevator, with no airspeed requirement, so
      you can point anywhere including retrograde to brake. `_air_vel` decouples course from heading
      as the air thins -- in atmosphere the wing forces velocity to follow the nose, and that
      alignment is itself an aerodynamic effect. New `rcs` field on VehicleDef (default 0, so both
      existing air rows and every other class are unchanged) and a `lifter` row that carries them.
      HUD reads AIR %/VACUUM/RCS and the ballistic DRIFT angle.
      **The 14-48km numbers were wrong** -- Earth's, on a world whose rim wall is 4km. Corrected, but
      NOT by deriving the ceiling from the wall (tried, and it makes one number answer two questions:
      wall height is how the horizon looks, the ceiling is where a wing quits). Instead a CONTAINMENT
      FIELD spans wall-top to `atmo_top_h`, drawn as a faint fresnel shimmer -- a ringworld has no
      gravity well, so something at the rim has to hold the air in, and now you can see it.
- [ ] **Settle the wall height and the atmosphere ceiling.** Both are placeholders and they are now
      independent knobs with live sliders ("wall height" / "atmosphere top") and shot-harness
      overrides (`--wall`, `--atmo`). 4000 was judged too high -- "the walls dominate the landscape
      even when you are not near it" -- and 1500 with a 4000 ceiling reads much cleaner from the air.
      Comparison shots: logs/shots/20260812_2234_wall4000, _2239_wall2500, _2311_field (wall 1500).
      Fly to the ceiling before fixing it; the number is a judgement, not a calculation.
      BLOCKED (2026-08-12): this is a look-at-it judgement I can't make here. The Godot binary is
      out-of-repo (C:\Godot, outside the session sandbox), so I can't fly to the ceiling; and the
      number is explicitly "not a calculation" -- the meat model has to arbitrate. Worse, the three
      comparison air shots are pixel-identical because the `air` framing looks DOWN at the plain from
      400m and never turns to the rim, so the wall isn't even in them -- there was nothing to judge
      from. The framing that item below asks for is the prerequisite, and I built it in that item, so
      the next laptop `-- --shots --wall N --atmo M` run produces the `rim`/`rimtop` frames to settle
      this against.
- [x] **The field shimmer is unverified.** Implemented and it renders without error, but none of the
      three shot framings looks AT the rim, so nobody has seen it. Needs a framing that puts the rim
      wall in frame, from inside and from above the wall top.
      Added the two framings the item names to `_shot_run`, aimed across the strip at the NEARER rim
      (yaw +/-90deg, chosen by the framing point's lat): `rim` -- inside at eye level, 45deg FOV, a
      touch of up-pitch, "does the wall dominate the horizon from where you play"; and `rimtop` --
      camera at an ABSOLUTE ring height halfway up the field (`wall_top + max(atmo-wall,500)/2`),
      looking back at the rim, so the masonry, the shimmer strip above it and the ceiling are all in
      one frame. Needed two small harness generalisations, both scoped to the shot loop: an optional
      per-frame `yaw` override (captured/restored via `base_yaw` so it can't leak into the next
      patch's ground/road/air frames -- which also closes a latent cross-patch yaw bleed on road-less
      patches) and an `abs_h` key that places the camera at an absolute height instead of terrain+h
      (terrain height is meaningless above the wall top). These run per patch alongside the existing
      frames and honour `--wall`/`--atmo`, so they are also the missing prerequisite for the wall/
      ceiling item above. NOT run-verified: the Godot binary is out-of-repo/gated here (C:\Godot
      outside the sandbox), so no `--shots` -- and the shimmer is the thing being LOOKED at, so a
      screenshot I can't take is the whole point. Run `-- --shots` on the laptop and read the new
      `*_rim.png` / `*_rimtop.png`; log the session in logs/shots/JOURNAL.md.
- [x] **Ring-relative orbital mechanics.** You cannot orbit a ringworld the way you orbit a planet —
      the mass distribution is wrong and the ring is spinning under you at ~2.1 km/s. Match the
      spin and you hover over one spot; do not and the ring moves beneath you. That is a genuinely
      novel traversal mechanic and probably the most interesting item on this list.
      Done in `_loco_air`, and it needed almost no new state because `_car_arc` already lives in the
      ring's ROTATING frame — so `_air_vel.x` is literally your velocity relative to the ground, and
      "the ring moves beneath you" was already true by construction; what was missing was the physics
      that made it MATTER. The previous item's spin gravity was a placeholder constant `omega^2*r`.
      Replaced it with the full spinning-frame reaction derived the honest way — ask what a free body
      does in the INERTIAL frame and read it back out: a body with inertial tangential speed
      `v_i = v_arc + omega*r` needs centripetal `v_i^2/r` to hold its radius and nothing real provides
      it (a ring has no gravity well), so the net floor-ward pull IS `v_i^2/r`. That one term is spin
      gravity + Coriolis + centripetal at once, and the item's cases fall straight out: hover matched
      to spin (`v_arc=0`) reduces to `omega^2*r` (so low flight is byte-identical to before); fly
      PROGRADE and the floor pulls harder; fly RETROGRADE at `v_arc=-omega*r` and `v_i=0` — you're
      inertially still, pull is zero, you hold altitude with no thrust while the ring streams past at
      `omega*R` (~2.1 km/s), which is the orbit. The companion angular-momentum term (`r*v_i`
      conserved) couples vertical into arc: a climb throws you spinward, a descent retrograde, so you
      can't change altitude without the ground sliding under you. `_spin_omega()` derives omega (and
      the ~2.1 km/s spin speed) from AIR_GRAVITY, one source. HUD reads `GROUND ±N m/s` (the rate the
      ring slides beneath you) and flags `ORBIT` when `v_arc≈-omega*r`. Preserves the far-side crossing
      (r<0 flips the pull) for the right reason now. Scoped to `_loco_air` only; no other class reads
      it, no-change gate holds. Caveats: the `v_arc/r` term is exact only for small radial excursions
      (fine for a wing, which can't reach the axis anyway — the item's own note); `g_eff` is clamped
      ±200 m/s^2 and `r` floored at 1km to keep the integrator sane at the unreachable axis singularity;
      the UNPOWERED projectile ballistics (rifle rounds) stays the weapons programme's `Ballistics on a
      ring` item. NOT run-verified: the Godot binary is out-of-repo/gated here (C:\Godot), so no
      `--proving`, and orbital handling can't be judged from a screenshot anyway (the reason the proving
      ground exists). Cycle to the `lifter`/`airplane` ([L]) on the laptop, climb to vacuum and burn
      RETROGRADE — the ALT should hold with the throttle off while GROUND climbs toward -2000 m/s and
      the HUD flags ORBIT; fly PROGRADE and it should sink.
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



