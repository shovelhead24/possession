# Staged demo: terrain baseline

Scene: `res://world/terrain_baseline.tscn`. This is a separate scene in the existing
project. The October 6 restart order is terrain; Warthog; backdrop and terrain
controls; trees and lighting; models and weapons. Only stage 1 is included here.

The footprint is 3,200 m square, centred on the previous scene's home DEM camera
coordinates. It reads the native 3840-square Millstreet elevation source
(23.445 m/sample), with a local vertical origin. The fresh recipe adds one broad
bridge and a hill with a through tunnel. It does not load saved workshop recipes.

The bounded baseline prepares all 256 200 m tiles and collision during loading.
An 8 m sampling lattice is shared globally, including vertical planes, so the
existing tetrahedral extractor produces matching boundaries. The bridge has a
16 m thick deck aligned to that lattice; this is a coarse test structure.
It is not a claim of 8 m native DEM detail or finished fine sculpting quality.

The source recipe remains authoritative. Primitive mesh arrays and precomputed,
border-preserving render LOD indices persist in an isolated content-addressed
`user://terrain-baseline/` cache. Godot selects the cached index LODs by projected
size. Main-thread mesh upload and full-detail collision creation finish before
entry. Full collision remains resident throughout this small bounded scene;
there is no in-play streaming or generation yet. Extending this to an unbounded
world will require measured residency and upload budgets.

Basic solid terrain material, ambient illumination and one unshadowed sun are
the starting visual baseline. WASD/RMB inspect; Space/Ctrl change altitude;
Shift speeds up travel; 1–4 jump to overview, bridge, tunnel and whole-area views.
Enter dismisses the loading/briefing screen; F2 reopens it. The inspection camera
can fly through geometry; it is not a vehicle or character collision controller.

`profile_terrain_baseline.gd -- --baseline-profile --output=<directory>` checks
native source size, tile coverage, shared boundary positions, bridge deck and
underside collision, and the clear tunnel passage. Rendered samples use an
uncapped 1280×800 Compatibility viewport. Seven 20-second windows cover overview,
movement beneath the bridge, tunnel, whole area, a 3 km traverse, camera rotation
and a repeated bridge view. Each reports median/p95/p99/max wall-frame time,
budget misses and render counts. The gate requires p99 <=16.667 ms for every
sample; maximums and misses remain visible even when that gate passes. Headless
validation is not FPS evidence. Interactive play uses a 120 FPS software cap with
vsync off: the target is at least 60 FPS, and tested 60 Hz vsync configurations
had uneven wall-frame spacing despite substantial rendering headroom.

The first rendered uncapped run passed all seven p99 gates at 1280×800 on Intel
UHD Graphics / Godot 4.5.1 Compatibility. Average rates ranged from 180.07 to
295.05 FPS; the worst p99 was 9.833 ms (whole area). There were 7 frames above
16.667 ms out of 35,632, with a maximum of 23.005 ms. This is measured headroom,
not a guarantee that every future frame or later content stage will meet budget.
All 256 tile seams and bridge/tunnel collision probes passed. The corrected
rendered cold build took 70.24 s; warm rendered loading took 6.08–6.68 s.

The software 60 FPS cap plus vsync averaged 59.99 FPS but p99 was 21.89–23.31 ms;
vsync alone still failed the 20 ms presentation gate. These failures are retained
in the session logs. A 120 FPS, vsync-off presentation check uses the stricter
16.667 ms p99 budget instead. It passed: whole-area 119.81 FPS, p99 10.900 ms,
maximum 13.837 ms; moving beneath bridge 120.01 FPS, p99 8.645 ms, maximum
11.269 ms. None of those 4,798 frames exceeded 16.667 ms. Source-generation time
is outside every FPS window. These are two 20-second pacing windows, not a
long-session endurance result.

The tunnel's coarse shading/contour is present with render LOD disabled too.
Future meshing work should consider direct DEM heightfield extraction and
adaptive volumetric sampling around authored cavities/overhangs, with validated
joins between resolutions. No octree implementation is included in this stage.
