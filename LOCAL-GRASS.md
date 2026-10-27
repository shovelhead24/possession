# Local grass study — 2026-10-24

Performance Demo replaces the material on streamed terrain with performance_grass.gdshader. Grass applies only within the original 3.2 km square (arc/lateral ±1600 m), with a 64 m edge blend into existing imagery. Other areas and the backdrop keep their materials.

The existing generated grass colour and height images are copied into game/assets/terrain/grass-study/. Grass repeats every 4 m. Generated mipmaps and anisotropic filtering handle distance without a separate texture. A modest height gradient affects nearby normals, fades between 25 and 65 m, and is skipped farther away. Specular is disabled; roughness is 1, metallic 0. Ring-coordinate UVs survive floating-origin shifts.

No terrain geometry, saves or source DEM assets are altered by the material. The saved-start restoration uses outputs/player-start-before-regional-satellite-2026-10-24.json from the current task, returning to arc 111.213 / lateral 161.917 near the original workshop.

The colour and height images remain studies: generation does not guarantee exact height/albedo registration or seamless tiling.

## Local wilderness blend — 2026-10-25

The local material now uses a saved 1024-square biome-mask.png spanning the 3.2 km patch. Red controls broad olive/straw distribution; green controls smaller colour variation and breaks up rock transitions; blue supplies fine ground mottling. Rebuild offline with tools/bake_local_biome.py. The deterministic bake is an art mask, not a hydrology or biome simulation.

The mask and shared grass/height/rock images load once during content preparation. There is no runtime mask generation, streaming scheduler, or warm-cache dependency. Terrain slope is evaluated relative to ring up before bump mapping, exposing rock through a soft approximately 33–55 degree transition with patch variation. Existing dry boulder diffuse supplies rock detail using two vertical projections. Fine grass colour detail fades from 18 to 110 metres; a weak 29 m grass sample bridges the middle distance and fades from 180 to 650 m. Broad mask variation remains. Nearby height bump and matte shading remain.

Only local streamed terrain changes. Backdrop and other regions keep satellite imagery; their boundary can still be visible. This does not add long grass geometry, snow, marshes, or rivers. User saves and DEM data are untouched.

