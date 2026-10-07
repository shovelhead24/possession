# SDF expanse material sources

User-supplied downloads, 2026-09-30. Original archives remain in Downloads.

- `limestone.jpg`: `rough-limestone-drystone-1656-mm-architextures.jpg`. Colour only; no invented normal or displacement map. Physical width 1.656 m is provisional, inferred from filename, not verified metadata. License not supplied: verify redistribution rights before publishing these assets.
- `grass_albedo.png`, `grass_normal.png`: albedo and explicitly OpenGL normal from `whispy-grass-meadow-unity.zip`. Archive also contains AO, height, metallic PSD, and preview; these remain in the original archive and are not required by this material. License not supplied: verify redistribution rights before publishing.
- `rock_albedo.png`, `rock_normal.png`, `rock_roughness.png`: diffuse, normal, roughness from `mossy-granite-rock-surface_boracity_1k.zip`. Included README identifies Boracity, OpenGL normals, seamless 1024x1024 maps, free personal/commercial use with optional attribution. Displacement remains in the original archive. Provider: https://www.boracity.com .

Source images are copied without alteration. Runtime copies are capped at 1024 pixels with mipmaps; no geometry displacement, physics changes, renderer switch, or engine upgrade. Source PNGs/JPG must be explicitly included for export, since this local prototype loads them with Image.load_from_file.

Triplanar colour and approximate world-space normal detail remain anchored across chunks. Upward terrain blends into grass; walls/undersides use mossy rock. Bridge CSG versus ground selects masonry (including its underside), not grass. This shader duplicates the current bridge/ground field for classification and must change if those authoring parameters change. Future material IDs should come from the recipe. Limestone mapping is a surface treatment, not structurally laid arch masonry.

Press T to compare flat/textured rendering. Existing controls and collision are unchanged.
