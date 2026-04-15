---
phase: 03-smooth-flatten-brushes
plan: "02"
subsystem: editor
tags: [smooth-brush, terrain, gdscript, gaussian]
dependency_graph:
  requires: [03-01]
  provides: [apply_smooth_brush, BrushMode.SMOOTH-wired]
  affects: [game/terrain_manager.gd, game/editor_controller.gd]
tech_stack:
  added: []
  patterns: [two-pass-gaussian-average, match-branch-dispatch]
key_files:
  created: []
  modified:
    - game/terrain_manager.gd
    - game/editor_controller.gd
decisions:
  - "Two-pass Gaussian: Pass 1 builds global weighted average, Pass 2 lerps vertices toward it — prevents order-dependent seam artifacts"
  - "Smooth strength constant 3.0 expressed inline (3.0 * boost * delta ≈ 0.05 lerp/frame at 60fps) to remain easy to find and tune"
  - "RMB has no effect in Smooth mode — smooth has no directional opposite, LMB-only guard in _tick_brush"
  - "BrushMode.FLATTEN added as stub pass block so mode cycling does not crash"
metrics:
  duration: ~15 minutes
  completed: 2026-04-15T11:50:00Z
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
---

# Phase 03 Plan 02: Smooth Brush Summary

**One-liner:** Two-pass Gaussian smooth brush (`apply_smooth_brush`) on TerrainManager with LMB-only wiring in `_tick_brush` behind `BrushMode.SMOOTH` branch.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement apply_smooth_brush in TerrainManager | b1debab | game/terrain_manager.gd |
| 2 | Wire smooth brush into _tick_brush in EditorController | c18447c | game/editor_controller.gd |

## What Was Built

- `apply_smooth_brush(world_pos, radius, strength)` added to `terrain_manager.gd` after `apply_height_brush`
- Two-pass algorithm: Pass 1 computes Gaussian-weighted average offset across all in-radius vertices (cross-chunk), Pass 2 lerps each vertex toward that average weighted by its own Gaussian weight
- Bounding box expanded by `half_cs` on each side (same pattern as `apply_height_brush`) to avoid chunk coordinate dead zones
- Returns dirty `Array[Vector2i]` for caller to rebuild
- `_tick_brush` in `editor_controller.gd` refactored from flat code to `match brush_mode:` dispatch
- `BrushMode.RAISE_LOWER` branch retains original raise/lower behavior exactly
- `BrushMode.SMOOTH` branch: LMB-only guard, `strength = 3.0 * boost * delta`, calls `apply_smooth_brush`
- `BrushMode.FLATTEN` stub pass block added (Plan 03 will implement)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Soft-reset staged unwanted deletions from ahead-of-base commits**
- **Found during:** Task 1 commit
- **Issue:** The worktree HEAD was behind the target base commit 862d2fd. The `git reset --soft` command staged diffs from 03-01 commits (BrushMode enum removal, planning file deletions, ROADMAP.md revert) which were inadvertently included in the Task 1 commit.
- **Fix:** Restored `editor_controller.gd`, `editor_hud.tscn`, ROADMAP.md and planning files from the main repo (which matched the 862d2fd state exactly). Committed restoration before proceeding to Task 2.
- **Files modified:** game/editor_controller.gd, game/editor_hud.tscn, .planning/ROADMAP.md, .planning/phases/03-smooth-flatten-brushes/*.md
- **Commits:** 29815be (planning files), 7b801d9 (game files)

## Known Stubs

- `BrushMode.FLATTEN` in `_tick_brush` is an intentional stub (`pass`). Plan 03 will add `apply_flatten_brush` and wire it here.

## Threat Flags

None. `apply_smooth_brush` uses the identical chunk-iteration pattern as `apply_height_brush` with the same trust boundary (editor-only, LMB input). No new network endpoints or auth paths introduced.

## Self-Check: PASSED

- game/terrain_manager.gd contains `func apply_smooth_brush`: VERIFIED (line 1217)
- Two-pass structure (Pass 1 / Pass 2 comments) present: VERIFIED (lines 1228, 1264)
- `weighted_sum` and `avg_offset` variables present: VERIFIED (lines 1229, 1262)
- `lerp(chunk.height_offsets[idx], avg_offset, strength * w)` present: VERIFIED (line 1293)
- `half_cs: float = chunk_size * 0.5` present in apply_smooth_brush: VERIFIED (line 1222)
- game/editor_controller.gd contains `match brush_mode:`: VERIFIED (line 295)
- `BrushMode.SMOOTH` branch present: VERIFIED (line 303)
- `apply_smooth_brush` called from editor_controller.gd: VERIFIED (line 311)
- `BrushMode.FLATTEN` stub pass block present: VERIFIED (line 314)
- `BrushMode.RAISE_LOWER` branch retains original behavior: VERIFIED (lines 296-302)
- Commit b1debab exists: VERIFIED
- Commit c18447c exists: VERIFIED
