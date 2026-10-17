# Camera, Rex and CE plasma grip — 15 October 2026

## Recorded evidence

The F8 captures at 19:47:32 and 19:47:53 show Rex #5 hunting while reporting `terrain_support`, with maximum recorded stalled durations of 13.22 and 16.46 seconds. The first eventually resumes moving. The old ground sampler used the same empty result for missing support and normals steeper than 48 degrees. Recovery cleared a path array that the Rex locomotion did not use. The selected weapon in these captures was index 4, Halo CE Plasma Rifle.

## Changes

- Warthog third-person view retains the speed-dependent look-ahead. A separate recenter requires two seconds of forward motion and two seconds since the last mouse/right-stick look input. It smoothly returns yaw and pitch to centre. Reverse and stationary movement do not recenter.
- Camera collision uses a 28 cm sphere sweep from the vehicle pivot, independently of the look-ahead target. When scenery leaves under 2 m of clearance, a temporary driver view replaces the obstructed chase view. Chase returns above 3 m clearance; the selected camera mode is preserved.
- CE Plasma Rifle gets a measured grip anchor and scaled arm placement, reset on every weapon switch so transforms cannot accumulate. The shared finger pose alone was insufficient. Exported blue/white attachment-marker surfaces are stripped from the runtime CE mesh; original assets remain intact.
- Rex movement probes 1.8 m ahead, retains detours for 1.5 seconds, considers retreat directions, and permits downhill recovery from an already-too-steep surface. Failed escape scans retry at 0.3-second intervals. Persistently blocked hunting can temporarily exclude an inaccessible victim.
- Sight checks accumulate optical cover through approximate tree crown ellipsoids from the spatially indexed painted-tree data. Multiple crowns reduce effective sight range exponentially; clear space under crowns remains open. There are no leaf physics bodies or leaf raycasts. Existing four-per-second target scans remain.
- F8 includes camera quiet time, manual look, temporary driver-view state and lead; Rex diagnostics include detours, retries, recovery counts and foliage rejection/depth.

## Verification

Isolated weapon previews rendered successfully from first-person and side views. The updated loading briefing was rendered and inspected. Static GDScript parser checks passed for the vehicle camera, Rex and recorder, including their preload dependencies. No gameplay performance result is claimed.

After explicit user approval, `game/benchmarks/check_camera_forest_recovery.gd` passed in headless Godot 4.5.1: recenter timing/input and reverse gates, obstruction fallback and chase recovery, compounded forest crown cover and open gaps, and downhill Rex escape without teleporting. The first run exposed a vertically misplaced synthetic tree fixture; correcting its bounds made the canopy checks exercise the intended sightline. The two recorded terrain locations have not been replayed after these changes. Check the in-game feel and new F8 diagnostics after restarting.

Player saves and launcher were not changed. The playtest ZIP was not rebuilt; rebuild it only on explicit request, following the packaging note in the chat outputs folder.

