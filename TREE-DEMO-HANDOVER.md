# Tree Demo handover — 2026-10-08

The user approved the fast continuous terrain editor and asked to lock that
state, then make an exact scene copy with a desktop shortcut named **Tree demo**
for new work with a new agent. Tree features have not been added yet.

## Open this workspace

`C:\Users\Bran the builder\Documents\Codex\2026-10-08\tree-demo`

Branch: `tree-demo`. Godot project: `game/project.godot`.
Scene: `res://world/terrain_drive.tscn`.
Desktop launcher: `C:\Users\Bran the builder\Desktop\Tree demo.lnk`.
Godot executable: `C:\Godot\Godot_v4.5.1-stable_win64.exe`.

## Locked baseline

Original code checkpoint: `b7013717c3687d5b4652f46d101e2e3540ce62e4`.
Tag: `terrain-demo-locked-2026-10-08`.
Original checkout remains at:
`C:\Users\Bran the builder\Documents\Codex\2026-09-27\we-h\work\world-foundation`.
Its `Terrain Demo.lnk` shortcut was verified unchanged. Unrelated workshop
changes in that checkout were not included in the checkpoint.

This is a separate Git worktree with separate physical gameplay source files.
All 155 files under `game/world` matched the approved original byte-for-byte.
Only project configuration changed: project name `Tree Demo` for isolated saves,
and default main scene changed to the terrain demo. Gameplay is unchanged.
`AGENTS.md` contains the new workspace/shortcut rules.

## Saves and assets

Tree user data: `%APPDATA%\Godot\app_userdata\Tree Demo`.
Original user data: `%APPDATA%\Godot\app_userdata\HaloTest`.
The terrain save, vehicle tuning and tank tuning were copied and hash-verified.
Starting copies are preserved in this worktree's `baseline-state/`, tracked by Git.
Future Ctrl+S and vehicle tuning writes in Tree demo affect only Tree Demo data.
The terrain save loads as 441 compact terrain edits.
Relevant terrain, satellite and model caches were copied separately for startup.

`game/mocks/dem` is a junction to `C:\Games\possession\game\mocks\dem`, exactly
as in the original project. These are shared source data, NOT edit saves.
Treat them as read-only; make a private copy before modifying source DEM files.
The initial full asset-copy attempt ran out of disk space; its incomplete DEM
copy was removed and replaced by this junction. The retry completed after the
user freed space. No original files or caches were removed.
Generated UID/import files and copied Godot cache changes can appear in status;
avoid including unrelated generated data in gameplay commits.

## Controls and existing functionality

- F1: terrain tools (Raise, Lower, Tunnel boring, Mountain fill).
- Hold LMB to raise/lower continuously; Ctrl+S saves, Ctrl+Z/Y undo/redo.
- Editor flight: RMB + WASD, Space/Ctrl vertical; Shift faster.
- Tunnel: entrance then exit click; Alt-click far surface; Esc cancels.
- B: destructive grenade; E: fly/drive; WASD drive; Space brake; R recover.
- C camera; F5 vehicle setup; F2 briefing; Enter dismisses loading briefing.

The terrain is curved and streamed; destruction uses local 2m detail.
The Warthog driver/model and steering-wheel animation orientation are corrected.
Held strokes retain all input while mesh work runs, reuse cached field/column
work, and undo as one stroke. Exact additive compaction keeps saves smaller.
Cold edits and whole-tile collision publication can still hitch.

## Prior evidence and testing

Read the detailed optimization handover:
`C:\Users\Bran the builder\Documents\Codex\2026-10-07\co\outputs\HANDOVER-CONTINUOUS-TERRAIN-2026-10-08.md`.
Prior checks cover editor tools, compact saves/reload, seam craters, continuous
brush input and vehicle orientation. They passed before the user approved it.
Existing benchmark scripts may contain absolute output paths from that chat;
use isolated saves, never the player's current terrain file, for test runs.
New copy verification and startup log are alongside this handover in that
chat's outputs folder: `tree-demo-copy-check.json`, `tree-demo-shortcut.json`,
`tree-demo-smoke.log`.

## Continue with a new agent

Use the workspace above and this handover. Preserve the baseline tag and
`baseline-state` snapshots. Update only **Tree demo** when changing the target
test. Do not retarget Terrain Demo or edit the original checkout for tree work.

## Copy validation result

Headless startup passed with 256 resident tiles, satellite imagery, ring
backdrop, Warthog, editor and 441 loaded terrain edits. It reported the separate
Tree Demo user-data directory. Startup took 39.1 seconds in this check.
This verifies startup and asset resolution; it is not a new visual review.
