# Terrain bake pipeline — first slice

The editable JSON is the source, not the baked resource. The home tile now stores
a disposable compressed resource alongside it: `home.json.bake.res` under
`user://ring-authoring/`. Lightweight terrain and tests use separate names.

## Current behavior

- Startup reads saved source first. A matching derived cache supplies the
  detailed curved mesh (including normals and grass UVs), vertices and collision.
- Missing, stale or structurally invalid caches rebuild from source. A source
  read failure does not overwrite that file; the viewer keeps its existing
  fallback behavior and reports the failure.
- Brush strokes update mesh/collision immediately and mark the bake pending.
  They do not write source or baked files on every stroke.
- Ctrl+S saves source with the existing previous-save backup, then writes the
  bake to a pending resource, validates it, and replaces the cache. Source-save
  success is independent of bake success; the HUD distinguishes pending/failed
  bakes. A later load can regenerate a failed bake.

Cache identity covers bake version, height samples, grid size/spacing, ring
radius, tile center and UV repeat scale. Heights are quantized to one micrometre
for hashing to avoid JSON float round-trip noise around 1e-14 m. This is below
the actual mesh/physics precision, not a promise of micrometre world accuracy.
Increment the bake version when mesh construction, filtering or frame rules
change. Cache resources are trusted local generated files, not an interchange
format for untrusted downloads. They are not committed to Git.

## Derived data

Seven float32 height grids: 65, 33, 17, 9, 5, 3 and 2 samples per side, spanning
the same 256 m tile. Spacing ranges from 4 m to 256 m. Interior samples are box
filtered from the full source; edge samples retain matching source heights.
Each level records a maximum radial-height residual against fine samples using
triangle interpolation. This is not a complete screen-space/geometric error
bound: it does not include curvature chord error or between-sample extrema.
The cache also stores detailed mesh normals, UVs, bounds and collision.

## Deliberately not implemented yet

The runtime consumes the detailed cached mesh/collision. Coarse grids are
prepared and loaded, but not yet selected by the ring CDLOD shader. Do not claim
the fixed-resolution patch has become a multi-LOD renderer. Borders between
different resolutions still require a defined transition/morph policy; matching
some boundary samples alone does not guarantee watertight joins.

This is one cache per authored tile, not per-subregion dirty rebuilding. Baking
is synchronous on save/miss for this small tile. Background job scheduling,
multi-tile dependencies, neighbour halos, coarser parent invalidation, atomic
multi-file manifests and ring-wide source-data caches remain next steps.
Satellite GPU texture caches, model conversions/LODs, navigation and lighting
are not included in this change. It does not eliminate the existing DEM load.

## Validation

`--author-check` checks seven level dimensions, border preservation, metadata,
cache reuse after source round-trip, stale/invalid rejection, and ray contact
against reloaded collision, alongside sculpt/save/UV/footprint regressions.
Test files are isolated from home source/cache. Rendered smoke checks use the
existing `--author-capture` path. No source terrain or source art is deleted.
