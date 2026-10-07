# Nature authoring and believable grassland

## Implemented in the SDF workshop

Mountains are ordered additive field displacements, not stored meshes. Each
recipe retains its position, footprint, seed, noise choice, wavelength, octaves,
roughness, added height, water/wind strengths, wind heading and iteration count.
A worker produces a 49-square height grid over the entire feature, never separate
erosion simulations at chunk edges. Water/sediment follow the steepest neighbour,
with erosion/deposition and evaporation; wind performs directional talus transport.
The model is deliberately small and stylised, not geological or fluid simulation.
Outside the footprint the displacement is zero. Subsequent tunnel/cut operations
retain normal recipe ordering. Adding a mountain after a tunnel can distort it:
move the mountain earlier in the recipe if the tunnel should cut the new land.

Generated grids are bounded RAM derivatives, calculated only for relevant terrain
jobs; generated meshes and sampled chunk fields continue to persist on disk.
Generator source hashes invalidate stale reuse. No automatic disk deletion.
The workshop is still vertically bounded (-24 to 64 m). Placement checks the
clicked datum plus added height against 58 m; this is not a guarantee for complex
overlapping hills or tall features elsewhere in the footprint. Large-scale vertical
streaming is separate work. The noise grid is not a true distance field: continue
using sampled meshing, not unrestricted sphere-tracing assumptions.

Tree strokes are seeded scatter patches in the same saved recipe/Undo history.
They do not invalidate terrain meshes. Painted trees derive their position from
current resident collision triangles after mesh/collision publication, reject steep
slopes, and re-ground after edits. Generation is limited to 8 candidates per tick;
artist LOD meshes are rendered in MultiMesh batches, with trunk collision on layer 2.
Limits: 64 candidates per stamp, 4096 considered locally, 600 resident painted trees,
3 m dedup cells, 200 m visual cutoff. No individual tree editing yet; Erase removes
overlapping authored patches, not original arena trees. Very dense painting is
bounded rather than an unlimited forest system; chunk-local batching and smoother
distance transitions remain future work. Trees can take time to re-ground during
large edits; a standing forest is not a rigid-body destruction simulation.

## Ground material pass

Four additional CC0 PBR sets: Grass Ground, Leafy Grass, Sparse Grass, Rock Boulder Dry.
Grass Ground is the active meadow; Leafy Grass is retained for future woodland use.
Albedo, OpenGL normal and roughness are used; earlier user textures are preserved.
The material is enabled only in the authoring workshop. Real tile sizes are 2.51 m
for meadow, 2 m for sparse cover and 1.8 m for stone. An artistic green tint and
secondary-scale albedo blend make the meadow less dry/repetitive. Gentle slopes mix lush and sparse cover;
steep slopes expose triplanar stone. Two broad irregular noise scales break up
uniform coverage and colour. Height modestly biases dryness. These are artistic
proxies, not measured moisture or output from the erosion simulation.
Ground cover uses planar sampling; normals fade by distance to limit sampling
cost/shimmer. All runtime maps are at most 1K RGB8 plus mipmaps (~36 MiB for the
nine new maps before driver overhead, replacing five previous bindings).

## Next grassland layers, in order

1. Share one coverage field between material and vegetation: soil depth, slope,
   drainage/moisture proxy, authored exclusions and broad seeded patches. Use the
   actual erosion flow/sediment derivatives where available, not a second random map.
2. Near-camera clumps only: sparse 10–25 cm grass and occasional taller patches,
   10–30 m detail range, MultiMesh per small spatial cell, bounded instance/upload
   budget, dithered fade and gentle vertex wind. Sample published terrain only;
   invalidate affected cells after edits. Leave paths, tunnel interiors and steep
   faces bare. Match each clump's colour to the ground to hide LOD transitions.
3. Midground remains textured terrain with occasional shrubs/stones; distant ring
   remains the existing landscape system. Avoid carpeting the full arena in alpha
   cards or paying for per-blade collision/shadows.
4. Add deliberate ecological pattern: sheltered lush hollows, sparse ridges,
   woodland litter beneath trees, exposed soil around traffic and cut faces.
   Composition and coherent scale matter more than higher texture resolution.
5. Measure shader GPU time and total draw calls on the Intel UHD before increasing
   density or layering more PBR sets. Keep a low-cost material/vegetation setting.

Grass geometry, live moisture, tree-canopy litter masks and traffic wear are NOT
implemented in this pass. Existing performance backlog remains in
`sdf-authoring-plan.md`; these additions do not replace streaming/edit optimisation.
