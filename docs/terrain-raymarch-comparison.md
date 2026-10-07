# Preserved mesh arena versus visual ray marching

The original working arena is untouched. `game/benchmarks/mesh_snapshot/world/`
contains a separate copy of its world scripts, scenes, materials and source
textures as of 2026-10-01. Internal `res://world/` paths were mechanically
redirected to the copy. Copied UID/import metadata was removed to avoid duplicate
resource identities; original metadata and assets were not deleted. Imported
models, ring textures and scripts outside `world/` remain shared repository
dependencies, preserved by Git rather than duplicated into the snapshot.

Original saved scene: `res://benchmarks/mesh_snapshot/world/sdf_arena_expanded.tscn`.
Controlled mesh test: `res://benchmarks/terrain_mesh.tscn`.
Visual field test: `res://benchmarks/terrain_raymarch.tscn`.

## What is matched

Both tests derive from the same frozen arena. They use identical camera presets,
960x600 resolution, Compatibility renderer, sun/environment, grass/stone material
code and original ring background. Both display posed Warthog, Altay, aliens,
T-Rex, trees and the two compounds. Static poses avoid non-identical AI movement
between independent runs. Physics mesh generation and collision remain unchanged
in both. This is a visual rendering experiment, not an SDF physics replacement
or a measurement of startup/memory savings.

Before ray benchmarks, a 64-pixel GPU field probe compares the GLSL recipe against
the frozen CPU field at both tunnel portals/interiors, bridge/supports, pads,
home shapes and outer hills. Readback is 16-bit encoded over a 512-unit range;
the expected quantisation error is about 0.004 field units. A difference above
0.03 refuses the benchmark. This checks selected formula evaluations, not a proof
of safe stepping or all possible rays.

Shadows are deliberately OFF in BOTH controlled variants: the ray-marched terrain
does not yet supply a shadow pass. The saved original scene retains normal
shadows and gameplay. Mesh triangulation/LOD and continuous ray-marched surfaces
are inherently different approximations of the same layout; this is not a claim
of identical pixel quality. No extra features or terrain simplification were added.

## Ray renderer

A back-face-rendered arena bounding box launches one ray per covered pixel.
The GLSL field is a port of the frozen `expanded_height` and `expanded_field`,
including the outer hills, canyon, grading/pads, tunnel cuts, ridge, cover,
ledge, overpass and supports. It writes actual hit depth and lighting position,
then reuses the baseline's triplanar material and Godot lighting.

Step count is configurable from 32 to 4096. Field magnitude is divided by an
experimental factor of 8; **this is NOT a proven distance/Lipschitz bound**.
The hit tolerance is 0.025 field units, not a certified 2.5cm spatial error.
Positive-to-negative crossings are refined by twelve bisection iterations;
this does not catch wholly skipped thin features. No direct-field physics exists.

Magenta marks step-budget exhaustion. Images and reports must be assessed
together: FPS with missing surfaces is not a quality-equivalent success.
Reports count approximately magenta diagnostic pixels; this does not detect all
possible missed geometry. Disabling diagnostics is an explicit optional shader
experiment, never the default comparison. Feature bins, conservative local bounds,
distance/noise LOD and adaptive render resolution are NOT implemented yet.

## Measurement

`--terrain-bench --bench-view=3 --bench-seconds=10` locks input/camera, disables
VSync/frame caps, waits for chunk installation, assets and ring previews, warms
up, then measures actual wall-clock frame intervals. It reports mean throughput,
median and p95 frame time, settings, camera, GPU and quality diagnostics. It writes
JSON and PNG under `user://terrain-{mode}-view{index}`. Camera indices are 0
overview, 1 FOB, 2 relay, 3 canyon/overpass, 4 west tunnel, 5 east tunnel, 6 outer
hills. Run variants sequentially, not together. Repeat runs and inspect background
load before drawing conclusions; these are whole-scene times, not isolated GPU
timestamp timings.

The output-folder launcher `Open-Terrain-Comparison.ps1` selects Snapshot, Mesh or
Raymarch. `-Benchmark` runs a timed test and copies its result into that folder.

## Why feature selection matters

Compact formulas and repeated instances reduce definition storage, not necessarily
per-pixel evaluation cost. A scalable renderer needs spatial feature lists/bounds,
so each query evaluates only relevant shapes. Detailed bridges can be prioritised
independently from distant noise. A step cap bounds runtime but cannot make an
overloaded ray accurate: exhaustion requires a diagnostic or explicit fallback.
