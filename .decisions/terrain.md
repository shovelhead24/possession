# Terrain / World Bake

### bake-architecture — Prebaked layered world; recipe is source, bake is artifact
**Date:** 2026-07-19
**Status:** active
**Decision:** The world is prebaked, not runtime-generated (supersedes the April brainstorm's "no baked worlds" — that rule was scale-dependent and died with the 2,000 km decision). Architecture: layered bake DAG (L0 builders' shape → L7 hand edits) of pure functions with content-addressed caching; per-region compose parameter overrides; coherence via per-layer contracts + bake gates (non-negotiables as computable tests, e.g. see-it-reach-it); runtime adds only bounded detail octaves + deterministic scatter from baked density fields — instances are never data. Git versions generator code + seed + edit deltas; the binary bake is a reproducible build artifact, never committed. Substrate policy: generous interfaces, naive engines — coordinate/tiling scheme and additive-only field registry (LayerBuf) are the over-engineered frozen parts; layer implementations stay naive. Details: docs/terrain.md, docs/terrain/layerbuf-v0.md.
**Why:** Collapses runtime cost on potato hardware (bitmap sample beats noise stack, flat cost), makes authored moment sites edits-to-data rather than procgen coaxing, gives determinism and debuggability (layer bisection), and fits solo+AI development — cheap subagents iterate layer code against hard gates offline. Resolutions, layer count evolution, and all tuning values deliberately unrecorded.

### render-authoritative-placement — Objects/physics sample the SAME height the render uses at that location
**Date:** 2026-07-26
**Status:** active
**Decision:** Anything positioned on the terrain (player, vehicles, creatures, scattered props, physics) must derive its ground height from the *same representation the renderer draws at that location* — either by raycasting onto the actual rendered mesh, or by sampling the exact LOD level being rendered there — never from a separate finer/analytic height function that the render only approximates. Moving things raycast per-frame; static scatter raycasts (or biases) once at build.
**Why:** Terrain will be rendered at continuous distance-based LOD (the render resolution changes everywhere, all the time). If placement reads a finer source than the render, objects sink below or float above the drawn surface — proven concretely in the slice mock, where trees placed on the fine function were buried under the coarser render mesh and the player walked *under* the visible ground ("invisible floor"). With LOD this mismatch is the default state, not an edge case, so placement must be render-authoritative by rule.

### terrain-lod-direction — Camera-relative continuous LOD with seamless transitions (PROPOSED)
**Date:** 2026-07-26
**Status:** proposed (approach not yet chosen)
**Decision:** The real terrain needs camera-relative, continuous LOD — clipmap (concentric sliding resolution rings) or distance-driven quadtree — with crack-free transitions between levels (shared edge verts or skirts). Not the mock's fixed fine-centre/coarse-flank tiers (world-stuck, hard seam). Clipmap-vs-quadtree is open. Ties to the substrate resolution pyramid (docs/terrain/substrate.md) and R2 curvature (docs/research/r2-ring-curvature.md). The `game/mocks/ring_vibes` mock is the working basis for prototyping this — preserved on the `terrain-lod` branch.
**Why:** Fine detail near the camera, cheap far, following the player — the standard requirement for a walkable world at ring scale on potato hardware. Recorded now because the mock surfaced the requirement concretely; the specific technique is a real implementation-pass decision, deliberately left open.
