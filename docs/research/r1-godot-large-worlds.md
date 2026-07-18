# R1 — Godot Large-Coordinate Limits (2026-07-18)

**Question:** where does float precision break in Godot 4, does double precision work for us, and what does that force on ring dimensions (D2) and the terrain data model (D3)?

## Findings

**Single-precision comfort zone is ~2–4 km for a first-person game.** The official docs' precision table puts FPS-scale degradation (visible jitter on meshes/camera) beyond 2,048–4,096 m from origin, with step error growing steadily after that. Even the proposed 10 km ring *width* blows past it, never mind circumference.

**Double-precision builds are the wrong tool for this project.**
- Not in official builds — requires a custom engine compile (`precision=double`), which we'd be maintaining forever against the potato target.
- Docs explicitly say the feature is "tailored towards mid-range/high-end desktop platforms" with a performance and memory penalty — the opposite of Intel UHD.
- The rendering-side double emulation is shader-based and its Compatibility-renderer support is undocumented; the reference material centers on Vulkan.

**Verdict: floating origin / origin shifting is effectively mandatory.** This independently confirms the April brainstorm's "absolute position is fake" principle — it wasn't optional cleverness, it's forced by the engine at our scale on our hardware. World-space stays logical (lat/lon-style ring coordinates as the brainstorm proposed); render/physics space is a local frame that re-centers as players move.

## Consequences for open decisions

- **D2 (ring dimensions):** engine precision no longer constrains ring size — circumference can be whatever the design wants, since nothing ever lives far from a shifted origin. The remaining constraints on D2 are purely design-side (walk-time feel, curve visibility).
- **D3 (terrain data model):** chunk realization must key off logical ring coordinates, not engine world coordinates. Deterministic per-chunk generation (already the pattern for ancient structures) survives origin shifts for free; anything caching engine-space positions does not.
- **D5 (co-op):** big one — split-screen shares ONE origin. If both players are within a few km of each other, one shared shifted origin works. If they can diverge across the ring, we need either a tether (classic couch co-op behavior anyway) or per-viewport origin offsets (custom rendering complexity). The tether is probably the design answer, but it must be a *chosen* constraint, not an accident.
- **Skybox/manifold lesson (docs/world.md):** origin shifts move the far clip boundary relative to sky geometry — the April clipping bug class will resurface at every shift boundary if sky isn't camera-locked. Test explicitly.

## Sources

- [Large world coordinates — Godot docs](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html) — precision table, double-precision caveats, origin-shifting note
- [Emulating Double Precision on the GPU — Godot Engine blog](https://godotengine.org/article/emulating-double-precision-gpu-render-large-worlds/)
- [Frozen Fractal — Floating the origin](https://frozenfractal.com/blog/2024/4/11/around-the-world-14-floating-the-origin/) — practical floating-origin writeup
- [godot#58516 — jitter far from origin even with float=64](https://github.com/godotengine/godot/issues/58516)
- [Terrain3D double-precision notes](https://terrain3d.readthedocs.io/en/stable/docs/double_precision.html)
