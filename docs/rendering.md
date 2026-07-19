# Possession — Rendering

GL Compatibility (OpenGL 3.3) on Intel UHD is the hard floor. Every rendering ambition gets tested against it.

## What Exists

- Terrain shader: height-based grass/stone/snow/sand blending, cliff overlay, fog
- Cloud/sky system (built April, post-GSD, never documented): marching-cubes clouds with LOD, three cloud types, weather presets, day/night brightness, sunset scatter (`cloud_system.gd`, `sky_shader.gdshader`, `cloud_*_shader.gdshader`)
- Lighting test scene with CSV metric logging (`lighting_test.tscn`, `lighting_test_controller.gd`) — was made the default scene during the April lighting work
- Day/night cycle

## Texture Fidelity Baseline — DECIDED 2026-07-23

Deliberately ~2001 / Halo CE class (`.decisions/rendering.md#texture-fidelity-baseline`): coarse readable albedo, strong silhouettes, Frutiger-Aero accents on high-importance objects. Modern budget buys draw distance, honest ring geometry, and atmosphere — never texel density. Same scoped-resolution logic as the simulation, applied to pixels.

## Constraints of GL Compatibility (plan around these)

- No compute shaders, no Forward+ clustering — light count and technique ceilings are low
- Shadows are expensive on Intel UHD; April work already disabled shadows at LOD1+ and went unshaded at LOD3+
- Alpha handling: cloud shaders use alpha hash for a reason — sorting is a trap

## Open Questions

- **Ring curvature** (issue #2, D4) — not single-technique per [research/r2-ring-curvature.md](research/r2-ring-curvature.md): real arc-displaced terrain mesh near-field (ties to substrate's ring-arc coordinates), painted/impostor far-field (Tier 0 static-signal rule covers it), haze-based seam between them. Vertex-bend shaders ruled out as the seam technique — no positional truth, and the April manifold/z-fighting lesson lives exactly at that kind of boundary. GL Compat is not a blocker (vertex displacement is core). Night-side cities of Moment 7 land in the far-field impostor layer.
- **Performance budget** (issue #8) — no defined FPS target or benchmark scene yet; split-screen co-op means budgeting two viewports from day one
- **Fog/haze strategy** — historically a perf trick to hide the streaming edge; now a design material with three jobs: on a ring interior there is no horizon, *the air is the horizon* (knowledge.md — haze gates distance knowledge, night lights punch through), it stays the perf budget's best friend, and it's the tuning surface for D4 curve rendering (how much upcurve through how much air = vibes × framerate). The #9 mocks should treat haze as a first-class variable, not an afterthought
- **Snow blend mechanism** (issue #5) — old unfixed bug, thresholds have drifted since; make the mechanism trustworthy before tuning values

## Hard Lessons

- Skybox geometry clipping at view-distance boundary produces artifacts indistinguishable from z-fighting — was actually manifold/clip errors. Stitching skybox edges nearly broke us. Re-verify whenever view distance or sky geometry changes.
- `reload_current_scene()` leaves stale GDScript statics — reload is always full quit + relaunch (see `.decisions/engine.md`).
