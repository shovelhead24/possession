# Shared DEM/SDF terrain and distance caches

The workshop now uses unified_terrain_field.gd for streamed collision and exterior scenery. Models and saved recipe coordinates stay in place. The full original 3D base is returned exactly within the square ±768 m; ordered edits are applied once. Outside that square a smooth height transition reaches the home DEM at 1536 m. Exterior volumetric edits retain the SDF extractor.

The home source is Millstreet 3840² R16, 23.445 m/sample, h_scale=4. Its camera pixel and signed ring arc define the mapping. Native elevation remains resident (28 MiB); coarse mesh sampling uses a four-tap box-footprint approximation. This is not a ring-wide streamed elevation mip pyramid. Two-metre collision sampling cannot invent finer real-world elevation.

The first playable integration extends to ±2016 m, with exterior scenery to ±2048 m. Fine exterior chunks keep 2 m spacing and derive vertical bounds from the source and relevant edits. Protected chunks retain their original -24..64 m volume. The backdrop meets the exterior through the same source and 128 m boundary samples. Other ring regions remain scenery.

workshop_terrain_lod.gd selects power-of-two spacing from projected sample size. Adjacent height tiles share interpolated edge samples. Replacement meshes upload one per frame and switch as a complete layout, retaining old coverage while generation runs. Resident fine chunks request the finest exterior tier. Tiles with authored volumes use 3D extraction. This is not a general volumetric transition-cell algorithm: arbitrary edited coarse/fine boundaries remain follow-up work.

Exterior height tiles cache vertex normals and a 33² world-space surface-normal texture with mip filtering. These derive from the shared source, without adding its slope twice. Protected coarse SDF tiles cache full-field gradient normals at vertices, including underside and cave-wall directions. Metre-scale PBR detail normals remain a separate nearby material effect.

workshop_satellite.gd retains at most nine 256-source-pixel home imagery pages. Native, half and quarter resolution pages have source gutters and mipmaps, selected by projected pixel size. The existing 512² overview is the distant fallback. The 8192² PNG is temporarily decoded on a worker on cache misses, then released. Other ring imagery still uses existing previews.

Fine meshes, exterior meshes/normals and imagery pages persist on disk. Source, metadata, evaluator, local edits and LOD layout identify cache entries. Old files are retained; stale entries are not reused. Workers receive immutable inputs and produce derived data; GPU and physics publication stays on the main thread. Initial generation can be slow. Report cold builds separately from warm reuse. The existing loading screen includes exterior tile progress.

Validation:
- check_unified_terrain.gd compares 2023 protected samples and five cavity/deck landmarks exactly, plus signed arc wrap and exterior DEM surface agreement.
- check_unified_lod.gd checks shared edges, base-cache identity, clockwise top faces, persistent mesh/normal reuse and identical cached imagery pixels.
- check_unified_workshop.gd runs the rendered stress workshop, probes collision at z=-780, -1024 and -1500, checks bounded imagery and saves screenshots. Inspect images as well as PASS: collision alone cannot prove visible coverage.

Keys 5/6 show the exterior transition/elevated overview; 1–4 return to existing views. F2 reopens the existing briefing. Normal and stress saves remain separate.

Remaining limits: some exterior authoring placement/recovery paths still have legacy height limits; the protected workshop remains the authoring baseline. General volumetric LOD seams, actor/tree simulation LOD and airborne prediction are separate unfinished work. No ring-wide playable streaming or continuous geomorphing is claimed.

2026-10-05 validation: protected sampling, LOD/cache units, existing brush regression and the controlled rendered workshop route passed. Rendered contact errors at the three tested points were below 0.0001 m. The final mixed-cache route reused 838 exterior results and built 225 new variants, including first-time high-altitude tiers; this is not a fully warm performance comparison. Native/half tiers were observed together and quarter resolution was asserted at 12 km altitude. Nine imagery pages remained resident. Screenshots confirmed filled top faces and the aligned outer geometry seam. The change in imagery resolution and lighting at the older backdrop boundary remains visible and needs visual blending. Saved normal recipe SHA-256 remained FB5D1D1EC8228A3B3C8D1FF9FF1CB83594752966410CAF76ECFAA9A9BFCB1F35.
