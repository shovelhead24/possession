# Phase 2: Height Brush (Raise/Lower) - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a terrain height-editing brush to editor mode. The user can raise or lower terrain by clicking in editor mode, with adjustable brush radius and optional strength boost. Changes are stored as per-vertex height offsets that persist on top of procedural generation. Affected chunks rebuild their meshes on demand.

This phase does NOT include: smooth/flatten brush modes (Phase 3), undo/redo (Phase 4), save/load persistence (Phase 5), or a toolbar/HUD brush selector (Phase 3).

</domain>

<decisions>
## Implementation Decisions

### Offset Storage
- **D-01:** Per-vertex height offsets. Each chunk stores a `PackedFloat32Array` of height deltas, one per vertex position (matching the vertex grid used in `generate_terrain()`). Applied additively to procedural heights inside `terrain_manager.get_height_at_position()` (or injected at chunk level via `get_height_at_world_pos()`).
- **Rationale:** Per-chunk scalar would be too coarse (chunks are 100m wide — unusable for terrain sculpting). Per-vertex storage is ~1.1KB per chunk, ~280KB for all loaded chunks — negligible on any hardware.

### Brush Controls
- **D-02:** Left click = raise terrain. Right click = lower terrain.
- **D-03:** Scroll wheel = resize brush radius. (Scroll is unbound in editor mode currently.)
- **D-04:** Hold R while clicking = boost brush strength 2×. (R is free in editor mode; Shift and Ctrl are taken by orbit/pan.)

### Brush Falloff Modes
- **D-05:** Three falloff shapes implemented, cycled with a dedicated key (e.g. `F` key or another free key):
  - **Gaussian** (default) — bell-curve falloff using `exp(-dist²/sigma²)`, natural-looking mounds/valleys
  - **Linear** — strength decreases linearly from center to edge, slightly conical
  - **Hard-edged** — uniform strength across full radius, drops to zero at edge
- **D-06:** Default falloff on Phase 2 launch: Gaussian.
- **Note:** No toolbar/HUD falloff selector in Phase 2 — that's Phase 3. This phase just implements the underlying modes and a cycle key.

### Brush Cursor Visual
- **D-07:** A projected circle ring on the terrain surface, following the cursor and scaling with brush radius. Implemented as a thin flat cylinder mesh (or a decal) positioned at the raycast hit point. Updates every frame in editor mode when brush is active.

### Chunk Rebuild Strategy
- **D-08:** Dirty-flag affected chunks on each brush stroke event. Rebuild only dirty chunks. "Affected" = chunks whose vertex grid overlaps the brush circle (a brush stroke can touch up to 4 chunks at once at chunk boundaries).
- **D-09:** Rebuild is immediate on brush stroke (not debounced). Godot's mesh generation at LOD0 is fast enough for interactive rates.

### Shader Parameter Propagation
- **D-10:** Rebuilt chunks call `generate_terrain()` again which already sets all shader parameters (snow thresholds, grass heights, etc.) — no special handling needed. This is already correct by architecture.

### Claude's Discretion
- Default brush radius (suggest ~10–20m world units)
- Base raise/lower speed constant (height units per second while held)
- Scroll sensitivity for radius adjustment
- Which key cycles falloff mode (F is suggested but planner can pick any free key)
- Whether cursor ring is a full mesh or a shader-based decal

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above.

### Key files to read before planning/implementing
- `game/editor_controller.gd` — EditorController autoload: existing cursor raycast (`_get_terrain_cursor_world_pos()`), input handling, camera state. Brush input and cursor visual extend this file.
- `game/terrain_manager.gd` — `get_height_at_position()` is where height offsets must be injected. `chunks` dictionary maps `Vector2i` coords to `TerrainChunk` nodes.
- `game/terrain_chunk.gd` — `generate_terrain()` builds the mesh (vertex loop, `get_height_at_world_pos()` calls). `set_lod()` triggers a full rebuild. Height offset array stored here, applied in `get_height_at_world_pos()`.
- `.planning/phases/01-editor-mode-infrastructure/01-CONTEXT.md` — Phase 1 decisions (key bindings, camera controls, EditorController architecture)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `editor_controller._get_terrain_cursor_world_pos()` — raycast that returns `Vector3` world position under cursor (or null). Brush position sampling uses this directly, no new raycast needed.
- `terrain_chunk.lod_resolutions = [16, 6, 3, 2]` — vertex grid is `(resolution+1)²` per LOD. Per-vertex array size = `(resolution+1)²`. For LOD0: 17×17 = 289 entries.
- Gaussian math pattern already in codebase: `exp(-(dx² + dz²) / (2 * sigma²))` — used in `terrain_manager.get_noise_height_at_position()` for peak amplifier. Brush falloff reuses same formula.

### Established Patterns
- EditorController owns all editor input — brush input goes here (D-12 from Phase 1)
- Boolean mode flags on EditorController (`is_editor_active`) — brush active only when `is_editor_active == true`
- `terrain_manager.chunks: Dictionary` maps `Vector2i` coords → `TerrainChunk` — iterate this to find dirty chunks
- `terrain_chunk.set_lod(current_lod)` triggers a mesh rebuild — call this on dirty chunks to rebuild after stroke

### Integration Points
- `editor_controller.gd` `_input()` / `_process()` — brush events (mouse button, scroll) handled here
- `terrain_chunk.gd` `get_height_at_world_pos()` — add offset lookup here before returning height
- `terrain_manager.gd` `get_height_at_position()` — alternative injection point (may be cleaner for cross-chunk consistency)
- `editor_controller.gd` `_process()` — cursor ring visual update goes here alongside `_update_hud()`

</code_context>

<specifics>
## Specific Ideas

- User wants a full terrain editor eventually (terrain, biomes, props, vehicles, triggers, sounds, paths). The height brush is the first "real" tool — it should feel responsive and natural, not sluggish.
- Long-term vision: a "build tool that allows configuring the game world while preserving memory compression afforded by procedural generation."
- Per-vertex storage must be designed to survive Phase 5 (save/load) — `PackedFloat32Array` serialises cleanly to JSON as a base64 blob or array of floats.

</specifics>

<deferred>
## Deferred Ideas

- **Toolbar / HUD brush selector** — Phase 3 (brush mode selector and visual mode indicator are already planned there)
- **Smooth brush** — Phase 3
- **Flatten brush** — Phase 3
- **Undo/redo** — Phase 4
- **Save/load terrain edits** — Phase 5
- **Biome paint** — Phase 6

</deferred>

---

*Phase: 02-height-brush*
*Context gathered: 2026-04-13*
