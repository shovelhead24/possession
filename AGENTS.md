# Tree demo workspace

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
