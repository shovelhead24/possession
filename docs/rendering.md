# Possession — Rendering

GL Compatibility (OpenGL 3.3) on Intel UHD is the hard floor. Every rendering ambition gets tested against it.

## What Exists

- Terrain shader: height-based grass/stone/snow/sand blending, cliff overlay, fog
- Cloud/sky system (built April, post-GSD, never documented): marching-cubes clouds with LOD, three cloud types, weather presets, day/night brightness, sunset scatter (`cloud_system.gd`, `sky_shader.gdshader`, `cloud_*_shader.gdshader`)
- Lighting test scene with CSV metric logging (`lighting_test.tscn`, `lighting_test_controller.gd`) — was made the default scene during the April lighting work
- Day/night cycle

## Constraints of GL Compatibility (plan around these)

- No compute shaders, no Forward+ clustering — light count and technique ceilings are low
- Shadows are expensive on Intel UHD; April work already disabled shadows at LOD1+ and went unshaded at LOD3+
- Alpha handling: cloud shaders use alpha hash for a reason — sorting is a trap

## Open Questions

- **Ring curvature** (issue #2) — vertex bend vs real geometry vs skybox impostor past playable range; where the seam sits; night-side cities of Moment 7
- **Performance budget** (issue #8) — no defined FPS target or benchmark scene yet; split-screen co-op means budgeting two viewports from day one
- **Fog strategy** — historically used to hide the streaming edge; ring curvature changes what "the horizon" even is
- **Snow blend mechanism** (issue #5) — old unfixed bug, thresholds have drifted since; make the mechanism trustworthy before tuning values

## Hard Lessons

- Skybox geometry clipping at view-distance boundary produces artifacts indistinguishable from z-fighting — was actually manifold/clip errors. Stitching skybox edges nearly broke us. Re-verify whenever view distance or sky geometry changes.
- `reload_current_scene()` leaves stale GDScript statics — reload is always full quit + relaunch (see `.decisions/engine.md`).
