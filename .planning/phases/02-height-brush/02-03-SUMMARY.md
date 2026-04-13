---
phase: 02-height-brush
plan: "03"
subsystem: terrain
tags: [terrain, height-brush, mesh-rebuild, dirty-chunks, editor]
dependency_graph:
  requires: [height_offsets-storage, apply_height_brush-api, brush-input-wiring]
  provides: [rebuild_mesh-helper, dirty-chunk-flush, brush-visible-deformation]
  affects: [game/terrain_chunk.gd, game/editor_controller.gd]
tech_stack:
  added: []
  patterns: [per-frame dirty-set deduplication, queue_free + regenerate teardown pattern]
key_files:
  created: []
  modified:
    - game/terrain_chunk.gd
    - game/editor_controller.gd
decisions:
  - "rebuild_mesh() also tears down collision_body (not just mesh_instance) because generate_terrain() recreates it for LOD0-1 — omitting this would leak StaticBody3D nodes on every brush stroke"
  - "Props deliberately NOT torn down in rebuild_mesh() — brush rebuilds are too frequent; prop repositioning deferred to Phase 3+"
  - "_frame_dirty uses Dictionary (Vector2i -> true) for O(1) dedup; cleared after flush each frame"
  - "_flush_dirty_chunks() uses chunk.has_method('rebuild_mesh') guard for forward compatibility"
metrics:
  duration_minutes: 10
  completed_date: "2026-04-13"
  tasks_completed: 2
  tasks_total: 3
  files_modified: 2
---

# Phase 2 Plan 3: Dirty Chunk Rebuild Summary

**One-liner:** TerrainChunk.rebuild_mesh() tears down stale mesh+collision and regenerates; EditorController flushes a per-frame deduped dirty set after each brush tick to make height painting visibly deform terrain.

## What Was Built

### Task 1 — TerrainChunk.rebuild_mesh() (commit `5d75548`)

Added to `game/terrain_chunk.gd` (before `generate_terrain()`):

```gdscript
func rebuild_mesh() -> void:
    if mesh_instance and is_instance_valid(mesh_instance):
        mesh_instance.queue_free()
        mesh_instance = null
    if collision_body and is_instance_valid(collision_body):
        collision_body.queue_free()
        collision_body = null
    generate_terrain()
```

Key decision: collision_body is also removed before calling `generate_terrain()`, which recreates it for LOD0-1. Without this, each brush stroke on LOD0-1 chunks would leak a StaticBody3D node. The plan template only mentioned `mesh_instance`, but reading `generate_terrain()` (line 562) confirmed it unconditionally creates a new `collision_body` when `has_collision` is true — so teardown of both was required (Rule 2: missing critical cleanup = correctness requirement).

Props are deliberately untouched. Brush rebuilds happen every frame while holding a button; re-spawning props at that frequency would be prohibitively expensive and they would visually snap around. This is a known limitation documented below.

### Task 2 — _rebuild_dirty_chunks stub replaced + _flush_dirty_chunks added (commit `022e9cb`)

Modified `game/editor_controller.gd`:

**New state var** (after `terrain_manager`):
```gdscript
var _frame_dirty: Dictionary = {}  # Vector2i -> true, deduped across one frame
```

**`_rebuild_dirty_chunks` (stub → real)**:
```gdscript
func _rebuild_dirty_chunks(dirty: Array) -> void:
    for c in dirty:
        _frame_dirty[c] = true
```

**`_flush_dirty_chunks()` (new)**:
```gdscript
func _flush_dirty_chunks() -> void:
    if _frame_dirty.is_empty() or terrain_manager == null:
        return
    for coord in _frame_dirty.keys():
        if not terrain_manager.chunks.has(coord):
            continue
        var chunk = terrain_manager.chunks[coord]
        if chunk and chunk.has_method("rebuild_mesh"):
            chunk.rebuild_mesh()
    _frame_dirty.clear()
```

**`_process()` addition** (after `_tick_brush(delta)`):
```gdscript
_flush_dirty_chunks()
```

The deduplication means: if the brush overlaps 3 chunks and the cursor moves slightly within those same 3 chunks in one frame, each chunk is rebuilt exactly once regardless of how many dirty entries were accumulated.

## Decisions Made

- **collision_body teardown added** — not in the plan template, but required for correctness: `generate_terrain()` always creates a new StaticBody3D for LOD0-1. Without removing the old one, each brush stroke leaks a collision node. Treated as Rule 2 (missing critical cleanup).
- **Props not torn down** — per plan directive. Existing props will sit at incorrect heights after a brush stroke but this is accepted for Phase 2. Phase 3+ concern.
- **`has_method("rebuild_mesh")` guard** — defensive check ensures no crash if a chunk ref is stale or from an older scene without the new method.

## Deviations from Plan

### Auto-added: collision_body teardown in rebuild_mesh()

- **Found during:** Task 1
- **Issue:** Plan template only showed `mesh_instance` teardown, but `generate_terrain()` unconditionally creates a new `collision_body` for LOD0-1 (confirmed at line 562). Without removing the old one, every brush stroke on close chunks leaks a StaticBody3D.
- **Fix:** Added `collision_body.queue_free(); collision_body = null` block to `rebuild_mesh()` before calling `generate_terrain()`.
- **Files modified:** game/terrain_chunk.gd
- **Commit:** 5d75548

## Known Limitations

- **Props at wrong height after brush stroke** — Existing trees/grass props are placed by world position and do not follow terrain deformation. After painting a hill under props, the props float or sink. Repositioning props on rebuild is deferred to Phase 3+.

## Known Stubs

None. The brush pipeline is now end-to-end: input → offset mutation → dirty tracking → per-frame mesh rebuild.

Task 3 is a `checkpoint:human-verify` UAT gate — UAT not yet performed. Plan is paused at the checkpoint.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries.

## Self-Check: PASSED

- `game/terrain_chunk.gd` — `func rebuild_mesh` present at line 226
- `game/editor_controller.gd` — `_frame_dirty`, `_flush_dirty_chunks`, `chunk.rebuild_mesh()`, `_frame_dirty[c] = true` all present
- Commit `5d75548` — verified in git log
- Commit `022e9cb` — verified in git log
