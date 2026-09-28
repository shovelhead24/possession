# Terrain authoring and ring content integration

Automatic OSM buildings, road-centreline loading and roadside hedges are disabled
in the foundation viewer. Source data and the original ring_vibes scene remain.
Roads visible in satellite imagery or existing raster overlays are not removed.
The reported floating houses are evidence of a height disagreement; its precise
cause is not established by the screenshot alone.

## Recovered authoring implementations

April game/editor_controller.gd + game/terrain_manager.gd:
raise/lower, smooth, flatten (samples target world height on first stroke), grass
paint/erase, adjustable brush radius/falloff, mouse and controller input.
Dirty chunks are accumulated and rebuilt. Chunk lookahead streaming appears in
2c16189 (17 April); later April revisions retain the editor. Reuse brush operations,
interaction and dirty-region scheduling. Audit persistence and cross-LOD seams
before assuming them solved. These tools operate in flat XZ coordinates.

September prototypes/first-operation/terrain_editor.gd:
height brush over baked arena data, affected sector mesh rebuild, normals and LOD
regeneration, collision rebuild, tree grounding and navigation refresh.
Save writes a pending compressed resource, backs up an existing edited resource
and renames it into place; original arena bake is retained.
Useful update/save pipeline, but hard-coded arena extents, protected areas and
references to rex_menu / PracticeRange / TacticalGround must be separated.

## Proposed integration boundary

Keep ring geography as the base. Author local height/material overrides in
arc-metres and lateral-metres. One versioned surface tile must feed the rendered
near mesh, collision, editor picking, grounding and structure anchors. Coarser
LOD meshes derive from that tile; do not independently resample a different
height tier for placement. Far geography may stay coarse while local physics
uses the active tile. Define a seam/morph policy before enabling edits across LOD.

First proof: one editable patch within ring_vibes; sculpt, smooth and flatten;
place a relay and a scale marker; regenerate mesh/collision; save/reload; show
that both stay grounded across tier changes. Then bring in a stationary Warthog,
tank, alien and T-Rex as geometry before enabling their controllers.

Existing tactical controllers assume global Y-up, flat height_at(x,z), and
res:// paths relative to the separate first-operation Godot project. A rotated
parent Node3D alone cannot adapt world-space physics calls. Move reusable modules
under a common project with explicit dependencies; give controllers a local
physics frame, gravity direction and shared surface queries. Validate suspension,
feet and collision at multiple ring angles before AI and combat.

Local tangent coordinates reduce precision errors, but are not a substitute for
curvature: at this radius a 1 km tangent offset differs vertically by about 1 m.
Generate both local render mesh and collision from the same curved tile.

Bake edited tiles and derived LOD/collision before play; stream only nearby tiles.
Keep source DEM and authored overrides separately, with revisioned bake outputs,
so another bake cannot silently erase authoring.

## First prototype implemented (28 September 2026)

foundation_viewer now creates a 256 m square, 4 m grid authored_patch at home.
It samples the existing terrain once, then uses its curved triangles for render,
collision, brush picking and grounding three scale stand-ins (including a relay
cabin/antenna). These are not the production relay, actors or vehicles.
CDLOD fragments are masked inside the tile so lowering edits exposes the new
surface. Borders are pinned and brush influence fades over the outer 16 m.
This is a fixed-resolution proof, not completed cross-LOD seam integration.

F9 enables the brush, F10 cycles raise/lower, smooth and flatten. Aim using the
camera and hold PageUp/PageDown to sculpt. Brackets change brush radius; Ctrl+S
saves. Flatten samples the target at the beginning of a stroke. Saves use
user://ring-authoring/home.json with pending writes and a previous-save backup.
The lightweight terrain uses home-lite.json instead. No undo or autosave yet.
Ring-size/rebuild/height-scale shortcuts are locked while the tile exists.

The brush behavior and save sequence draw on the recovered editors, but this is
a new ring-coordinate implementation, not a wholesale port of either editor.
The original editors, DEM and scene are retained.

Validation: --author-check exercises sculpting, exact smooth/flatten behavior,
three collision ray comparisons (2 cm tolerance), marker grounding, save/reload
(1e-6 m tolerance) and a pinned border sample. Passed with real map data and the
lightweight terrain; the strengthened smooth/flatten checks ran on real data.
Test writes are isolated in test-patch.json. --author-capture captures a rendered
viewport; inspected using OpenGL Compatibility with real map data. Readiness was
6.8 seconds for that run, not a cold-start benchmark. Missing grass/tree packs
remain reported by the original viewer.

Open: material/imagery blending, near/far LOD joins, shoreline edits, undo,
multi-tile streaming, edit revision/bake pipeline, other ring-angle precision,
footprint leveling for structures and actual entity/controller integration.
An anchor grounds one point; it does not level an entire building footprint.
Local saved edits are not automatically committed or backed up remotely.

## Static content proof (28 September 2026)

content_gallery.gd loads the existing Warthog archive, Altay GLB, first-operation
lizard_rig GLB and T-Rex GLB in place; no source art is copied or modified. It
extracts the relay-only procedural layout from study.gd without mission state.
F11 visits each asset. Ring-coordinate anchors re-ground on patch rebuilds.
The old box relay is replaced by this earlier relay geometry; scale markers stay.

Static skinned poses are baked in memory before bounds normalization, because
source mesh bounds did not describe the rendered T-Rex pose. Surface materials
are explicitly retained. This needs a real renderer; the gallery is skipped
headless, and --content-check rejects headless runs rather than reporting a
misleading success. Godot's bake implementation was checked here:
https://github.com/godotengine/godot/blob/4.5-stable/scene/3d/mesh_instance_3d.cpp

Preview choices: 4.8 m Warthog length, 9 m tank length, 2.2 m alien height,
24 m T-Rex length (~7 m posed height). These are not final gameplay dimensions.
Source skin/animation/controller files remain unchanged. Static meshes have no
object collision, animations, AI or possession controls. Terrain still collides.
An upright root anchor is not multi-point suspension, feet IK or footprint
leveling. Those remain explicit integration work; do not enable old controllers
without replacing their flat world-height/gravity assumptions.

--content-check with OpenGL Compatibility passed on the real map: five entries,
posed mesh minimum Y near zero, shared triangle anchors, and re-grounding after
a terrain stroke. --author-capture --content-all captures each F11 viewpoint.
Tests edit only memory and never save home.json. Specular/gloss material
conversion warnings remain on import. Raw GLTF decoding is synchronous, one
asset per frame; bake/cache and proper streaming are not implemented. The
repository-relative external asset paths are development-only, not export-safe.

## Grass surface reference

The editable patch now uses the supplied grass texture at one repeat per 2 m,
with ring-surface UVs set on every mesh rebuild, mipmaps and anisotropic filtering.
Sculpting does not slide or reset its UVs; steep slopes stretch this planar
mapping, so triplanar/painted materials remain future work. The selected repeat
size is provisional, not a calibrated physical size from the source image.
The original C:/Games/possession/assets/grass texture.jpg is actually WebP data;
game/world/grass_texture.webp is a byte-identical project copy with the correct
extension. The original file is untouched. Only the authored patch is changed,
not the ring's satellite imagery. --author-check validates texture availability,
UV count, metre spacing, and UV stability across sculpt/save/reload operations.
