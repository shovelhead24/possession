# Possession — Terrain & Landscape

The highest-stakes system in the game. Plan before prototyping; naive code only until the plan survives contact. Tracking issue: [#1](https://github.com/shovelhead24/possession/issues/1).

## What Exists (April 2026 code, working)

- Chunked procedural terrain (`terrain_manager.gd`, `terrain_chunk.gd`) — noise-based, LOD-banded, distance-tuned (numbers deliberately not recorded here — they're tuning, not decisions)
- Biome definitions with per-biome noise traits (`biome_definitions.gd`) — 7 types defined, River Valley is the tuned one
- Height/smooth/flatten/grass editor brushes over per-vertex offsets (`editor_controller.gd`)
- Deterministic ancient structures per chunk (`ancient_structures.gd`)
- Object-pooled props at near LODs (`prop_pool.gd`)
- Terrain shader blending grass/stone/snow/sand by world height (`terrain_shader.gdshader`)

## Open Questions (the planning pass must answer)

- **Ring dimensions** — playable width and circumference in km. Everything downstream needs this number.
- **Terrain data model** — pure procedural + edit overlays (current), heightmap tiles, or hybrid? Gates undo/persistence/biome-paint (issue #7).
- **Ring topology** — does the world wrap? Is "walk the full circumference" a real goal or an illusion past some range?
- **Explorability constraint** — "if you can see it you can reach it" implies slope limits, traversal mechanics (hookshot?), or both. What enforces it?
- **Water** — rivers/lakes/coastline were explicitly deferred in April. Where do they enter?
- **Authored vs procedural** — settlements, the relay, the crash site are story-placed. How do authored landmarks compose with procgen?
- **Streaming under the landing sequence** — Moment 1 free-falls the camera through every LOD band in seconds (issue #4).
- **Collision policy at distance** — full collision near, none far; where's the line and what happens to AI/vehicles there?

## Constraints (fixed, from vision)

- Fully explorable. Potato hardware. Scale without fanfare. Couch co-op (two camera positions streaming at once — issue #3).
