# Possession — Terrain & Landscape

The highest-stakes system in the game. Plan before prototyping; naive code only until the plan survives contact. Tracking issue: [#1](https://github.com/shovelhead24/possession/issues/1).

## What Exists (April 2026 code, working)

- Chunked procedural terrain (`terrain_manager.gd`, `terrain_chunk.gd`) — noise-based, LOD-banded, distance-tuned (numbers deliberately not recorded here — they're tuning, not decisions)
- Biome definitions with per-biome noise traits (`biome_definitions.gd`) — 7 types defined, River Valley is the tuned one
- Height/smooth/flatten/grass editor brushes over per-vertex offsets (`editor_controller.gd`)
- Deterministic ancient structures per chunk (`ancient_structures.gd`)
- Object-pooled props at near LODs (`prop_pool.gd`)
- Terrain shader blending grass/stone/snow/sand by world height (`terrain_shader.gdshader`)

## Bake Pipeline — PROPOSED (D3 sketch, 2026-07-18)

Prebaked world (settled direction from the brief session): **bake = build artifact, recipe = source.** Git versions generator code + seed + hand-edit deltas; the binary bake is reproducible and never committed.

**Layered bake DAG** — layers mirror the fiction (builders → nature → civilization → you), each a pure function of upstream outputs + seed + params:

| Layer | Pass | Establishes |
|---|---|---|
| L0 | Builders' shape: shell, walls, macro-terrain | the designed ring |
| L1 | Hydrology/erosion: rainfall → flow → carve/fill | every drop has a destination |
| L2 | Climate: altitude, water, wall shadow, spinward wind | temperature/moisture fields |
| L3 | Biomes: classify climate × soil × slope | legal biome adjacency |
| L4 | Scatter density fields (never instances) | vegetation/rock/fauna weights |
| L5 | Civilization: settlements → pathfound roads → history/ruins | inhabited, plausible geography |
| L6 | Narrative anchors: 12 moment sites as constraints (some push upstream) | authored sites hold |
| L7 | Hand-edit overlays (the April brush editor is this layer) | art direction |

- **Content-addressed caching:** hash layer inputs → only downstream of a change rebakes. Layer bisection localizes artifacts to the pass that made them.
- **Per-region compose files:** regions override layer *params* (arid here, dense settlement there) over shared layer code.

**Coherence = contracts + bake gates, not review:** each layer declares pre/postconditions and preserved invariants; validators run per-layer at bake time and fail with coordinates + a debug map. Cross-layer gates on the final artifact turn non-negotiables into computable tests: "see it → reach it" (vista sampling vs navmesh), settlement-graph connectivity, moment-site preconditions, slope/road-grade/ford legality. The runtime detail octave gets an amplitude budget so synthesized detail can't violate baked contracts.

**Substrate & latitude policy — "generous interfaces, naive engines":** the expensive back-propagation isn't implementation changes (one rebake + golden-seed diff), it's interface changes. So over-engineer only the invariants:
1. **Coordinate/tiling substrate** (beneath L0, frozen early): ring lon/lat convention, the 2,000 km wrap seam, tile addressing, resolution pyramid supporting mixed res from day one (regional high-res insertable later without re-addressing).
2. **Field registry, additive-only evolution:** layers emit named raster fields (units + metadata); downstream declares consumption; adding fields is non-breaking by construction, removing/retyping is a versioned migration.
3. **Byproduct hoarding:** L1/L2 emit maps the sims already compute even if unconsumed (flow accumulation, sediment, water table, wind exposure, wall-shadow hours) — future layers get them free; adding them later = code + full rebake.
4. **Spatially-variable params are maps** with constant defaults, so compose overrides/authored inputs can drive them without code changes.
5. **Determinism contract fixed once:** hierarchical seeds per layer/tile → independent, parallel tile bakes.

Nested-sandbox view (each level can't break the one beneath): substrate → layer protocol → layer params/maps → regional compose → hand-edit overlay. Engine implementations stay deliberately naive; latitude lives in interfaces, and the cache + golden-seed diff make unforeseen bottom-layer changes survivable rather than requiring prophecy.

**Detail sub-docs:** [terrain/layerbuf-v0.md](terrain/layerbuf-v0.md) — field registry draft (per-layer emitted fields, params, syncopation cascade examples). Next: `terrain/substrate.md` (ring coords, tile addressing, resolution pyramid). See also [cost-ledger.md](cost-ledger.md) — function-class/cost-regime index over these same layers, for spotting shared-cost optimizations the field registry alone doesn't show.

**Verification ladder (in place of formal proof):** bake gates every bake → property tests across N random seeds nightly (low-res) → golden-seed layer-hash regression (silent world changes become visible diffs). Formal proof (Lean) evaluated and scoped out: it would verify a hand-maintained model, not the shipping code, and finite artifact-checking answers the actual question. Sole candidate if ever revisited: the ring-coordinate wrap/origin-shift math module. The gate suite is also what makes cheap-subagent layer code safe to accept.

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
