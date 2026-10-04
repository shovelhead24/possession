# Nature PBR sources

Downloaded 2026-10-04 from Poly Haven. Assets are CC0:
https://polyhaven.com/license . Powered by Poly Haven (download metadata API).
All twelve maps are the supplied 1K tier, unmodified downloads; MD5 verified
against `https://api.polyhaven.com/files/{asset}` before use.
Albedo and roughness are JPEG; OpenGL normals are PNG. Runtime images are
RGB8, capped at 1024 square with mipmaps. Original earlier textures remain.

| Asset | Creator | Source | Physical tile |
|---|---|---|---|
| Leafy Grass | Charlotte Baglioni | https://polyhaven.com/a/leafy_grass | 2 m |
| Grass Ground | Charlotte Baglioni | https://polyhaven.com/a/grass_ground | 2.51 m |
| Sparse Grass | Amal Kumar | https://polyhaven.com/a/sparse_grass | 2 m |
| Rock Boulder Dry | Dimitrios Savva (photography), Rico Cilliers (processing) | https://polyhaven.com/a/rock_boulder_dry | 1.8 m |

Download URLs follow
`https://dl.polyhaven.org/file/ph-assets/Textures/{jpg|png}/1k/{asset}/{asset}_{diff|nor_gl|rough}_1k.{jpg|png}`.
Local names use `diffuse` instead of `diff`.

| Local file | MD5 |
|---|---|
| leafy_grass_diffuse.jpg | 0dbc071e91d6905edfcfbe8eb785a1ab |
| leafy_grass_nor_gl.png | a98f306f4dafb1e956d562b78503e174 |
| leafy_grass_rough.jpg | 05f6bb1383e12b327727d313c5899cf2 |
| sparse_grass_diffuse.jpg | 5d0aba796e1b5882555161c16b10ee9d |
| sparse_grass_nor_gl.png | a09e4b0ea1cbec68992cfae5b00c2607 |
| sparse_grass_rough.jpg | acf2fd7e352e7635f67f24ecda01e485 |
| rock_boulder_dry_diffuse.jpg | da794cd9be3db91e3160cf081109f322 |
| rock_boulder_dry_nor_gl.png | 90a2f0d635e2216aa6ce4ac927459c7f |
| rock_boulder_dry_rough.jpg | 0c8b15df3e31c15256da5f8e1b0d0759 |
| grass_ground_diffuse.jpg | 299047258586c762735b7284d3c662c3 |
| grass_ground_nor_gl.png | 2e799a8262487811e672cb8a847bd64c |
| grass_ground_rough.jpg | 2e6afca246cf6b80bdb53f46fe7e5ce5 |

Grass Ground, Sparse Grass and Rock Boulder Dry are active. Leafy Grass is
retained as an optional woodland-floor set, not loaded by default. Meadow albedo
receives an artistic green tint and a secondary-scale blend in the shader;
downloaded source files themselves are unchanged.

Raw image loading follows the existing local workshop. Export packaging must
include these images or migrate this loader to imported Texture2D resources.
