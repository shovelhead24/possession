---
phase: 02-height-brush
plan: "04"
status: complete
date: 2026-04-13
subsystem: editor
tags: [editor, brush-cursor, torus, visual-feedback]
key_files:
  modified:
    - game/editor_controller.gd
commits:
  - 0cb6de1  feat(02-04): add brush cursor ring — orange torus, scales with radius, hides on camera-drag
  - 315b8d4  fix(02-04): camera focus uses player Y not sea level; expand dirty set to stitch chunk edges
metrics:
  completed_date: "2026-04-13"
  tasks_completed: 1
  tasks_total: 2
  files_modified: 1
---

# Phase 2 Plan 4: Brush Cursor Ring Summary

**One-liner:** Orange TorusMesh cursor follows the terrain raycast hit, scales 1:1 with brush_radius, hides during camera-drag modifiers and on editor exit.

## What Was Built

Added to `game/editor_controller.gd`:

- `var _brush_cursor: MeshInstance3D` — member var
- `_create_brush_cursor()` — builds a TorusMesh (inner 0.95 / outer 1.0, 48 rings, 8 segments), applies an unshaded orange StandardMaterial3D with `no_depth_test = true` and `render_priority = 1`, adds as child, starts hidden. Called from `_ready()`.
- `_update_brush_cursor()` — called from `_process()` each frame. Hides when editor inactive, when Shift/Ctrl held (camera-drag mode), or when raycast misses. Otherwise positions at `hit.y + 0.5` and sets `scale = Vector3(brush_radius, 1.0, brush_radius)`.
- `exit_editor_mode()` — hides cursor on exit.

## UAT Fixes Applied

**Camera underground (FIXED):** Camera focus Y was hardcoded to 0 — wrong when terrain is above sea level. Fixed to use `player.y - 1.5` so the camera always orbits above the actual terrain surface.

**Chunk edge seams (FIXED):** `_flush_dirty_chunks()` now expands the rebuild set to include 4 direct neighbors of each dirty chunk, so shared edge vertices on both sides of a boundary are always rebuilt together.

**Warthog collision blocking brush raycast (OPEN):** Warthog `VehicleBody3D` likely shares collision layer 1 with terrain. If the warthog hull is between the camera and the ground, the raycast hits the vehicle instead of terrain. Needs dedicated brush raycast layer — deferred, investigate after camera fix lands.

## Known Limitations

- Cursor floats 0.5 m above surface — may look slightly detached on steep slopes.
- Warthog may intercept brush raycasts if parked between camera and terrain.
