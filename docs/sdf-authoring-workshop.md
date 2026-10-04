# SDF recipe workshop — first working editor

Run `game/world/sdf_authoring.tscn`, or the workspace launcher
`outputs/Open-SDF-Authoring.ps1`. The existing expanded arena is unchanged.

## Use

### Brush controls (updated)

Brush mode is the default. Choose a tool without immediately creating a feature;
hold left mouse over terrain to accumulate a stroke. Earlier strokes remain.
One stroke is one undo step. Hill/ravine add signed field offsets at the adjustable
Strength/s rate; flatten/carve/ridge/bridge progressively blend toward their target
shape. Strength is not guaranteed metres of displacement on steep surfaces.
Moving strokes resample between cursor positions. Tunnel is a two-point tool.

- WASD flies while editing; Space/Ctrl rises/descends; Shift flies faster.
- Hold right mouse and move to look; release to freely point the cursor.
- Wheel zooms/dollies toward the cursor. Shift-wheel or [ / ] changes radius.
- Radius has a visible terrain footprint. Choose circle, square or ellipse;
  ellipse ratio stretches its second axis and yaw rotates it. The preview is a
  horizontal outline, not a conforming decal.
- F3 toggles chunk cages: cyan ready, orange pending.
- Turn Brush off for explicit feature creation/transform. **Move feature** moves
  an existing feature; it is intentionally not a new brush stamp.

Tunnel: click an entrance. Its proposed exit searches eight horizontal directions
at 2 m intervals, up to 256 m, choosing the shortest detected through-path. This is
a bounded heuristic, not a globally shortest-path solver; if none is found it
uses the configured length. Inspect the result. The cylinder guide and exit handle
render through terrain. Drag the exit in the camera-facing plane; Ctrl snaps its
horizontal heading to 45-degree increments. **Set tunnel exit** then click picks
a visible surface; Alt-click finds the first solid-to-air exit along the ray
through the uncarved terrain, at 2 m probe resolution. Esc cancels. Endpoints save
in the recipe. Turn Brush off to numerically edit an existing tunnel's radius.

Input accumulates while meshing finishes. Old neighbouring surfaces remain until
the replacement batch is ready, then visuals/collision swap together. The HUD
reports queued strokes; preview can lag rather than continually cancelling jobs.
All generated revisions remain on disk. The 2048-feature limit still applies;
long strokes are sampled, not an unlimited voxel painting store.

Vehicle look-ahead now includes stopping distance. A finite-domain guard prevents
Warthog/tank bodies leaving the supported rectangle. The workshop HUD shows the
collision-ahead speed limit. This does not eliminate genuine generation delays
or enlarge the domain; the guard is a prototype boundary stop, not a designed
physical perimeter. These changes also apply to the original expanded arena's
shared vehicle system and look-ahead calculation.

### Explicit feature mode

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

The sampled-field precache retains expensive base samples and brush kernels in
an estimated 32 MiB RAM LRU. Warm edits rebuild affected 8 m horizontal sections
rather than reevaluating/remeshing the entire chunk. Field state is persisted with
meshes and restored on cache reads. First visits still require generation.
Normals now come from gradients of the sampled grid, an approximation to the
analytic normals; the sampled geometry remains authoritative.

While a brush is active, local visual updates take priority over speculative
streaming. A dirty local batch swaps together. Physics rebuilding is deferred
until the stroke ends (one queued chunk per frame), while cursor picking follows
the cached edited field so it does not wait for old collision to catch up. Editor
mode pauses actors and freezes vehicles. Returning to play waits for current
chunks; actors within changed footprints are relocated above sampled terrain and
vehicles have velocities cleared. This is a deliberate editor transition, NOT
continuous destruction or a guarantee of footprint fit on every overhang. Inspect
placement after significant edits. Existing static trees are not re-authored or
re-grounded by this first editor.

Continuous small-crater destruction is tested separately in the
[grenade lab](terrain-destruction-lab.md), not inferred from this editor pause.

## Scope and known limits

This separate workshop uses the expanded arena base field, ring backdrop and live
models/controllers, with uniform nearby streamed 2 m terrain. It does not yet
include the expanded scene's distant coarse terrain layer or compounds. Recipes
are not automatically applied to that original scene. Keeping this separate
avoids mismatched editable near terrain and unchanged distant LOD geometry.

Generated vertical range is -24..64 m. Keep shapes within it. Very thin features
may disappear at 2 m sampling. Materials use the shared terrain shader; no per-
feature material painter yet. Selection includes list, centre and tunnel exit, not a full
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

`check_sdf_brush.gd` checks accumulated/repeated ravines, time-based strength,
square/ellipse footprints, endpoint cylinders, persistence and matching shared-edge
vertices in two actual adjacent ravine meshes. The rendered check additionally
tests wheel zoom/size, chunk cages and vehicle boundary containment. These tests
do not prove every tunnel proposal finds an exit.
