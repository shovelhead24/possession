# Grenade terrain lab

Separate experiment: `game/world/sdf_grenade_lab.tscn`. It does not load or
overwrite the authoring workshop's saved recipe, or change the original arena.
Launch with `outputs/Open-Grenade-Terrain-Lab.ps1` in the surrounding workspace,
or open the scene directly in Godot 4.5.1.

Click to capture the mouse; B throws a prototype grenade with a two-second fuse.
F switches walk/fly, WASD moves, Space/Ctrl moves vertically in flight. H/K visit
the Warthog/tank; E enters/exits. Existing weapons and possession remain available.
This is a terrain experiment, not finished grenade combat: the grenade has a
simple ball visual/flash, swept-point bounce collision, and no damage or blast
impulse. Holding B does not auto-repeat.

Impact retains only 18% of sideways speed and 12% of normal bounce speed. Low-
speed ground contacts enter a supported resting state (and wake if support is
removed), so grenades stop instead of continually hopping. The fuse keeps running.
`check_terrain_grenade.gd` verifies time/distance after impact, stable rest and one
detonation for a full-speed throw onto a flat test floor.

The cut uses a 2 m radius sphere centred above the grenade for a shallow hole.
The underlying grid is still 2 m: these are coarse, several-metre-wide craters,
not accurately resolved small bullet holes. Sub-metre holes need finer local
sampling and a tested resolution-transition design. Unsupported terrain/queue
overflow rejects the cut with a warning; accepted edits are never dropped.

## Runtime design

1. Retain the procedural samples for resident terrain in an estimated 32 MiB LRU
   cache. This is not a cap on total application memory.
2. Append compact, ordered spherical cuts. Reuse previous field samples for
   append-only subtraction; replay other edits from the base to preserve results.
3. Rebuild affected 8 m horizontal mesh sections on one worker. The visual draw
   mesh remains one mesh per 32 m chunk. Vertical extent is -24..64 m.
4. Prepare only changed collision sections on the main thread, yielding after
   approximately 4 ms. A single resource operation can exceed that budget.
5. Register replacement static bodies with collision disabled. Allow physics to
   register their bounds before switching the old/new filters and visible meshes
   together. Retire old bodies gradually. No vehicle freezing or repositioning.
6. Persist generated meshes and sampled state on disk, plus the independent
   ordered recipe. No automatic cache deletion. Initial terrain uses valid disk
   caches; edits currently rebuild incrementally rather than reload old edited
   mesh files.

Runtime storage: `user://sdf-destruction-meshes/`. Each session has a distinct
`recipe-<timestamp>.json`. Craters remain for the session and their recipes are
retained, but the lab intentionally starts fresh; automatic restoration is not
yet wired up. The workshop's `user://sdf-authoring.json` is untouched.

The demo has a bounded preloaded test area, not destruction integrated into the
entire streamed arena. Its interactive movement boundary is inside that area.
Queue admission is limited to 32 pending edits and 2048 recipe features. There
is no promise of unlimited overlapping edits or arbitrarily large blasts.
Cuts reaching within 2 m of the vertical test-volume boundary are rejected:
repeated grenades can otherwise dig through its finite bottom. This is a lab
safety boundary, not a proposed ring-world bedrock design.

## Tests and performance method

`res://benchmarks/destruction_profile.tscn` uses the same implementation, a real
Warthog following a fixed requested route, stationary camera, full ring scenery,
and live physics. AI is disabled during timing; the terrain is preloaded so this
isolates destruction rather than simultaneous cold streaming. The realised path
can change when the vehicle encounters holes. This is not a full gameplay FPS
guarantee.

Arguments after `--`:

- `--destruction-mode=baseline` (no cuts), `whole` (whole-chunk collider), or
  `blocks` (changed sections only).
- `--destruction-radius=2 --destruction-hz=1 --destruction-seconds=15`.
- `--destruction-label=<unique-name>` names the JSON/PNG output in `user://`.

Reports contain per-frame times, requested-edit-to-draw callback latency,
first post-handover physics-query latency, worker/meshing/preparation/activation
costs, queue length, rejection count, travelled distance, upward speed, streaming
suspension and ground probes. Visual latency is not physical input-to-photon
latency. Collision height is checked against the same sampled tetrahedral field,
not against a different analytic surface. Benchmark JSON excludes startup time.

Run the playable scene with `-- --grenade-check` for three actual fused projectile
throws, including overlapping cuts across a chunk seam. It checks visible-depth
changes, collision agreement and completion; it writes `grenade-integration.json`
and a screenshot without touching user saves.

`check_sdf_precache.gd` additionally compares six overlapping incremental craters
against independent full replays and compares positions/normals at chunk seams.
Existing recipe, brush and original tetrahedral equivalence tests remain relevant.

## Limits still requiring work

Cold terrain generation, simultaneous streaming/destruction, multiplayer,
save-game restoration, destructible buildings, debris, navigation changes, finer
local detail and very long play sessions are not covered. Tree roots and static
props are not automatically re-grounded. Raw texture export warnings and
synchronous model loading are existing separate packaging/startup issues.

## Measurements — 2026-10-04

Godot 4.5.1 Compatibility, Intel UHD Graphics, 960×600, ordinary desktop load.
These are short prototype measurements, not controlled hardware benchmarks.

| Run | Cuts | FPS | Median visible latency | Median collision latency |
| --- | ---: | ---: | ---: | ---: |
| No destruction, final baseline | 0 | 34.8 | — | — |
| Local cut, whole-chunk collider, 1 Hz | 14 | 33.3 | 233 ms | 237 ms |
| Local sections, tuned handover, 1 Hz | 14 | 46.3 | 124 ms | 125 ms |
| Local sections, earlier conservative handover, 4 Hz | 53 | 39.3 | 210 ms | 216 ms |
| Final sections + volume guard, 4 Hz | 50 | 48.5 | 130 ms | 134 ms |

Do not interpret the higher FPS with cuts as destruction improving rendering:
machine load and the realised vehicle route varied between runs. More directly,
mean preparation fell from 27.5 ms per whole-chunk edit to 5.1 ms with sections.
The tuned 1 Hz run's worst visible latency was 224 ms; frame p95 was 34.2 ms and
worst frame 98.4 ms. There are still occasional hitches. All 14 edits used warm
base data; checked collision heights agreed within 1 mm. No streaming suspension,
below-surface vehicle probes or missing-floor probes occurred in that run.

The original broad-invalidation attempt was unusable: the first cut took about
2.35 seconds and a 1 Hz sequence accumulated a seven-edit backlog. That run used
3 m cuts and an older implementation, so it is diagnostic evidence of the failure,
not a matched speedup ratio against the final 2 m test.

The later 4 Hz tuned run found the finite-volume failure described above: repeated
cuts reached below the -23 m ground-query endpoint. This was recorded as a failed
test, not hidden as a successful performance result; admission now preserves the
bottom margin. The stress case demonstrates why short average-FPS tests alone
are insufficient.

The final guarded stress run passed: 50 completed cuts, three boundary-rejected
requests, maximum queued count one, no missing-floor/below-surface probes, no
streaming suspension, and collision-height error below 1 mm. Worst visible edit
latency was 275 ms. The rejections are explicit, not counted as successful cuts.

Actual grenade integration passed three projectile/fuse/cut operations, including
overlap across a seam. A separate full-speed throw test measured settling 0.233 s
and 0.660 m after first impact, then stationary support until one detonation.
Workshop cache regression measured a warm 4 m brush update at 6.9 ms versus
171 ms cold in its standalone test; that is mesh-worker time, not click latency.
The final rendered workshop regression also passed: its six submitted brush
updates reached the draw callback in 123–169 ms, followed by successful undo/redo,
hill/tunnel/bridge collision, save/load, Warthog, boundary and editor-control tests.

Raw JSON and the captured crater image are copied to the workspace `outputs/`
folder. Original userdata caches and independent recipes are retained.
