# Construction editor — Rebuild Demo

Open the **Rebuild Demo** desktop shortcut, press **F1**, then choose **Construction…**.
This adds the requested building workflow to the existing terrain/tree editor.

## Build and edit

- Choose Wall, Long wall, Doorway, Window wall, Floor 4 × 4, Floor 8 × 8, Ramp, Block, Pillar, or Building. Aim and click to place the preview. Esc cancels it.
- Click a placed construction part to select it; Shift-click adds/removes parts. Joined groups select together. G moves the selection, Ctrl+D copies it, Delete removes it.
- **Snap**: grid off / 0.25 / 0.5 / 1 / 2 / 4 metres; rotation steps 1 / 5 / 15 / 30 / 45 / 90 degrees. Face snapping aligns the centres of the bounding faces without a gap. Choose an explicit target face for thin floors, or use the face you aim at. Matching the target orientation makes repeated modular pieces align.
- Q/E rotate yaw. **Transform** provides all three rotation axes, exact ring-world coordinates, local-axis nudges, and Join / Separate. Shift-wheel raises/lowers a held preview. Float mode holds the preview 15 metres in front of the camera.
- **Join** makes a logical assembly: its parts retain their geometry and collision, but move, rotate and copy together. It does not merge meshes or remove interior faces. Separate restores individual selection.
- **Snap → Colour** has twelve swatches. Click a swatch to recolour a preview, selected part or selected group. A white border indicates the selected swatch. Colours persist and can be undone.
- Phased placement allows overlaps while editing. Turning it off checks for collisions on placement and precise transforms. All placed construction stays fixed and solid in play; there is no loose, gravity-driven prop mode in this release.
- RMB + WASD flies; Space/Ctrl moves vertically; Shift moves faster. F1 returns to driving or walking. Terrain & trees returns to the existing editing tools.

Ctrl+Z/Y operate on construction while Construction is selected. There are 64 construction undo steps. **Ctrl+S** saves terrain, trees and construction. Layout → Reload construction reloads the saved layout and is itself undoable.

The original automatically placed demonstration building is still a separate showcase. To edit a building, place one from the palette. The palette building is a single prefab; Separate breaks user-created groups, not the prefab's internal walls.

## Saves and performance

Construction saves automatically load from:
`%APPDATA%\Godot\app_userdata\Rebuild Demo\construction.json`.
The file records object identity, part, colour, group, ring coordinates and orientation; writes use a pending file and backup. Invalid or mismatched saves retain the current layout. Tests override this path with `--forge-file=...` and use copied terrain/tree saves.

Opaque parts share meshes and spatial MultiMesh batches by part, colour and shadow band. Visual range is 650 m; shadows are bounded to 140 m. Collision is kept near the car/player (120 m) and editor camera (220 m), with up to 12 new bodies per physics tick. Colour-only changes retain collision bodies. The editor exposes no artificial placement-count cap, but dense geometry, many colours and collision shapes still consume frame budget. Layout snapshots and undo history remain in memory; this is not disk-paged world storage.

The rendering and object-collision checks are separate from terrain collision. Distant render culling does not simplify the shape of nearby construction. Placed parts retain their authored pose after terrain edits rather than automatically following the changed ground.

This release implements the requested construction features. Multiplayer editing, game-mode objectives, scripts, moving machinery and full Halo: Reach feature parity are not implemented. The design reference was [Bungie's archived Forge World Q&A](https://halo.bungie.org/misc/ferrex_forgeworld_answers_20100722.html); grouping and undo are additions for this rebuild.

## Validation

The core test covers all ten meshes, rotated face snapping, joined relative transforms, undo/redo, save validation, 5,021 spatial records including a ring-seam query, and actual doorway/ramp collision. The rendered integration test covers placement, joined rotation/nudge, duplicate-group identity, cancellation, delete/undo/redo, fixed versus phased placement, colour changes and persistence, collision retention during recolouring, and editor mode transitions. The screenshots and machine-readable results accompany this guide.

### Measured construction sample

Intel UHD Graphics, Godot 4.5.1 Compatibility, actual viewport 1366 × 749, uncapped. Each stationary case used 90 warm-up frames and 300 measured frames with the same camera. The stress case added 1,000 identical walls to a six-part mixed-colour layout; it is not a worst-case mixed-palette or moving-route test.

| Case | Average FPS | Mean ms | p95 ms | p99 ms | Draw calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| Construction hidden | 108.8 | 9.191 | 11.319 | 13.448 | 388 |
| Six parts | 108.9 | 9.182 | 11.025 | 14.067 | 401 |
| 1,006 parts | 106.0 | 9.432 | 13.977 | 17.505 | 404 |

The stress population used 11 construction batches and 218 nearby colliders. Those parts were temporary test data and were not added to the player's world. The view did not meet the 120 FPS / 8.33 ms target even with construction hidden. Short-run timing varies; these measurements establish the observed cost of this sample, not a guarantee for arbitrary layouts.

## Snapping revision / 2026-10-15
Magnetic placement preserves orientation. Ordinary snapping follows the aimed face position. Hover the cyan face-centre marker (gold when selected), then click to align both bounding-face centres. Angled faces retain their angles, so centre alignment can overlap geometry when Phased is enabled. Transform selects 15/30/45/90-degree steps for Rotate X/Y/Z and Q/E.

## Edge magnets and development reload / 2026-10-16
The held mesh is the placement cursor. Snap > Align camera-nearest overlapping edge aligns the projected boundary of the moving piece to the nearest edge of the contacted bounding face. It retains rotation and highlights the chosen edge. Oriented-box overlap also finds targets just beyond the mouse ray; excluded moving pieces cannot snap to themselves. Face-centre selection takes priority. Angled pieces align their projected boundary, not their edge direction; ramp/building snaps use bounding boxes.

Ctrl+F6 with F1 open, or Layout > Reload development changes, updates construction parts, batches/collision, construction/actor editor UI and actor preview code. Terrain, trees, camera, live actors, in-memory layouts, undo stacks and move/copy drafts remain. One restart is needed to install this mechanism. It is a source-build development control; it does not reload AI, weapon, terrain or base editor code. No save file is loaded or written by the reload. It performs a separate parser check first and reports failures in the editor.
