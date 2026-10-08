# User workflow: current test shortcut

The user requested on 2026-10-07 that a single desktop shortcut always launch
the latest targeted playable test. Reuse and update the existing
`Terrain Demo.lnk` in the Windows Desktop known folder rather than creating
a separate desktop shortcut for every iteration.

Whenever work changes the targeted test, update the shortcut target, arguments,
working directory and description, then read it back to verify. The user has
explicitly authorized these updates. Use the required filesystem approval
mechanism when writing outside the workspace.

Current target: Godot 4.5.1, this repository's `game` project,
`res://world/terrain_drive.tscn` (optimized continuous terrain sculpting, compact saves and corrected Warthog;
F1 opens the editor; B throws grenades in driving or flight). Keep this current-target note updated when
switching to another test.



## Locked terrain baseline — 2026-10-08
The user approved this state and requested a separate `Tree demo` desktop shortcut
and independent scene copy for a new agent. This supersedes the single-shortcut
rule above: preserve `Terrain Demo.lnk` and this terrain baseline. New tree work
belongs in `C:\Users\Bran the builder\Documents\Codex\2026-10-08\tree-demo`.
Do not retarget Terrain Demo to tree work. See the Tree Demo handover in the
2026-10-07/co/outputs folder. The local terrain checkpoint tag is
`terrain-demo-locked-2026-10-08`.
