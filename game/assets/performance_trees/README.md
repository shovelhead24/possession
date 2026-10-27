# Performance pine substitution

Source: user-provided pine_trees_pack_lowpoly_game_ready_lods.glb, copied unchanged as pine_lods.glb. Keep the supplier license with this asset before redistribution; no license was supplied with the standalone GLB.

Performance Demo alone substitutes render meshes through performance_tree_assets.gd. Existing saved species keys, coordinates, height, yaw and IDs remain unchanged. Mapping:

| Saved species | Pine variant | LOD0 / LOD1 / LOD2 / billboard triangles |
|---|---|---|
| Christmas tree | Pine_medium_3 | 2923 / 1703 / 992 / 16 |
| Christmas tree_2 | Pine_small_2 | 1912 / 1284 / 768 / 16 |
| Christmas tree_3 | Pine_sapling_1 | 587 / 436 / 270 / 16 |

The loader removes the source's baked 20-metre LOD row spacing using one bark-base pivot and one LOD0 height scale per variant. Mesh LOD trunk alignment is asserted. Foliage uses the existing opaque alpha-cutout shader with corrected alpha borders and mipmaps. Bark normal/metallic detail is disabled. Existing batch, distance and collision rules remain in use. Density cache fingerprints already include canopy radii and rebuild on changed geometry.

Billboard silhouettes are visibly fuller than the mesh foliage; this is an authored asset difference and should be judged at the existing 110-metre transition. Their heights are 1–4% shorter. The small variant is relatively broad when scaled to existing saved heights.

Run benchmarks/check_performance_pines.gd for the isolated visual grid and mesh audit. Full-scene tests require all four isolated save overrides documented in PERFORMANCE-DEMO.md.

20 October: pine visuals are opt-in with --pine-trees. Regular fir trees are again the default; --original-trees overrides the pine flag.
