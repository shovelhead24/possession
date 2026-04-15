---
phase: 03-smooth-flatten-brushes
plan: "03"
subsystem: editor
tags: [flatten-brush, terrain, gdscript, gaussian]
dependency_graph:
  requires:
    - phase: 03-02
      provides: apply_smooth_brush, BrushMode enum, match-branch dispatch in _tick_brush
  provides: [sample_height_offset, apply_flatten_brush, BrushMode.FLATTEN-wired]
  affects: [game/terrain_manager.gd, game/editor_controller.gd]
tech_stack:
  added: []
  patterns: [first-press-state-capture, gaussian-lerp-toward-target]
key_files:
  created: []
  modified:
    - game/terrain_manager.gd
    - game/editor_controller.gd
key_decisions:
  - "target_offset is the raw height_offsets additive value (not world Y) — flattening in offset-space is consistent with raise/lower and smooth brushes"
  - "Flatten strength 5.0 (vs smooth 3.0) chosen for faster convergence — roads/landing pads need a hard level, not a gentle blend"
  - "_flatten_lmb_was_pressed resets on LMB release so each new press resamples a fresh target; no extra M-key reset needed"
  - "Safety reset of _flatten_lmb_was_pressed in exit_editor_mode() prevents stale target surviving editor re-entry"
patterns-established:
  - "First-press state capture: bool flag + stored value, reset on release — reusable pattern for any single-sample brush"
requirements-completed: [FLATTEN-01]
duration: ~10 minutes
completed: 2026-04-15
---

# Phase 03 Plan 03: Flatten Brush Summary

**Flatten brush with first-press height sampling: `sample_height_offset` and `apply_flatten_brush` on TerrainManager, wired behind `BrushMode.FLATTEN` with per-stroke target capture in EditorController.**

## Performance

- **Duration:** ~10 minutes
- **Started:** 2026-04-15T12:00:00Z
- **Completed:** 2026-04-15T12:10:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `sample_height_offset(world_pos)` reads the bilinear-interpolated height_offset at any world position via `chunk._sample_offset`
- `apply_flatten_brush(world_pos, radius, target_offset, strength)` pulls all in-radius vertices toward a fixed target using Gaussian weighting — Gaussian weighting means center converges faster than edges, avoiding hard plateau edges
- First LMB press in Flatten mode samples the target; held frames apply flatten; LMB release resets so next press resamples a new target
- `exit_editor_mode()` resets `_flatten_lmb_was_pressed` for clean state on re-entry

## Task Commits

Each task was committed atomically:

1. **Task 1: Add sample_height_offset and apply_flatten_brush to TerrainManager** - `6c5e5e9` (feat)
2. **Task 2: Wire flatten state and FLATTEN branch into EditorController _tick_brush** - `2167e8c` (feat)

## Files Created/Modified

- `game/terrain_manager.gd` - Added `sample_height_offset` (bilinear sample via chunk._sample_offset) and `apply_flatten_brush` (Gaussian-weighted lerp toward target_offset) after `apply_smooth_brush`
- `game/editor_controller.gd` - Added `_flatten_target_offset` and `_flatten_lmb_was_pressed` member vars; replaced `BrushMode.FLATTEN: pass` stub with full first-press-sample + continuous-flatten logic; added `_flatten_lmb_was_pressed = false` reset in `exit_editor_mode()`

## Decisions Made

- `target_offset` is the raw `height_offsets` additive value (not world Y) — flattening in offset-space is consistent with raise/lower and smooth brushes which also modify `height_offsets` directly
- Flatten strength constant `5.0` (vs smooth `3.0`) for faster convergence — roads and landing pads need a hard level surface, not a slow gentle blend
- `_flatten_lmb_was_pressed` resets on LMB release so each new stroke resamples; no extra reset needed in M-key handler since M is pressed while LMB is not held

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. The flatten brush is fully wired. All three BrushMode branches (RAISE_LOWER, SMOOTH, FLATTEN) are implemented.

## Threat Flags

None. `apply_flatten_brush` uses the identical chunk-iteration pattern as `apply_height_brush` and `apply_smooth_brush`. Editor-only surface, no new network endpoints or auth paths.

## Issues Encountered

Worktree was initialized via `git reset --soft` from a commit ahead of the target base, leaving staged deletions of planning files and modifications to editor files. Resolved by unstaging non-terrain files for Task 1 commit, then copying the correct 03-02-state game files from the main repo before applying Task 2 changes.

## Next Phase Readiness

- All three brush modes (Raise/Lower, Smooth, Flatten) are fully operational
- Plan 04 can implement save/load of terrain edits, or any other planned extension
- No blockers

---
*Phase: 03-smooth-flatten-brushes*
*Completed: 2026-04-15*
