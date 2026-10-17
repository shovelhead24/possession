> CURRENT STATE 2026-10-12: Aggressive overlap shadows and the following CPU-cache pass were reverted at user request. Read HANDOVER-REBUILD-2026-10-12.md. Earlier sections describing those experiments are historical.

# Rebuild Demo — first content increment, 9 October 2026

Launch using **Rebuild Demo** on the desktop. This is a separate entry scene in
the Tree Demo repository, not a separate checkout. Tree Demo remains the project
main scene; its source and launcher were not changed by this increment.

The new scene restores one original 12 × 14 m building from arena_compounds.gd.
The original sixteen box parts, windows and 2 m doorway retain analytic layer-2
collision. A foundation and entrance ramp bring the collision part count to 18.
All boxes are rendered in two material MultiMeshes (six added draw calls in the
tested two-cascade shadow view). Local ring orientation is used throughout.

Placement surveys nearby candidate sites against resident edited-terrain collision,
using a 2 m footprint sampling grid plus the ramp endpoint. Initial relief is limited
to 1.5 m. In the current save it selects arc 110 / lateral 240, close to the Warthog.
The HUD reports actual coordinates. This is a procedural demonstration placement,
not a persistent building editor; exact sub-2 m terrain peaks remain a sampling limit.

The manager checks terrain-body identity at 4 Hz and re-grounds after publication.
Visuals cull at 650 m; shadow casting stops beyond 140 m. Runtime geometry/collision
retire beyond 750 m unless car or walking player needs support within 100 m, and
require resident terrain. Rendering follows edited-terrain fallback visibility.
These rules are for this one building, not a general world-content streaming system.

The launcher uses copies of terrain-drive-edits.json and painted-trees.json in
`%APPDATA%\Godot\app_userdata\Rebuild Demo`. Vehicle tuning, caches and F8 traces
still use the Tree Demo project namespace. The two explicit save flags are required
when launching the new scene directly; otherwise inherited save defaults apply.
Existing Tree Demo and Terrain Demo launchers were not changed.

Validation:
- check_rebuild_buildings.gd: 16 source parts retained, two visual batches, doorway
  clear and wall/floor solid at arc 100000 with rotated ring gravity.
- check_rebuild_integration.gd: real saved-world startup, footprint placement,
  walking up the ramp through the doorway, standing on the floor, F1 return to foot.
- Rendered screenshot visually reviewed. Existing Warthog material-conversion
  warnings remain; no script errors in the final integration run.
- Matched building-hidden/building-visible stationary and camera-strafe measurements.
  Intel UHD, Compatibility, actual test viewport 1366 × 749, uncapped, vsync disabled.
  Only 240 measured frames per case after 90 warmup frames. Building-on means:
  stationary 8.239 ms / 121.38 FPS, p95 10.699 ms, p99 13.118 ms;
  camera route 8.341 ms / 119.89 FPS, p95 13.002 ms, p99 15.597 ms.
  Building-off means 9.086 and 8.443 ms; the apparent speedup is timing drift,
  not evidence that adding a building makes rendering faster. Draws increased
  156→162, submitted primitives increased by 648 including shadow passes.
  No stress population or matched driving-route performance claim is supported.

Run integration with isolated copies, passing `--drive-edits-file=...` and
`--tree-paint-file=...` after `--`; use `--rebuild-output=...` to select report output.
Do not run alongside a user playtest. Full startup takes about 41 seconds here.

Next increments remain: richer tactical alien rig/behavior adaptation; weapons,
interaction and possession; additional vehicle content; population scheduling and
moving-route/stress measurements. The tactical rig_scale_bake.gd contains an
asset-specific animation translation multiplier: do not copy it blindly. Models
and behaviors beyond the existing Warthog are not restored by this first increment.

## Construction editor — 2026-10-09
Rebuild Demo now includes a Forge-style construction editor. F1 → Construction.
Read CONSTRUCTION-EDITOR.md. New modules: forge_parts.gd, forge_store.gd,
forge_world.gd and forge_editor.gd. Construction saves are separate from terrain
and tree snapshots; isolated tests must also pass --forge-file=<test path>.
The original showcase building remains available; construction parts are user-placed.
The previous first-building timing figures do not establish construction stress performance.

## Weapons — 2026-10-10
Carbine and Railgun are restored, with original arms and sounds. Read WEAPONS-REBUILD.md for controls, performance design, tests and remaining scope. The Rebuild Demo shortcut still launches this scene. Loading-screen SOP is recorded in AGENTS.md.


## Terrain streaming cache fix — 2026-10-10
The edit cache now returns a separate publication dictionary, preventing stale collision cursors after tile revisits. check_stream_cache_revisit.gd reproduces the original failure and checks 32 revisits plus a queued edit. F8 includes streaming collision and edit queue state. Continuous brush undo/redo and save/reload regression passed; player saves were not changed.


## Collision inspection and Plasma Rifle — 2026-10-10
Read COLLISION-INSPECTION.md. Tab retains FPS while hiding HUD; both F1 menus offer loaded collision wireframes. Rebuild suspension now includes construction layer 2. Plasma Rifle is weapon 3, Q cycles all three. Mountain triangle/shading audit is documented; geometry was not retuned.


## Tactical aliens — 2026-10-11

The tactical patrol/combat aliens are restored. Read TACTICAL-ALIENS.md for behavior, streaming limits, tests and performance caveats. Use the existing Rebuild Demo shortcut. G throws a combat frag; F7 resets encounters. The visible loading briefing and Tab/FPS behavior have been checked. The 120 FPS target is not yet met.

## Shadows and enemy performance — 2026-10-11

Nearby alien body shadows are enabled. Rifles now combine seven skinned pieces into one mesh with three original materials, and capsules update only when stance changes. Read ALIEN-PERFORMANCE.md for measurements, validation and remaining bottlenecks. The updated briefing is visually verified. Full-world samples still do not meet 120 FPS; close foliage rendering is the largest measured remaining scene cost in the tested foot view.


## Authored canopy density and forest review - 2026-10-11

F1 > Forest density & performance bakes a persistent all-authored canopy-density field, updates local cells after tree edits, lists dense review areas and measures the current editor view. Read FOLIAGE-SLICE.md. The experimental density-based LOD budget is optional and off by default: rendering gains were inconsistent. Normal distance LODs and shadows remain. Loading briefing and editor were visually checked. The 120 FPS target remains unmet.


## Aggressive forest shadows - 2026-10-11

Any projected canopy-bound overlap now suppresses the farther tree shadow proxy, enabled by default in Rebuild. F1 forest review offers an A/B toggle. Worker classification/grouping and cached snapshots limit main-thread work; tree geometry and collision remain unchanged. Read SHADOW-OVERLAP.md for tests, timings and approximation details. Loading briefing visually verified.


## Cached shadows and cover — validated 2026-10-12

Visual LOD changes preserve shadow geometry caches; obstruction updates rebuild only changed groups. Caster settings use a registry and change detection. Alien cover caches grounding with local terrain and construction invalidation, retaining live clearance/threat checks. Read CPU-CACHE-UPDATE.md for controlled CPU comparison, full-world measurements and tests. The briefing was visually verified; 120 FPS remains unmet.


## Vehicle impacts and T. rex � 2026-10-12

Warthog impacts damage and punt aliens forward/upward; fatal hits carry the impulse into ragdolls. The original Tyrant walking, hill grounding, sound and four attack sequences are restored with curved-terrain integration. F7 resets squads and the Tyrant. Read REX-AND-IMPACTS.md for tuning, validation and limits.


## T. rex forest stalls and bite continuity - 2026-10-12

Read REX-BITE-FIX.md. The larger size is explicit; original Rex-only trunk exceptions are restored, held attacks finish before distance/stream suspension, and F8 includes attack/movement diagnostics. The current saved-world reproduction completed the full four-attack loop without the earlier prolonged frozen pose.

## Actor authoring / 2026-10-12
F1 now includes Actors + patrol routes for aliens, squads, T. rexes and drivable Warthogs. See ACTOR-EDITOR.md. Tests must isolate actors.json using --actors-file alongside the terrain, tree and construction overrides.

## AI diagnostics and heavy crates / 2026-10-14
See AI-DIAGNOSTICS-CRATES.md. F4 toggles readable AI state labels; F8 records 4 Hz AI snapshots and transitions. The actor palette includes heavy rigid-body crates affected by Warthogs and grenades.


## Patrol replan correction — 2026-10-14
The 23:19:42 F8 recording showed squad #8 repeatedly reversing on waypoint 1.
Every 1.3-second replan reinserted the current 4-metre grid cell centre behind
the walking unit. Navigation now omits that start centre for an open starting
cell, retaining blocked-cell recovery. It appends the actual destination only
when A* reaches its original open goal cell within the local grid, with slope
and clearance checks. This fixes offset destinations as well as backtracking.
Formation timing and authored routes were not changed.
Validation: check_patrol_replan.gd covers repeated replanning, exact goals,
blocked starts, wall detours, cliffs and out-of-grid goals. Existing
check_rebuild_rex_impacts.gd passed collision, Rex and tactical alien checks.
Briefing rendered and visually inspected. No live save edits or FPS claim.


## Dynamic tactics / 2026-10-14
See DYNAMIC-TACTICS.md for separated fleeing navigation maps, stable per-member
noise-biased routes, contact-triggered nearest assault pairs and validation.
F4/F8 now expose pair roles, partner IDs, route seeds and map-build counts.


## Reticle and aim assistance / 2026-10-15
See AIM-ASSIST.md. Blue reticle turns red on a living enemy ray hit.
Bracket keys adjust saved strength; Shift+brackets adjust cone. Default 35%,
4 degrees. Assistance changes shot direction; reticle displays that correction.
Focused aim and existing weapon tests passed; briefing visually inspected.


## CE-inspired aiming revision / 2026-10-15
AIM-ASSIST.md now supersedes the moving-reticle first pass: centred weapon
reticles; per-weapon eligibility; nearest collision-volume correction; spread
after correction; input-gated controller friction/tracking. Mouse stays direct.
Ctrl/Alt plus brackets tune controller layers; existing correction settings persist.
Focused aim and weapon regression tests pass. Physical-controller feel remains
to be playtested. F8 includes aim tuning and last-shot correction/spread.


## DS4Windows / PS5 restore, 2026-10-15
See PS5-CONTROLLER.md. Restored early-build controller polling, preferring the
virtual XInput endpoint over the duplicate native DualSense. Tab/Create keeps
the reticle visible. Foot and vehicle controls, reload/interaction, jump and
grenade polling are wired. Focus/trigger rearm and duplicate input tests passed.
Both live device endpoints were discovered; physical controls need playtesting.


## Device recovery / 2026-10-15
See DEVICE-RECOVERY.md. Captured logs show controller disconnects and WASAPI
output invalidations. Realtek is now explicitly selected for game audio.
F5 Devices supports Native DualSense, XInput only and stable Auto selection.
F8 records selected endpoints. Hardware/Bluetooth pairing was not changed.
