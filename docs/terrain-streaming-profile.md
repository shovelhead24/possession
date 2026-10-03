# Terrain mesher profiling — 2026-10-03

The live arena now uses indexed marching tetrahedra. Shared crossed edges reuse
vertices and finite-difference normals. This is not Marching Cubes, Transvoxel,
ray marching or a change to terrain resolution. The preserved mesh snapshot and
ray comparison scenes are unchanged. `--mesher-legacy` selects the reference.

## Correctness and generation

`check_tetra_mesher.gd` compares expanded triangle order/winding, positions and
normals at ground, tunnel portal, overpass and an actual coarse-border sampler.
All four had zero position and normal error. Empty volume also passed.
The reference normal loop is timed separately after triangulation; its output is
unchanged, but its execution scheduling differs from the frozen original.

Final sequential headless sample on this machine:

| Region | Reference ms | Indexed ms | Reference array bytes | Indexed array bytes |
|---|---:|---:|---:|---:|
| Ground | 698 | 219 | 258840 | 89964 |
| Tunnel portal | 466 | 172 | 147816 | 50916 |
| Overpass | 749 | 281 | 272304 | 114240 |
| Overpass boundary | 920 | 297 | 284760 | 117420 |

That is 2.7–3.2x faster in this run and 58–66% smaller vertex/normal/index
payloads. These bytes are not total RAM, collider memory or compressed disk size.
An earlier run was slower in absolute terms but showed 2.6–3.4x improvement.
Triangle counts and collision detail are unchanged.

The expanded arena regression also passed actual tunnel passages/roofs,
canyon floor/overpass deck collision, both compound pads and openings, and
bounded streaming. The standalone SDF demo check passed too.

## Twenty-second driving tests

Godot 4.5.1, Compatibility, Intel UHD Graphics, 960x600, shadows on, real Warthog
physics, original 45 m/s top speed and 4000 engine force. Other actors are held
static. Same requested waypoint route, throttle and steering policy; no VSync.
The existing streaming speed limiter changes the realised trajectory, so this
is a throughput test, NOT a matched-camera rendering comparison.

| Run | Mean FPS | Distance m | p95 frame ms | Worst frame ms | Cached / installs |
|---|---:|---:|---:|---:|---:|
| Reference cold | 33.4 | 136.8 | 40.1 | 110.8 | 1 / 22 |
| Indexed cold | 36.9 | 219.2 | 37.8 | 81.7 | 5 / 41 |
| Reference warm repeat | 36.2 | 247.8 | 40.1 | 99.4 | 28 / 37 |
| Indexed warm repeat | 40.7 | 280.8 | 35.9 | 104.5 | 48 / 52 |

Single runs, not statistical confidence intervals. Cold means a fresh fine-chunk
namespace; repeated/revisited chunks can hit cache during that run. Warm means
reusing its own variant's cold cache, not a fully cached or identical trajectory.
Coarse cache and startup are outside the timed driving window. Faster travel
reaches new chunks. Both variants were speed-limited throughout; neither entered
the streaming suspension state during measurement.

All reports and screenshots saved. The indexed warm process subsequently exited
with Windows access violation -1073741819 during shutdown. Cause is unresolved;
its completed measurements are retained with this caveat. The other driving
runs, final headless regression and expanded scene regression exited normally.

## What the profiling says

Cold driving worker averages (different visited chunk sets):

| Stage | Reference ms | Indexed ms |
|---|---:|---:|
| Scalar grid sampling | 349 | 359 |
| Triangulation | 141 | 48 |
| Normal calculation | 1213 | 220 |
| Main-thread upload call | 0.97 | 0.56 |
| Main-thread collision creation | 8.87 | 9.06 |
| Total main-thread installation | 10.24 | 10.01 |

Redundant normals dominated generation. Indexing addresses that without reducing
quality. Collision construction still dominates measured installation and can
exceed the existing soft 5 ms budget in one indivisible call. Warm indexed average
collision creation was 7.23 ms, maximum 14.41 ms. Hitches are not solved.
Upload call timing is CPU elapsed time, not GPU work timing. Deferred physics,
resource destruction, rendering and other costs may land in subsequent frames;
these timings do not prove the cause of every worst frame.

Next priorities: inspect collision construction/activation and the streaming
look-ahead versus stopping-distance policy; then optimise remaining field
evaluation. Evaluate native meshing and proper LOD transitions against this
baseline. Do not add workers indiscriminately or assume a warmed disk cache
removes installation cost. No new precaching scheduler or physics simplification
is included in this change.

## Reproduction

Run from the project root using the local Godot executable:

```powershell
& 'C:\Godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path .\game --script res://benchmarks/check_tetra_mesher.gd
& 'C:\Godot\Godot_v4.5.1-stable_win64_console.exe' --path .\game --rendering-method gl_compatibility --resolution 960x600 res://benchmarks/streaming_profile.tscn -- --terrain-profile --profile-cache=NEW-TRIAL --profile-label=cold --profile-seconds=20
```

Add `--mesher-legacy` for reference. Run variants sequentially, each cold then warm
with its same namespace and `--profile-label=warm`. Use a fresh namespace for a
new cold trial. Labels alone do not clear caches. Outputs are
`user://streaming-{indexed|legacy}-{label}.json` and `.png`; the microbenchmark
writes `user://tetra-mesher-profile.json`. The workspace outputs folder includes
a PowerShell launcher which copies fresh reports there automatically.

Cache schema 2 stores optional indices. Cache keys include recipe, mesher source,
engine and legacy flag. Old cache entries remain intact but are not selected.
Only array/file work occurs on meshing workers; GPU and collision installation
stay on the main thread. Existing raw-image export and GLTF material warnings
remain separate follow-up issues.
