---
phase: 02-height-brush
plan: "02"
subsystem: editor
tags: [editor, height-brush, input, brush-controls]
dependency_graph:
  requires: [height_offsets-storage, apply_height_brush-api]
  provides: [brush-input-wiring, brush-state, _rebuild_dirty_chunks-stub]
  affects: [game/editor_controller.gd]
tech_stack:
  added: []
  patterns: [per-frame brush tick in _process, Shift/Ctrl modifier guard for orbit/pan conflict avoidance]
key_files:
  created: []
  modified:
    - game/editor_controller.gd
decisions:
  - "terrain_manager resolved via get_node_or_null('../TerrainManager') in _ready — both nodes are siblings under root in world.tscn"
  - "Brush tick added at end of _process after player_marker update, not at start, to maintain consistent ordering with HUD"
  - "F key falloff cycle uses physical_keycode (consistent with existing Tab handler) to avoid layout issues"
  - "KEY_R boost uses is_key_pressed (held) not pressed event, so boost applies per-frame while held during a stroke"
metrics:
  duration_minutes: 10
  completed_date: "2026-04-13"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 2 Plan 2: Brush Input Wiring Summary

**One-liner:** EditorController extended with brush state vars, scroll-wheel radius resize, F-key falloff cycle, R-hold strength boost, and per-frame LMB/RMB brush tick calling TerrainManager.apply_height_brush.

## What Was Built

### Task 1 — Brush state + input handling (commit `adc6080`)

Added to `game/editor_controller.gd`:

**Constants** (after `PITCH_MAX`):
- `BRUSH_RADIUS_MIN = 5.0`, `BRUSH_RADIUS_MAX = 120.0`, `BRUSH_RADIUS_STEP = 2.0`
- `BRUSH_STRENGTH_PER_SEC = 30.0` (height units per second while held)
- `BRUSH_BOOST_MULT = 2.0` (R-key multiplier)

**State vars** (after `_orbit_pitch`):
- `var brush_radius: float = 15.0`
- `var brush_falloff: int = 0` — matches `TerrainManager.BrushFalloff` enum
- `var terrain_manager: Node = null`

**`_ready()` addition:**
- `terrain_manager = get_node_or_null("../TerrainManager")` — resolved path confirmed by reading `world.tscn`: both `EditorController` and `TerrainManager` are children of `.` (root), so `../TerrainManager` is correct.

**`_input()` additions** (inside `if not is_editor_active: return` gate):
- Scroll wheel up/down → clamp-adjust `brush_radius`
- F key (physical_keycode, not echo) → `brush_falloff = (brush_falloff + 1) % 3`
- Both call `set_input_as_handled()` to prevent propagation

**`_tick_brush(delta)` method:**
- Guards: `is_editor_active`, `terrain_manager != null`, no Shift/Ctrl held
- Reads LMB/RMB held state each frame
- Raycasts cursor world position; returns early if null
- Computes `strength = direction * BRUSH_STRENGTH_PER_SEC * boost * delta`
- Calls `terrain_manager.apply_height_brush(world_pos, brush_radius, strength, brush_falloff)`
- Forwards dirty Array to `_rebuild_dirty_chunks(dirty)` if non-empty

**`_rebuild_dirty_chunks(_dirty: Array)` stub:**
- `pass` — implemented in Plan 02-03

**`_process()` addition:**
- `_tick_brush(delta)` called at end of process tick

## Decisions Made

- `terrain_manager` resolved at `_ready()` time via `get_node_or_null("../TerrainManager")`. Both nodes are siblings under the scene root in `world.tscn` (confirmed by grep). This is the correct path.
- Brush tick runs every `_process` frame while button held — no debounce — matching decision D-09 (immediate rebuild per stroke). The data layer mutation is immediate; visual update waits for Plan 03.
- Orbit/pan conflict guard: `_tick_brush` returns early if `KEY_SHIFT` or `KEY_CTRL` is pressed, because those modifiers are used for orbit and pan respectively in the existing `_input` handler.

## Deviations from Plan

None — plan executed exactly as written. The `terrain_manager` node path was confirmed by reading the scene file rather than assumed — `../TerrainManager` is correct as stated in the plan's suggested path.

## Known Stubs

- `_rebuild_dirty_chunks(_dirty: Array)` — body is `pass`. Data offsets are mutating correctly on each brush stroke, but mesh geometry will not update until Plan 02-03 calls `chunk.set_lod()` on dirty chunks. This is intentional per plan scope.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary changes. Purely in-process input wiring.

## Self-Check: PASSED

- `game/editor_controller.gd` — exists and contains all required symbols
- Commit `adc6080` — verified in git log
- All 13 acceptance criteria checks pass (verified with grep output above)
