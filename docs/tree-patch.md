# Tree patch — 2026-10-08

Entry scene: `res://world/tree_demo.tscn`. The scene extends the locked driving
scene. Terrain generation, editing, coordinate conversion and vehicle code are
unchanged. No shared DEM data or baseline snapshots are modified.

## Controls

- F6 toggles trees and their trunk colliders, for a same-view comparison.
- Automatic demo placement and the F7 density control were removed on 2026-10-09. Only painted trees populate the world.
- F9 enters flight and cycles three fixed views of the patch. E returns to driving.
- F10 cycles automatic LOD / LOD0 / LOD1 / LOD2 / original billboard.
- F11 toggles the normal 120 FPS limit and uncapped rendering.
- Existing F1 terrain tools, Ctrl+S, Ctrl+Z/Y, B grenade, F5 vehicle setup and F8
  frame capture remain available. F2 opens the tree-specific briefing.

The former deterministic demo patch has been removed. The base tree node now
prepares shared assets with zero candidates; painted placements load separately.
No automatic population can be restored with F7. Historical demo measurements
and `check_tree_patch.gd` describe the retired population.

## Tree painting — added 2026-10-09

F1 now opens the extended terrain editor with Paint trees and Erase trees.
The brush has radius (2–60m), species (mixed/tall/medium/sapling), target height
(1–30m, ±20% variation) and density (1–12 trees/100m²). Hold LMB and drag;
Shift-wheel adjusts radius. The brush rejects steep/unloaded terrain and keeps
at least 3m between painted roots. Erase removes painted trees.

Each completed drag is one undo step. Ctrl+Z/Y and the labelled undo buttons
operate on the selected category (terrain or trees). Ctrl+S / Save terrain +
trees saves both layers into separate files; tree saving waits for queued brush
work. Load trees reloads the saved painted layer, while Load terrain retains
the original terrain behaviour. Tree placement automatically loads on launch.

The painted layer uses `user://painted-trees.json` in Tree Demo's isolated user
data. It has its own schema, base-terrain identity, validation, pending-file
write and previous-save backup. Invalid loads leave existing placements intact.
Tests override this path with `--tree-paint-file=<absolute test path>`.
Undo holds at most 32 tree actions; this pilot supports 4096 painted trees.

Painting uses queued, interpolated dabs with at most 32 candidate attempts per
physics tick. Grounding pauses during terrain rebuilds. The painted renderer
shares the prepared meshes/materials, LOD logic and radial grounding with the
shared base renderer, but retires empty batches as painted areas change. F6
toggles painted trees, and F10 compares their LODs. No tree placement is added to the terrain SDF recipe.

`benchmarks/check_tree_paint.gd` verifies stroke grouping, spacing, duplicate
repaint rejection, erase, undo/redo, save/reload, invalid-load retention and
nearby collision in an isolated flat-world fixture. The graphical
`benchmarks/check_tree_paint_editor.gd` checks the real editor input path,
Ctrl+Z/Y/S, paint/erase, tool switching and panel layout. It requires explicit
isolated paths for both terrain and tree saves.

## Asset findings

The existing fir pack contains three variants. Triangle counts, by source LOD:

| Variant | LOD0 | LOD1 | LOD2 | Billboard |
| --- | ---: | ---: | ---: | ---: |
| Tall fir | 12,969 | 6,633 | 3,268 | 20 |
| Medium fir | 6,813 | 3,598 | 2,278 | 20 |
| Sapling | 599 | 437 | 318 | 20 |

Mesh LODs have two surfaces; billboard LODs have one. The old arena pipeline
repeated LOD2 as its far tier. This pilot preserves the original LOD3 geometry
and UVs, including atlas subregions, rather than creating generic full-UV quads.
The billboards are fixed multi-plane meshes, not camera-facing single quads.
They are suitable for a far-tier trial, but forced close-up inspection exposes
different branch silhouettes from the full meshes.

Asset preparation is cached by archive, loader, foliage shader and engine
version. It reuses the existing archive importer and wrapped foliage shader,
preserves each material's authored alpha cutoff, and generates texture mipmaps.
Each LOD is normalized to unit height with its base at zero before placement.

The runtime preparation now applies `Image.fix_alpha_edges()` before generating
mipmaps. The medium fir billboard's transparent pixels contained black RGB,
which produced a dark filtered fringe. Original/corrected renders at three
projected sizes verified a visible improvement with sampled alpha unchanged.
The original archive is not edited. `benchmarks/check_tree_edges.gd` reproduces
the comparison without loading terrain or the player's save.

## Runtime architecture

Candidate positions are stored in arc/lateral metres. Terrain-only radial rays
query the actual published collision surface, including edits, and roots use
the existing ring tangent basis. Slopes above 38 degrees are rejected. Tree
roots are sunk 8cm to close small contact gaps. Nearby trunk cylinders use
collision layer 2 and an 80m activation radius around the vehicle.

Eight candidates are checked per physics tick. A terrain body's instance ID
invalidates grounding after publication, eviction or reload; empty ray results
are retried in case physics publication has not reached the query server yet.
Unsupported or steep trees disappear; undo can restore them. Trees are not
automatically converted to falling physics objects.

MultiMeshes are separated by species, spatial cell and LOD. Mesh cells are 96m;
billboard cells are 192m. LOD uses distance scaled by tree height, nominal
thresholds 22/55/110m for a 10m tree and a 4m adjacent-tier hysteresis band.
Trees beyond 650m are omitted. Hard transitions deliberately expose silhouette
matching during this first test. No translucent cross-fades or TAA are involved.

LOD checks run at most five times/second and skip stationary unchanged views.
Only changed batches upload transforms. F6 off stops tree maintenance as well
as rendering and collisions. Allocated empty batches can be reused later; the
pilot has a fixed upper bound on candidate count and spatial cells.

## Verification

`game/benchmarks/check_tree_patch.gd` requires an explicit `--tree-output` path.
Run using a copied terrain fixture via `--drive-edits-file`; never use the
player's live terrain save for a test. The benchmark performs crater and undo
operations in memory, verifies re-grounding and eviction/reload, checks ring
orientation and source billboard geometry, and records rendered on/off timings
and screenshots. It does not save terrain edits.

Example arguments after Godot's `--`: `--baseline-profile`,
`--drive-edits-file=<absolute copied fixture>`, `--tree-output=<absolute directory>`.
Run with the graphical Compatibility renderer to measure the Intel GPU;
headless results do not measure rendering performance. Fixed-view timings are
local measurements and do not establish a universal 120 FPS forest budget.

The next asset experiment should compare UV-aware trimmed foliage cards against
the current cards at the same view and density. Opaque interiors should only be
introduced where coverage really is solid and where extra material surfaces
do not erase the fragment-work savings.

Daylight controls (2026-10-09): F1 > Daylight settings opens session-only sun angle,
sun/ambient brightness, original-lighting comparison and optional 70 m near shadows.
The controller is tree_daylight.gd; test is benchmarks/check_tree_daylight.gd.
Shadows default off: Intel UHD comparisons did not establish a 120 FPS shadow budget.

Shadow optimisation (2026-10-09): Daylight now offers Balanced (default quality),
Fast and Detailed. Balanced uses invisible 48-triangle fir silhouettes in spatial
MultiMeshes at the existing 70 m shadow range. Fast uses 45 m, one split and 1024
resolution. Detailed retains the earlier mesh/leaf-card casters. Visible tree
LODs and painted records are unchanged. Shadow lists cache by tree batch revision.
Benchmarks: check_tree_shadow_opt.gd (requires explicit copied save paths),
check_tree_shadow_proxy.gd (headless lifecycle regression). On a copied 1,340-tree
forest, total frame time improved about 17% Balanced / 27% Fast versus Detailed;
this did not recover a locked 120 FPS. Lighting choices are still session-only.

Distant edited terrain (2026-10-09): tree_edited_terrain_lods.gd restores native
render LOD index buffers for edited tiles on a worker. Full detail is forced
within 180 m of tile bounds; LODs resume beyond 220 m. Collision/vertex data and
terrain editing remain unchanged. F1 Daylight includes an independent LOD switch.
F8 now records lighting/shadow settings, tree counts/LODs and edited-LOD state.
The user's F8 trace caught a ~1.5 km camera jump with up to 126 streaming jobs;
88 remained at capture end. Do not interpret that trace as settled GPU timing.

Explicit authored-terrain render pass replaces automatic generation (2026-10-09):
F1 > Terrain rendering > Build loaded terrain LODs. Cache reads are automatic;
simplification is opt-in and covers a snapshot of loaded edited tiles. Unbuilt
far edits use cached base terrain beyond 220 m, restore full geometry within
180 m, and retain collision. Trees/proxies on hidden edit tiles are also hidden.
Stop after tile cancels queued work. F8 includes pass requests/generated counts,
hidden tiles and sun/cascade parameters. Vehicle shadow check confirmed one sun;
the apparent double shadow is the two-cascade transition. Balanced stays unchanged.

On-foot mode (2026-10-09): tree_on_foot.gd adapts the legacy sdf_demo capsule
and arena_vehicles exit clearance logic. E exits/enters the Warthog; WASD walk,
Shift sprint, Space jump, mouse look, Esc cursor. F1 restores previous walking
position or driving mode when closed. Ring gravity and streamed DEM/SDF collision
are used. Driving controller remains unchanged. F8 records movement_mode.
Validated by check_tree_on_foot.gd and check_tree_on_foot_editor.gd (isolated saves).
