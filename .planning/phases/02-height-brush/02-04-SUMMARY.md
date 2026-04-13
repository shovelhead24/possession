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

## Task 2 — UAT

Awaiting in-game verification after push.

## Known Limitations

- Cursor floats 0.5 m above surface — may look slightly detached on steep slopes.
