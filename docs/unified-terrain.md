# Shared DEM/SDF sampling — first preservation gate

`unified_terrain_field.gd` is an executable sampling prototype. The playable
workshop still uses its existing field and caches. This first step does not
publish DEM collision or claim a complete terrain LOD hierarchy.

The source contract is full Millstreet elevation (3840² unsigned little-endian
R16, 23.445 m/sample, metadata h_scale=4), canonical signed ring arc and lateral
metres. Pixel origin follows the existing far-band `_dem_sample` convention:
camera_px + arc/m_per_px, camera_px - lateral/m_per_px, bilinear at integer pixel
coordinates. It does not silently adopt the CDLOD texture's half-texel convention.
RingFrame converts physical points to arc/altitude/lateral before DEM sampling.
Height detail remains limited by the source resolution.

The complete original tangent-frame 3D base is returned exactly throughout
the square ±768 m, before any transition calculations. This protects the whole
current workshop, not just the original arena, including caves and bridge
undersides. Outside it, a smooth scalar-field blend reaches the DEM radial
altitude field at 1536 m. Original ordered edits are composed exactly once after
base selection and keep their existing tangent-frame coordinates. This is a
prototype transition choice; scalar blending outside protection does not promise
distance-field accuracy or preservation of arbitrary exterior topology. Missing
DEM coverage explicitly falls back to the original local field.

The sampler snapshots the recipe and elevation. Its identity hashes elevation
bytes, metadata, ordered features, sampler source and existing evaluator/mesher
source. No existing caches are deleted or reused for this new representation.
`check_unified_terrain.gd` compares 2023 protected samples and five cavity/deck
landmarks with the user's saved recipe, checks canonical wrap, and samples one
outward -Z transition. This proves sampled field equality, not a new physical
contact or model-transform regression pass.

Next integration gates:

1. Let the field/block cache accept an immutable base sampler and include its
   identity in RAM and disk keys; use the same snapshot for picking and scenery.
2. Publish a single outward -Z sector with vertical coverage derived from DEM
   height. Current -24..64 m chunks cannot represent all source elevation.
3. Replace overlapping backdrop geometry from the same definition and frame;
   verify actual mesh seams, contacts and unchanged model transforms before
   expanding the playable bounds. A height-only backdrop cannot display caves.
4. Coordinate tree residency and actor render/animation/AI/physics budgets, then
   add aircraft prediction volumes. These are separate unfinished systems.
