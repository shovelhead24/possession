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
