---
phase: 02-height-brush
plan: "03"
status: complete
date: 2026-04-13
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
commits:
  - 5d75548  feat(02-03): add TerrainChunk.rebuild_mesh() — tears down stale mesh/collision and regenerates
  - 022e9cb  feat(02-03): replace _rebuild_dirty_chunks stub with per-frame dedupe flush via rebuild_mesh
  - 14fc760  fix(02-03): reset editor camera to overhead angle and ground-level focus on entry
  - 58bdbcb  fix(02-03): hide player HUD on editor entry, restore on exit
metrics:
  duration_minutes: 25
  completed_date: "2026-04-13"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 2
---

# Phase 2 Plan 3: Dirty Chunk Rebuild Summary

**One-liner:** TerrainChunk.rebuild_mesh() tears down stale mesh+collision and regenerates; EditorController flushes a per-frame deduped dirty set after each brush tick to make height painting visibly deform terrain.

## What Was Built

### Task 1 — TerrainChunk.rebuild_mesh() (commit `5d75548`)

Added to `game/terrain_chunk.gd`:

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

Key decision: collision_body is also removed before calling `generate_terrain()`, which recreates it for LOD0-1. Without this, each brush stroke on LOD0-1 chunks would leak a StaticBody3D node.

Props are deliberately untouched — brush rebuilds happen every frame while holding a button.

### Task 2 — _rebuild_dirty_chunks stub replaced + _flush_dirty_chunks added (commit `022e9cb`)

Modified `game/editor_controller.gd`:

```gdscript
var _frame_dirty: Dictionary = {}  # Vector2i -> true, deduped across one frame

func _rebuild_dirty_chunks(dirty: Array) -> void:
    for c in dirty:
        _frame_dirty[c] = true

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

`_flush_dirty_chunks()` is called in `_process()` after `_tick_brush(delta)`.

### Task 3 — UAT: camera reset + HUD hide (commits `14fc760`, `58bdbcb`)

UAT surfaced two blocking issues:

**Camera locked to player height (FIXED):** `enter_editor_mode()` previously set `_focus_point = player_ref.global_position` (full XYZ, including terrain surface height). Fixed to use only XZ with Y=0, and reset `_orbit_pitch` to -1.2 (≈69° down), `_orbit_yaw` to 0, and `_zoom_step`/`_camera_altitude` to defaults on every entry.

**Player HUD visible in editor (FIXED):** Added `_get_player_hud()` helper reading `player_ref.hud_instance` via duck-typed `get()`. `enter_editor_mode()` hides the entire HUD CanvasLayer; `exit_editor_mode()` restores it.

## Decisions Made

- **collision_body teardown added** — `generate_terrain()` always creates a new StaticBody3D for LOD0-1. Without removing the old one, each brush stroke leaks a collision node.
- **Props not torn down** — per plan directive. Accepted limitation for Phase 2.
- **`has_method("rebuild_mesh")` guard** — defensive check for stale chunk refs.

## Known Limitations

- Props float/sink after brushing under them — deferred to Phase 3+.
- Brush cursor ring not yet built — planned for 02-04.

## Self-Check: PASSED

- `game/terrain_chunk.gd` — `func rebuild_mesh` present
- `game/editor_controller.gd` — `_frame_dirty`, `_flush_dirty_chunks`, `chunk.rebuild_mesh()` all present
- All 4 commits verified in git log
