# SDF authoring and streaming plan

Updated 2026-10-03. This is agreed direction and planned work, not a claim that
the editor or the follow-ups below have been implemented.

Implementation update: a first [working SDF workshop](sdf-authoring-workshop.md)
now implements the seven feature tools, ordered recipe save/load, undo/redo,
centre placement/drag, local invalidation and persistent mesh caches. The workshop
is separate from the expanded arena; see its scope/limitations before treating
the broader milestone or performance backlog below as complete.

## Standing storage rule

Save procedural seeds/parameters and ordered authored features as world source.
Generate only needed terrain, retain generated meshes on disk by default, and
stream valid cached meshes on subsequent visits and sessions. Authoring does not
require pre-generating unvisited areas. Editor previews that generate reusable
chunks should follow the same persistent cache path.

RAM eviction and disk retention are separate policies. Do not automatically purge
disk caches, including obsolete revisions, unless explicitly directed. Purging is
housekeeping for now; revisit packaging, cache budgets and selective pre-baking
near shipping. Invalidated data must not be reused merely because it is retained.
Cache identity must cover relevant recipe dependencies, mesher/version, sampling
resolution and boundary dependencies. Use atomic writes and reject invalid data.
Source recipes must survive any cache purge. See the standing terrain decision.

Current arena already has disk mesh-array caching. Authored feature revisions,
dependency-local keys and editor integration remain to be implemented; persisting
cooked collision resources is a separate measured optimisation, not yet done.

## First complete authoring milestone

Build a small reusable feature editor rather than another scene-specific brush.
Reuse proven earlier tools where suitable after inspecting their assumptions.

- Raise/lower landforms, flattening pads and subtractive carve volumes.
- Spline ridges and tunnel paths with editable profiles and falloffs.
- Bridges: endpoints, deck height/profile, width, thickness, and support/arch
  parameters; compose solid deck/supports and open clearance into the terrain
  recipe. Show resulting collision clearance, not only a decorative mesh.
- Selection, transform/shape handles, numeric properties, explicit composition
  order, undo/redo, save/load and deterministic replay.

One evaluator serves preview and runtime generation. Spatial indexing limits
each chunk to relevant features, including blend influence. Terrain coordinates
must fit the shared ring/local coordinate contract; camera-relative coordinates
are not saved authoring coordinates. Materials remain stable when terrain edits.
Editing invalidates affected chunks and boundary neighbours; do not regenerate
the whole arena. Keep old visual/collision terrain until a coordinated safe
replacement is ready, especially beneath active vehicles.

Acceptance: create a hill, tunnel and bridge; edit and undo each; save/reopen the
recipe; drive across/through them with matching collision. Revisit and relaunch
to verify valid mesh cache reuse. Edit one feature and verify local invalidation,
no stale geometry reuse, intact neighbouring seams, and retained old disk files.
A fresh cache namespace must reconstruct the same terrain from the recipe alone.
An unvisited distant authored site must not force mesh generation on save/load.

## Performance work retained, not replaced by the editor

Completed: indexed tetrahedral meshing with shared normals, stage profiling,
geometry equivalence tests and cold/warm driving baseline. Preserved original
mesh snapshot and ray-marched comparison remain available. See
[measured results](terrain-streaming-profile.md).

Priority follow-ups:

Progress 2026-10-04: sampled-field/kernel caching and local section remeshing are
implemented for the workshop; generated field/mesh state remains on disk.
The separate [grenade destruction lab](terrain-destruction-lab.md) tests warm
small cuts with live Warthog physics and staged collision handover. This does not
complete cold streaming, finer volumetric LOD, long-session or shipping work below.

1. Measure actual launch-to-playable time, separating terrain, models/textures,
   ring background and cache state. Investigate the recorded post-benchmark
   shutdown access violation; do not label it fixed without reproduction/testing.
2. Collision generation/activation and resource retirement: measure beyond the
   current CPU call timers, reduce indivisible installation stalls, preserve
   contact safety. Assess separate collision resolution or persistent collision
   data only with vehicle/tunnel clearance regression tests.
3. Reconcile look-ahead distance with stopping distance and available coverage;
   keep safety backpressure but avoid unnecessarily restricting driving speed.
4. Remaining field evaluation: avoid repeated height work per vertical column,
   spatially cull features, retain deterministic results. Benchmark before
   choosing native Marching Cubes or another mesher; no algorithm switch is yet
   committed. Thousands of overlapping definitions are not free.
5. Idle-time/background radius expansion and directional prefetch to persistent
   disk cache. Bound RAM, worker concurrency and main-thread installation; pause
   speculative work when gameplay needs resources. Measure cold, warm and edited
   routes; do not assume disk reads remove collision/upload costs.
6. Proper volumetric LOD transitions and feature-aware detail, especially bridge
   decks, supports and tunnel openings. Evaluate transition meshes/Transvoxel
   against current border blending, including stitching cost and collision
   continuity. Preserve ring-scale distant scenery and existing CDLOD research.
7. Keep the fair visual mesh/ray comparison separate from driving throughput.
   Direct ray marching is experimental, not the default or a prerequisite for
   SDF authoring. Extend comparison only with matched layouts and settings.

Track raw-image export safety and synchronous model loading as separate startup/
packaging concerns. Preserve map, sky/water and ring-coordinate integration work;
the authoring milestone does not replace those systems. Do not restart automatic
road/building placement as part of bridge authoring.

Shipping cache size/purge strategy and consolidation of very long edit histories
are deferred, not implicit permission to discard caches or authored source.
