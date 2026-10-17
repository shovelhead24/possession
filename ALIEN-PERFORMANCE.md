# Alien shadows and performance review — 11 October 2026

Available through the existing Rebuild Demo desktop shortcut. Player saves are unchanged.

## Changes

- Nearby animated alien bodies now cast sun shadows. Casters turn on within 65 m and off beyond 75 m, with hysteresis to prevent toggling at the boundary. Small rifle parts do not cast separate shadows. The existing daylight switch and sun shadow range still apply. Editor flight updates caster distance even while gameplay is paused.
- Each rifle previously used seven separate skinned mesh instances. They now form one skinned mesh with three surfaces, retaining the original three materials, all 756 triangles, skin weights, bind poses and animations. Body and rifle remain separate so fleeing/dead aliens can hide their guns.
- Collision capsule dimensions and transforms now update only when standing, crouching or diving changes the stance. Repeated unchanged updates no longer rebuild the capsule.
- Gun visibility is changed only when fleeing state changes.
- F8 now includes actor, movement collision, pathfinding, sight and animation counters, plus capsule-change and shadow-caster counts. Counters are cumulative for the currently resident units; unloading units changes that population, so do not difference them across population changes without accounting for that.
- Loading-screen briefing updated and visually verified.

## Rendering evidence

Isolated ten-alien scene, identical camera and floor:

| Configuration | Draw calls |
|---|---:|
| Original meshes, shadows off | 103 |
| Batched rifles, shadows off | 63 |
| Original meshes, body shadows on | 115 |
| Batched rifles, body shadows on | 75 |

The shadowed new setup uses 28 fewer calls than the original setup without shadows. This is a reliable structural reduction; it is not a claim of an equivalent percentage FPS gain. Isolated shadowed rendering measured about 7.05 ms versus 7.17 ms before batching, too small a difference to claim a reliable timing improvement from these short runs. Unshadowed timing varied more. Full-world patrol samples landed around 91–93 FPS with shadows, compared with about 87 FPS in the earlier unshadowed iteration, but separate-run variation prevents attributing that entire difference to the changes.

## Final saved-world profile

Intel UHD Graphics, Godot 4.5.1 Compatibility, 1366 x 749, uncapped, vsync disabled. Each sample contains 240 frames after a two-second warmup. Terrain, trees and construction used isolated copies. The combat fixture grants test-only extra health to keep defeat and respawn from changing the view; normal gameplay remains 100 HP.

| View / state | Mean ms | FPS |
|---|---:|---:|
| Patrol view, enemies hidden and paused | 10.09 | 99.1 |
| Ten patrol enemies, body shadows enabled | 10.94 | 91.4 |
| Frozen enemies, shadows enabled | 10.46 | 95.6 |
| Same frozen pose, shadows disabled | 10.48 | 95.4 |
| Foot view, enemies hidden and paused | 13.88 | 72.0 |
| Continuous combat, shadows enabled | 16.01 | 62.4 |
| Foot baseline repeated | 13.84 | 72.2 |
| Same foot baseline, tree rendering/proxies hidden | 8.89 | 112.5 |

The frozen shadow toggle was within measurement noise. The full combat sample varied from roughly 62 to 69 FPS across runs. Neither it nor the baseline reaches 120 FPS. These stationary samples are not a driving-route or long battle stress test.

## What the enemy code costs

CPU totals per rendered frame, summed over the ten resident actors:

| Component | Patrol | Combat |
|---|---:|---:|
| Actor update total | 1.039 ms | 1.850 ms |
| Movement collision, included in actor total | 0.360 ms | 0.701 ms |
| Path requests, included in actor total | 0.003 ms | 0.004 ms |
| Sight calls, may also be invoked by squad sensing | 0.001 ms | 0.008 ms |
| Animation advance, separate from actor total | 0.058 ms | 0.087 ms |

The rig-scale animation multiplier runs during cached rig preparation, not every frame. It is not the hot path. Path requests also are not the main cost in these samples. The remaining actor total includes steering, collision feelers, ring-coordinate work, state selection, separation and combat logic. Movement collision is the largest individually measured enemy subcomponent. Timers measure CPU work, not asynchronous GPU execution; do not add these numbers to frame time as independent costs.

Unchanged patrol stance produced zero capsule changes during the sample. Combat changed stance only as needed. Physics and combat still run at their original frequency; no behavior was removed or slowed to obtain the rendering reduction.

## Next optimization priorities

1. Close foliage rendering and tree-shadow proxies: hiding their rendering together saved about 4.96 ms in the same foot view, with their CPU processing still enabled. This strongly motivates separating leaf-card overdraw, mesh LOD and shadow-proxy costs next. The test does not distinguish those three costs by itself. Trees remain fully enabled in the playable build.
2. Enemy steering/collision work: roughly 0.7 ms of the combat actor total is move-and-slide. Profile feelers and remaining state calculations before reducing update frequency; retain physical collision and combat responsiveness.
3. Further material/draw consolidation or nearer label culling can reduce remaining submissions, but should be weighed against visual quality. Animation and pathfinding are lower priorities based on these measurements.

## Validation

Passed tactical core and rendered saved-world integration. Additional assertions check two mesh instances per alien, three rifle materials, 756 preserved rifle triangles and skin weights, body-shadow distance switching, editor-camera shadow updates, and unchanged-stance capsule stability. Existing checks cover all 14 clips, rig scale, patrol memory, vision, captain dive, morale, projectile obstruction, grenades, ragdolls, casualty persistence, respawn and HUD/FPS behavior.

Visually reviewed the actual loading screen, full-world alien shadows and isolated shadow screenshot. Existing Warthog material-conversion warnings remain; final runs have no script errors. No player save files were used by tests.
