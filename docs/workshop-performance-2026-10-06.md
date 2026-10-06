# Workshop performance investigation — 2026-10-06

The finished-product target is steady 60 FPS (16.67 ms per frame), including the
bridge drive. This iteration does **not** meet it. A stationary FPS improvement
does not establish moving performance or acceptable tail latency.

## Reproduction and measurements

Godot 4.5.1 Compatibility, Intel UHD Graphics, requested 1280x800 window (reported
render viewport 1280x749), vsync disabled in benchmarks. Each run used one engine
instance; the console wrapper is the parent of that engine. Existing playtests
were closed only with permission. Saved recipes and persistent caches retained.

The user's October 6 F8 capture lasted 72.15 seconds, with 45 stalls over 500 ms
and a maximum recorded gap of 1.35 seconds. Terrain recipe planning repeatedly
scanned all features for 220 tiles. The old scan measured 881 ms in isolation;
the indexed unchanged plan measured 1.04 ms (later 644 ms versus 0.68 ms).

| Settled view | Baseline FPS | Initial optimized FPS | Initial optimized p95 frame ms |
| --- | ---: | ---: | ---: |
| Starting overview | 19–22 | 34.8 | 40.46 |
| Bridge view | 24.5 | 43.4 | 32.63 |

An intermediate bridge run reached 50 FPS; this is not a guaranteed rate. The
120-frame windows are short diagnostics, not a long-session stability claim.
Starting-view submitted triangles fell from 3.47 million with cascaded shadows
to 2.42 million with one shadow map, then 0.77 million with vehicle mesh LODs.
Draw calls remain high: approximately 1044 in that starting view.

Subsequent experiments batch rigid tank parts by material, cache the suspension
inverse-search table, and optionally generate border-locked terrain render LODs.
Batching reduced starting-view draw calls to roughly 453 but increased submitted
triangles; its net performance benefit remains unproven. Later rendered tests
varied substantially, including lower performance with 3D disabled. Do not
compare these runs as a controlled before/after result. The latest moving test
was only 17.2 FPS, despite passing streaming safeguards at 44.3 m/s. No build is
approved for handoff at the requested 60 FPS target.

The terrain render LOD test covers flat and curved borders, warm-cache equality,
and exact collision-face equality against the original full-mesh pipeline. A
flat test chunk reduces from 512 to 62 rendered triangles while preserving all
64 border edges. The suspension cache matches the original inverse solver over
2001 samples with zero measured position error, including travel-limit inputs.

`--terrain-render-lods`, `--terrain-occlusion`, and `--cached-cloud-noise` remain
experimental switches. Occlusion uses nearby exact opaque terrain meshes and
never disables collision. Its retained set is bounded by distance, and edits or
mesh replacement immediately hide stale occluders before deferred deletion.
`check_terrain_occlusion.gd` verifies those cases and unchanged collision. The
noise-lattice experiment has no demonstrated frame-time gain and changes the
noise pattern; it remains off by default.

## Changes

- Index exterior feature footprints once per recipe revision; retain ordered
  local recipes and skip unchanged LOD plans. Compare against the original
  relevance filter across every exterior tile, including boundary cases.
- Share immutable detached worker recipe snapshots per revision, reuse demand
  within one process callback, and use hash membership for chunk retention.
- Cache generated rigid vehicle LOD indices by source content and engine version.
  Full-detail vertices/materials and moving hierarchy remain intact. Skinned and
  blend-shaped meshes are excluded. Both cold generation and warm cache use ran.
- Cache prepared fir meshes/materials, keyed by archive, preparation sources and
  engine version. The tactical reference revealed that generic crossed quads
  misuse the fir atlas. Use source LOD0/1/2 and retain atlas-safe LOD2 at distance.
  Only the nearest tier casts shadows. Skip unchanged MultiMesh uploads. F4 and
  the Show trees checkbox toggle original/painted visuals while keeping collision.
  Actual archive cold/warm cache checks passed (9.35 s versus 0.47 s).
- Use one nearby directional shadow map. Preserve vehicle/bridge shadows while
  suppressing separate shadow draws for tiny projected vehicle fittings, with
  hysteresis and restoration up close. This shortens distant dynamic-shadow reach.
- Skip cloud gradient/top-lighting calculations when viewed from below, where the
  existing shader selected transmission lighting. Keep top lighting from above.
- Add bounded rendered-frame history to F8 capture alongside wheel, physics and
  streaming samples. Performance monitor CPU values are rolling measurements,
  not additive exclusive timings; wall-frame intervals are the primary metric.

## Checks and remaining work

`check_visual_lod.gd` verifies cached index equality, unchanged full-detail mesh
attributes/materials, the old billboard helper geometry, tree bands and near-shadow
recovery. `check_vehicle_trace.gd` verifies ordered persisted frame/vehicle capture
and bounded history. `check_unified_lod.gd` covers feature-index membership, immutable
snapshot invalidation, DEM edges and normal/satellite caches. Rendered profiles
also assert that actual imported workshop trees preserve atlas-safe far meshes
and cast shadows only in the nearest tier. `check_tree_cache.gd` compares every
cached surface array and verifies material retention. The rendered toggle test
passed for original and painted trees: roughly 30.3 FPS on, 32.1 off, 28.9 restored.
That short starting-view sample does not identify trees as the main bottleneck.

The user's tactical reference is `C:/Games/possession/prototypes/first-operation`.
Its final expanded version is not a verified 60 FPS baseline; the user recalls
60 before expansion. It uses baked tree assets, near-only tree shadows and a
42 m directional shadow range. Its baseline sky has no five-layer cloud stack;
its optional painterly sky uses three noise samples in the sky shader. Alien
GLB hashes match the workshop, but tactical has scale baking, distance-based
animation updates, elite materials and richer controllers/ragdolls. Comparison
is ongoing; those behaviours have not yet been ported wholesale.

The cached stress drive reaches approximately 44.3 m/s without streaming braking,
power reduction or collision starvation, and forced starvation still freezes and
recovers safely. Moving FPS remains below target and varies with background cache
work. Native collision creation, mesh uploads, background LOD work, high draw-call
count and full-screen shading still need profiling and budgets. Cold generation
is explicitly separate from warm rendering. Do not purge caches to make a test
look different or disable safety backpressure to claim improved speed.

Use `profile_workshop_frame.gd` for settled views and `check_stream_drive.gd --
--authoring-diagnostic --stress-course --drive-ablation` for the moving route plus
settled lighting isolation. The latter waits for outstanding terrain work before
its stopped-view comparisons. Earlier non-settled ablation results are exploratory
and must not be treated as matched lighting measurements.

Remaining unified-terrain work includes volumetric LOD seams (visible distant
bridge gaps), backdrop shading continuity, exterior authoring height limits and
airborne streaming. None is declared solved by this rendering pass.
