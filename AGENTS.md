# Tree demo workspace

## Sky comparison phase — 2026-10-16
The user requested a new branch, scene and shortcut from the completed current
checkout. Work is now on `sky-demo`; read SKY-DEMO.md. Use `Sky Demo.lnk` and
`game/world/sky_demo.tscn`. Preserve Rebuild, Tree and Terrain shortcuts. All four
Sky Demo layouts are independent copies selected through launcher flags.
The user wants screenshots of each method and combinations to judge personally.

The user approved the terrain scene on 2026-10-08 and requested this isolated
copy as the basis of new work with a new agent. Work here, on branch `tree-demo`.
The starting scene is `game/world/terrain_drive.tscn`. Scene/gameplay code is
unchanged from tag `terrain-demo-locked-2026-10-08`.

Only update `Tree demo.lnk` on the desktop for this work. Never retarget
`Terrain Demo.lnk` or edit the original world-foundation checkout for tree work.
The user has authorized keeping Tree demo pointed at the latest tree test.
Read back shortcut target, arguments and working directory after updates.

Project name `Tree Demo` isolates Godot saves from the original `HaloTest`.
Starting terrain and tuning snapshots are in `baseline-state/`; preserve them.
The project main scene is set to the copied terrain scene.

Read `TREE-DEMO-HANDOVER.md` before starting. `game/mocks/dem` is a junction
to the SAME shared source DEM assets used by the original project. Treat these
as read-only: make a separate local copy before changing any source DEM assets.
All gameplay scripts, other assets and save files are separate physical copies.
Generated Godot cache, import and UID differences may appear in git status.
Avoid including them in gameplay commits. Existing benchmarks can contain
absolute output paths from the earlier chat; isolate test saves before running.
Never run destructive tests against the player's live save.

## Rebuild content phase — 2026-10-09
The user explicitly requested a NEW shortcut for rebuild builds. Use
`C:\Users\Bran the builder\Desktop\Rebuild Demo.lnk` for this phase;
do not retarget Tree demo or Terrain Demo. This user instruction supersedes
the earlier Tree-demo-only launcher rule for the rebuild phase.
The new scene is `game/world/rebuild_demo.tscn`, extending the approved Tree Demo.
Read `REBUILD-DEMO.md`. Terrain/tree save copies are selected by launcher flags;
never benchmark against those player copies. Existing dirty files predate this phase.

Construction tools are integrated into Rebuild Demo. Read CONSTRUCTION-EDITOR.md.
When testing this scene, also pass --forge-file=<isolated test JSON>, in addition
to the terrain/tree overrides. Player construction saves live in the separate
Rebuild Demo user-data folder. Preserve all three live save files.

## Loading-screen SOP
For every user-facing Rebuild Demo feature change, update
`game/world/rebuild_demo_brief.json` with the current date, test goal, changes and
actual controls. Set the briefing path BEFORE adding the Loading node: its _ready
reads the JSON immediately. Verify the visible briefing, not just the JSON file.

## Actor authoring — 2026-10-12
Read ACTOR-EDITOR.md for actor placement, routes and behavior controls.
Full-scene tests must also pass --actors-file=<isolated test JSON>; preserve
the live Rebuild Demo/actors.json alongside terrain, tree and construction saves.
