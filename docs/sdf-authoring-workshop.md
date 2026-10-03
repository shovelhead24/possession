# SDF recipe workshop — first working editor

Run `game/world/sdf_authoring.tscn`, or the workspace launcher
`outputs/Open-SDF-Authoring.ps1`. The existing expanded arena is unchanged.

## Use

- Click hill, lower, flatten, carve, ridge, tunnel or bridge to add a feature.
- Select an entry; change its numeric properties. Distances are metres, yaw is
  degrees. Drag its orange centre horizontally, or use Place then click terrain.
  Focus moves the camera to the selected feature. Esc cancels placement/drag.
- Earlier/Later changes composition order. A tunnel after a hill cuts it; a hill
  after a tunnel can fill it back in. Delete, Undo and Redo operate on features.
- Save writes the recipe. Load is undoable. The saved recipe automatically opens
  next session. Closing without Save loses unsaved edits, not existing saves.
- F1 switches between editing and play. Wait for edited chunks before playing.
  WASD/mouse fly, Shift accelerates, F walks; H then E enters the Warthog, K then E
  enters the tank. Tab possesses creatures. Backspace releases control.

The bridge is a parametric deck with two supports, not a freeform arch editor.
Y is the deck top, length runs along local X, width along local Z, thickness sets
deck/support thickness, height is support depth, yaw rotates the bridge. Ensure
supports reach ground; the editor does not automatically build approach ramps.
Add lower/carve features before the bridge for a crossing with clear space below.

Hill/lower use radius and height; flatten uses radius and target Y; carve uses
radius. Ridge/tunnel are quadratic paths controlled by length, yaw, bend and
radius, sampled into eight capsule segments. Unused numeric fields do not affect
that tool. Vertical placement uses Y; the centre drag is horizontal only.

## Storage and generation

Source: `%APPDATA%/Godot/app_userdata/HaloTest/sdf-authoring.json`.
Persistent meshes: same directory, `sdf-authoring-meshes/`.
Recipes are ordered feature definitions in the arena's ring-tangent metre frame,
not baked mesh data. They are local user data, not automatically committed or
remotely backed up. Save uses a temporary file and atomic rename.

Each worker receives an immutable recipe snapshot and filters features by chunk
bounds. Cache identity includes local features, base/evaluator/mesher source,
engine, origin and sampling settings. Distant edits do not change unrelated
chunk cache keys. Old revisions remain on disk. There is no automatic purge and
no whole-world generation on save. Undo can reuse a previous cached mesh.

The old visible mesh/collision stays until the replacement is installed. Editor
mode pauses actors and freezes vehicles. Returning to play waits for current
chunks; actors within changed footprints are relocated above sampled terrain and
vehicles have velocities cleared. This is a deliberate editor transition, NOT
continuous destruction or a guarantee of footprint fit on every overhang. Inspect
placement after significant edits. Existing static trees are not re-authored or
re-grounded by this first editor.

## Scope and known limits

This separate workshop uses the expanded arena base field, ring backdrop and live
models/controllers, with uniform nearby streamed 2 m terrain. It does not yet
include the expanded scene's distant coarse terrain layer or compounds. Recipes
are not automatically applied to that original scene. Keeping this separate
avoids mismatched editable near terrain and unchanged distant LOD geometry.

Generated vertical range is -24..64 m. Keep shapes within it. Very thin features
may disappear at 2 m sampling. Materials use the shared terrain shader; no per-
feature material painter yet. Selection is via list and centre marker, not a full
transform/endpoint gizmo suite. The spatial filter is a conservative linear scan
per chunk, not a hierarchical index; thousands of features need further work.

Terrain replacement still has collision installation costs. Full volumetric LOD,
smarter prefetch, launch timing, collision scheduling, arbitrary ring-angle
authoring, autosave/recovery and shipping policy remain in the retained
[roadmap](sdf-authoring-plan.md). This milestone does not claim those finished.

## Verification

`--headless --path game --script res://benchmarks/check_sdf_recipe.gd` checks all
seven tools, operation order, malformed recipe rejection, save/load equivalence,
shared-boundary field samples, local cache keys, exact cache reuse and retention
of old cache revisions after edits.

`--path game --rendering-method gl_compatibility --resolution 960x600
res://world/sdf_authoring.tscn -- --authoring-check` checks undo/redo, rebuilt hill
collision, a clear tunnel and its roof, bridge deck and clearance, recipe save,
and actual Warthog movement. Test recipes and captures use separate filenames;
the user's saved recipe is not overwritten. Both checks passed on 2026-10-03.
