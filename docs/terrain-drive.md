# Staged demo: Warthog, terrain expansion and backdrop

Scene: `res://world/terrain_drive.tscn`, built on the accepted terrain-only scene.
The previous stress workshop and terrain-only baseline remain separate scenes.
Only the new session's launcher should advance to this iteration.

## Exact Warthog configuration

Uses the existing archived Warthog model, runtime mesh-LOD importer, 4.8 m model
normalization, material preparation, collision-box dimensions, articulated
Wishbone controller, 0.18 m track extension, 0.14 m mount raise, 0.48 m centre of
mass, seated driver, vehicle audio and wheel effects. Its menu reads the same
`user://vehicle_tuning.cfg`, with the same tactical fallback path. All saved
physics/camera keys are checked against actual loaded values at startup.

At implementation time the saved configuration is: spring 28,000; damping 2,300;
travel 0.28; grip 1.45; steering 32/23 degrees with response 3.5; drive 4,000 N per
wheel; top speed 45 m/s; brake torque 2,000; front power 35%; front braking 80%;
chase view, distance 5.25 m, height 3.6 m, FOV 73, smoothing 5.5. These are user
settings, not newly selected tuning values. Camera modes retain the existing
transforms, smoothing and collision ray checks. The turret remains a visual
part of the source vehicle; weapon functionality belongs to a later stage.

The old controller's recovery plane defaults to -35 m as before. The new scene
disables that fixed plane because valid DEM ground can lie below it. R instead
raycasts onto loaded terrain and freezes across the pose reset, avoiding a
physics synchronization overwrite. Vehicle forces and speed tuning are unchanged.

## Expanding terrain

The initial 3.2 km square still loads before entry. A 16×16 demand window follows
the car (or inspection camera), within the native DEM's valid bounds. A parked
car retains a 3×3 support pocket. Hysteresis retains nearby old tiles, with a
400-resident ceiling; old disk caches are never deleted on RAM eviction.

One worker generates/loads primitive mesh arrays and expanded collision faces.
Main-thread publication has one render-upload phase and four smaller collision
shape phases, then a physics-tick readiness handoff. Triangles are partitioned
whole by centroid into four groups; no triangle is removed or moved. The worker
prepares these groups, and no worker creates PhysicsServer resources.
LOD indices remain cached. Existing tiles remain intact during new-tile work.

The same collision-supply speed controller scans up to 640 m ahead. Missing
coverage reduces safe supply speed and can brake; missing immediate wheel-area
coverage freezes the body, retaining velocity for recovery. These safeguards
are not replaced with a reduced top-speed setting.

`profile_terrain_drive.gd` runs parked, beneath-bridge, outward cold and repeated
warm routes at 1280×800 / 120 FPS cap / Compatibility. Steering guidance only
exists in the benchmark. It verifies actual start poses, all 17 saved settings,
speed, cold builds, disk reuse, residency, frame-time distributions, ray agreement
between mesh and collision across quadrant joins, and forced starvation/recovery.
`--cold-cache-tag=<unique-tag>` gives exterior tiles an
isolated cache namespace; the original square retains its original cache key.
No existing cache is purged to obtain a cold result.

## Controls

WASD drive, Space brake, C camera, RMB look, Home centre look, E fly/drive,
R recover onto current loaded ground, F5 original vehicle setup, F2 briefing.
Inspection flight retains WASD, Space/Ctrl and Shift. This iteration adds no
terrain editing UI, backdrop, trees, expanded lighting or weapon logic.

The initial unguided benchmark wandered instead of repeating its route; it is
not warm-cache validation. A guided test then exposed a pose reset being
overwritten by physics synchronization; the fixed reset is now explicitly
asserted. One intermediate warm test recorded a 123 ms outlier; it did not recur
in the next instrumented run, and its cause is not established. The instrumented
run identified smaller 17–19 ms frames as whole-tile collision installation
(13–15 ms main-thread work). That evidence motivated the four-part installation.

## Final validation, 7 October 2026

One Godot 4.5.1 Compatibility instance, Intel UHD, 1280×800, 120 FPS cap, vsync
off. Initial square loaded from its retained cache; exterior used a fresh
diagnostic namespace. Rendering and installation ran together during driving.

| Sample | Seconds | FPS | p99 ms | Maximum ms | Cold / cached tiles |
| --- | ---: | ---: | ---: | ---: | ---: |
| Parked | 12 | 120.01 | 9.252 | 11.305 | 0 / 0 |
| Drive beneath bridge | 10 | 120.16 | 9.707 | 11.219 | 15 / 0 |
| Cold outward drive | 65 | 120.01 | 9.492 | 11.182 | 300 / 0 |
| Fully cached return route | 65 | 120.01 | 9.607 | 11.192 | 0 / 192 |

All 18,245 measured frames were below 16.667 ms. Cold driving reached 44.999 m/s
and x=4056 m, well beyond the original +1600 m boundary. No unexpected freeze,
supply brake or power-limiting ticks occurred in any sample. Forced starvation
froze the vehicle and restored it safely. All 17 saved configuration values
matched; start/reset positions persisted. Maximum resident count was 288 of the
400 ceiling. Main-thread installation phases peaked at 5.336 ms, versus roughly
15 ms before splitting collision. Raycasts across streamed collider quadrant
joins matched full-detail mesh intersections within 0.000016 m.

The intermediate 123 ms outlier was not reproduced in the two subsequent runs;
its cause remains unproven. Do not claim that collision splitting explained it.
The final result covers these routes and durations, not all possible slopes,
flight speeds, terrain edits or long-session conditions.

### F8 suspension jitter capture (2026-10-07)
F8 starts and stops a separate JSONL capture with five seconds of preceding history.
The HUD shows recording, finishing and saved states. The session launcher writes
into its outputs/jitter-traces directory; direct scene launches default to
user://terrain-drive-traces. Each capture gets a new file and normal exit flushes
an active capture. No vehicle tuning or forces were changed.

The shared workshop flight recorder supplies bounded physics/frame histories and
same-point terrain probes. Additional fields record spring/damper/bump-stop loads,
wheel ray endpoints, compression/travel, contact collider/normal, chassis contact
count/pose/velocity, camera pose, physics frame, terrain worker/queue/cache counters
and upload phase timestamps. Correlate downward velocity and compression/load
changes with stable-point probe heights before attributing movement to generation.
A repeated render pose without a physics step can also distinguish camera/render
cadence from physical motion. A physics-frame sample observes controller state;
it is not a substep solver impulse trace.

JSON serialization and disk writes run on a background thread with a bounded
queue and reported drop count. Final focused rendered test: 601 physics samples,
1,179 frame samples, 300 physics samples of pre-roll, four wheels validated,
start/stop/restart validated, no dropped batches. Maximum sampling time 0.691 ms;
maximum recorded frame 14.069 ms. This validates capture, not a diagnosis or fix
for the user's intermittent jitter. Saved camera distance was 6 m at test time
and was preserved.

### Camera cadence fix (2026-10-07)
User capture jitter-2026-10-07T16-39-38-53646497.jsonl showed 60 Hz physics
and 120 FPS rendering with interpolation disabled. Of 1,397 frame transitions,
698 had no vehicle movement; the other 699 stepped roughly 0.74 m at speed.
The chase camera advanced each frame, producing alternating relative motion.
All 699 physics samples had no streaming freeze or braking. Generated count
stayed zero; 2,248 repeated ground probes all hit, with maximum height difference
1.073e-6 m. Maximum captured frame time was 13.284 ms.

The standalone driving scene now enables physics interpolation. Both cameras
use get_global_transform_interpolated(), with automatic camera interpolation off
to avoid applying it twice. Vehicle recovery resets interpolation history.
Physics tick rate, suspension and saved vehicle/camera tuning are unchanged.
F8 now records raw and interpolated vehicle positions and actual runtime
interpolation state. This follows Godot 4.5's advanced interpolation camera guide:
https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/advanced_physics_interpolation.html

Final rendered check passed on the normal driving route at about 44.45 m/s:
1,320 frame transitions, 660 stationary raw-physics poses but zero stationary
interpolated poses. P95 relative vehicle/camera displacement per frame fell from
0.371815 m (raw pose against camera) to 0.009126 m (rendered pose against camera).
P99 frame time 10.428 ms; maximum 12.357 ms. Driver camera alignment error was zero;
nearby 50 m recovery reset passed. This targets the measured cadence defect;
user confirmation is still needed for any remaining visual symptoms.

Test harness corrections: await briefing readiness before dismissing it, skip
empty JSONL tail lines, and recover onto resident terrain instead of an evicted
starting tile. Initial harness failures were not counted as successful tests.

### First backdrop pass (2026-10-07)
`terrain_drive_backdrop.gd` adapts the workshop scenery separately, keeping the
old workshop script and launcher intact. It reuses the 3,000 km circumference /
50 km width ring, DEM splice heights, satellite preview cache, containment walls,
existing sky shader and existing haze density. No clouds or new lighting stage.
The accepted foreground sun and ambient settings remain unchanged; the backdrop
shader takes its sun direction from that existing light.

The local 16 km square uses the same staged source and height origin, with a
128 m scenery grid and coarse edge anchors. The outer ring remains coarse.
A 512-square R8 ownership texture maps one texel to each 200 m terrain tile.
Its origin derives from native DEM bounds rather than assuming a centred DEM.
Only published tiles claim ownership; scenery updates after the streamer's
publication/eviction pass. No scenery collider or terrain cache identity changes.
This prevents distant terrain drawing over the playable bridge, tunnel or hills.

This is a first visual pass: coarse scenery edges approximate the fine surface,
and the foreground still has the accepted plain green material. Exact visual
LOD transition stitching, wider DEM scenery fidelity, clouds and foreground
material matching are subsequent backdrop refinements. Terrain controls still
follow the backdrop; trees, lighting, models and weapons remain later stages.

`benchmarks/profile_drive_backdrop.gd` checks the saved configuration, 120 FPS cap,
physics interpolation and ownership-mask coverage, compares four viewing
directions with/without scenery, captures the ring, and drives into streamed
terrain. It waits for briefing screenshot readiness before entering. The
`--no-drive-backdrop` argument supports a baseline launch; normal play includes
scenery. A unique `--cold-cache-tag` measures cold exterior generation without
purging caches. Final measurements are in this session's BACKDROP-STAGE-3A.md.

### Full-resolution satellite surface (2026-10-07)
The accepted ring backdrop is followed by the existing 8192×8192 Millstreet
satellite image on the driving terrain. At 90.0288 km coverage this is about
10.99 m per pixel: real fields/roads and colour variation, not grass-scale detail.
World X/Z maps through the same DEM camera-pixel origin and north/south sign;
geometry, terrain cache identities and collision are unchanged. Authored bridge
and tunnel surfaces currently inherit this top-down drape too.

`terrain_drive_satellite.gd` decodes on the loading worker, generates mipmaps and
compresses to S3TC. The 44,739,256-byte image is cached under user://terrain-satellite
using source modification time, byte length and processing-version identity.
The ImageTexture is shared with the home backdrop. Initial and streamed tiles
use the same material; the shader requires no new mesh UV data or extra pass.
The plain terrain-only baseline keeps its existing StandardMaterial3D.
`--no-drive-satellite` retains a diagnostic plain-green comparison.

`profile_drive_satellite.gd` compares plain/satellite material in four directions
and drives 35 seconds with streaming. `--satellite-smoke` checks the cached path
and captures chase/overview views. The session SATELLITE-STAGE-3B.md records the
measurements. Finer close-range grass/rock and dedicated structure materials
remain separate visual refinements.

### Curved close terrain (2026-10-07)
The detailed terrain had remained in the old flat tangent frame while the distant
DEM scenery used the ring frame. At long distances this produced a visibly raised
far band. `terrain_drive_ring.gd` is now the shared conversion layer: tile render
vertices, normals and collision are warped to the ring, while the streamer's tile
lookup converts world positions back to ring arc/lateral coordinates. The near
backdrop band uses the same ring conversion and source heights, so it meets the
close tiles in the same frame.

The Warthog now receives radial gravity and the vehicle/camera placement uses the
local tangent basis. Satellite UVs derive arc length from the curved vertex rather
than using global X. Curved terrain has a separate source-cache identity, keeping
previous caches intact. Focused checks confirm a 1,674.54 m ring lift at 20 km,
matching inverse height coordinates (0.054 m maximum error), and confirm all four
wheels stay grounded while driving there. The broader drive profile was updated
to measure ring coordinates and tangent steering; it retains the 60 FPS overall
target and collision/cache checks.
