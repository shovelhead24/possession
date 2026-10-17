# Authored canopy density and forest review

Implemented 2026-10-11. Open Rebuild Demo, then F1 > Forest density & performance.

## What is cached

Species canopy radius is derived from the existing LOD0 mesh bounds and scaled by each authored tree height. A 24 m grid accumulates estimated projected canopy area; coverage uses a 3 by 3 neighbourhood (72 m across). This is canopy-derived density, not just tree count and not actual camera occlusion. Coverage above 1 represents overlapping estimated footprints.

All authored trees contribute, including unloaded placements. Add/remove/resize refreshes nine cells; moving a tree refreshes old and new neighbourhoods. Undo/redo/load compare records and update affected cells. Pure terrain-height edits re-ground trees but do not change this planar field. Unsupported authored placements conservatively remain in the density estimate.

Bake density cache writes a versioned, fingerprinted sidecar beside the selected tree save: painted-trees.json.density.json. Normal tree save also writes it. Missing or stale caches rebuild once on loading; canopy-size changes invalidate the cache. Per-tree contributions are indexed once at load for later editing. Camera movement and streaming do not regenerate coverage. Baking unsaved trees does not save their placements: use Ctrl+S to save authored work.

## Performance review

Measure this view uses two seconds of warmup and six seconds of measurement. It hides editor UI, temporarily disables cap/vsync, then restores these settings. Results include mean frame time, average FPS and p95. The forest-review.json sidecar records density identity, camera, viewport and adapter. Current source also records timestamp and terrain/construction fingerprints.

Dense cells remain candidates requiring measured review. The report lists the top 32; the dialog shows the top five. This does not automatically traverse or certify a whole forest. For vertical-slice acceptance, inspect entry/edge/interior views at gameplay height in both directions, then capture walking/driving and combat with normal shadows using F8. Target mean is 8.33 ms; also examine p95 and hitches. Recheck after relevant terrain, lighting, construction or gameplay changes. Dense-forest occlusion remains deferred.

## Optional rendering policy

The experimental checkbox applies lighter existing tree LODs earlier in crowded areas. Camera-dependent ranking caps highest-detail trees at four and the next detail at twenty, prioritising near/front trees. Close trees retain geometry. No trees or shadows are hidden by density. Existing distance-based detail is the default because measured rendering gains were inconsistent.

Shared batch uploads now avoid unnecessary instance-buffer resets and unchanged transform uploads. Existing cutout foliage materials were retained: tested shader variants did not demonstrate a reliable gain. Simplified tree shadow proxies remain. A camera-relative canopy-overlap rule is a possible future experiment, not implemented in this increment. It should first reduce detail by one level, preserve shadows and use hysteresis; overlapping canopy bounds do not prove opaque coverage.

## Measurements

Intel UHD / Godot Compatibility, 1366 x 749, uncapped, isolated copies of all three saves. Fixed-camera foliage comparisons disable/hide aliens to isolate foliage. Each sample measures 240 frames after warmup. These short samples do not establish full-game performance.

| Sample | Mean ms | FPS | p95 ms |
|---|---:|---:|---:|
| distance_only_close | 13.86 | 72.2 | 18.10 |
| density_budget_close | 17.23 | 58.0 | 27.11 |
| distance_only_edge | 9.17 | 109.0 | 12.78 |
| density_budget_edge | 9.90 | 101.0 | 13.69 |
| baseline_repeat | 13.09 | 76.4 | 17.40 |
| slice_final_close | 12.80 | 78.1 | 15.69 |

The optional policy reduced submitted close-view primitives from about 656,600 to 608,200, but did not reliably improve frame time. Moving close view: 12.36 ms mean / 17.05 ms p95; last selection cost 1.21 ms and last whole batch update 12.65 ms (not percentiles). Removing actual leaf geometry produced 10.38 ms versus 13.08 ms baseline; disabling tree proxies alone produced 12.97 ms. The earlier incorrectly positioned forest-edge sample was discarded; the final edge view was visually checked. The 120 FPS target remains unmet.

## Validation

- check_density_field: local edits, unchanged sync, incremental/full equivalence, persistence, stale placement and asset rejection, seam and renderer refresh.
- check_foliage_budget: caps, deterministic selection, immutable placements, close geometry, hysteresis and seam; warm 2,400-tree selection median 1.57 ms in CPU fixture.
- check_tree_streaming: 50,640 placements with field enabled, bounded streaming, teleport eviction, walking/car collision, paint/save/load, undo/redo and toggles.
- check_projectile_tree_index: 120 matched trunk hits across 2,400 trees including seam.
- profile_foliage_slice: rendered comparisons, forced LOD override, placement identity, all-authored field, cache round trip, review timing.
- check_foliage_review: next-start cache reuse, normal default detail, optional toggle, bake/report and timing controls.
- Final source compile and density tests passed. Loading briefing and editor visually inspected. Expanded terrain/tree panel scrolls to keep controls accessible.

Player saves were not used by tests. Rebuild Demo shortcut target, arguments and working directory were verified. Other shortcuts and shared DEM assets were not changed. No commit created.


Subsequent update: aggressive camera-relative shadow suppression is now implemented separately from density LODs. Any projected canopy overlap removes the farther tree shadow proxy. See SHADOW-OVERLAP.md / shadow-overlap-update.md for the current behavior and measurements.
