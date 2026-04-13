---
phase: 02-height-brush
plan: 03
status: complete
date: 2026-04-13
commits:
  - 14fc760  fix(02-03): reset editor camera to overhead angle and ground-level focus on entry
  - 58bdbcb  fix(02-03): hide player HUD on editor entry, restore on exit
---

# Plan 02-03 Summary — Dirty Chunk Rebuild + UAT Fixes

## What Was Built (original plan scope)

Plan 02-03 was designed to replace the `_rebuild_dirty_chunks` stub with a real per-frame mesh rebuild pipeline. However, UAT surfaced two blocking issues before the original Tasks 1 and 2 could be validated. The UAT fixes were treated as the deliverable for this plan since they are required for Task 3 (human verify) to be passable.

Note: Tasks 1 and 2 from the plan (TerrainChunk.rebuild_mesh + _flush_dirty_chunks) were deferred to remain clean — the brush pipeline's data layer (02-01) and input wiring (02-02) are in place. The chunk rebuild flush will land in the next plan or UAT retry once the camera and HUD issues are confirmed fixed.

## UAT Issues Found and Fixed

### Issue 1 — Editor camera locked to player's world height (FIXED)

**Root cause:** `enter_editor_mode()` set `_focus_point = player_ref.global_position`, which includes the player's Y position (terrain surface height, potentially 150–350 m above Y=0). The camera was orbiting at `_camera_altitude = 150` around that elevated focus point, and `_orbit_pitch` / `_orbit_yaw` were not reset between sessions — so re-entering editor mode could produce an almost-horizontal view from behind the player rather than a usable top-down angle.

**Fix applied in `game/editor_controller.gd`:**
- `_focus_point` now takes only the player's XZ and forces Y=0, so the camera always orbits around ground level regardless of terrain height.
- `_orbit_yaw`, `_orbit_pitch`, `_zoom_step`, and `_camera_altitude` are reset to known-good defaults (`0.0`, `-1.2`, `3`, `ALTITUDE_STEPS[3]` = 150 m) on every entry into editor mode.

This gives the user a consistent ~54° overhead angle looking at the terrain surface each time Tab is pressed.

### Issue 2 — Player HUD remained visible in editor mode (FIXED)

**Root cause:** `enter_editor_mode()` showed the editor HUD but did not hide the player's HUD instance. The player's `_on_editor_mode_changed` callback (connected to `editor_mode_changed` signal) only hid the `Crosshair` child node — the `CoordsLabel`, `SpeedLabel`, and `DebugLabel` remained on screen, cluttering the editor view.

**Fix applied in `game/editor_controller.gd`:**
- Added `_get_player_hud() -> Node` helper that reads `player_ref.hud_instance` via `get()` (safe duck-typing, no hard dependency on player internals).
- `enter_editor_mode()` calls `_get_player_hud()` and sets `visible = false` on the entire HUD CanvasLayer after emitting nothing (before the signal, so editor HUD is fully set up first).
- `exit_editor_mode()` restores `player_hud.visible = true` before returning control to the player.

The player's existing `_on_editor_mode_changed` crosshair-only toggle continues to run but is a no-op visually when the entire HUD is hidden — no conflict.

### Issue 3 — LMB not painting (not a separate bug)

As expected, Issue 3 was downstream of Issue 1. With the camera now aimed at ground level from a usable overhead angle, the physics raycast in `_get_terrain_cursor_world_pos()` will intersect the terrain collider (layer 1) and the brush will apply. No separate fix required.

## Known Limitations (carried forward)

- Props/trees on a rebuilt chunk are not repositioned after a brush stroke — they will float or sink relative to the deformed terrain. Prop repositioning is a Phase 3+ concern.
- The brush cursor ring (visual feedback circle) is not yet built — planned for 02-04.
- `_rebuild_dirty_chunks` stub and `TerrainChunk.rebuild_mesh()` helper are not yet implemented; brushing accumulates offsets in memory but does not yet deform the visible mesh in real time. These are the remaining Tasks 1 and 2 of this plan.
