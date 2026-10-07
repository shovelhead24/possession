# Standalone implicit-terrain feasibility demo

Scene: game/world/sdf_demo.tscn. No dependency on ring_vibes, DEM files, gallery
models, or authored height saves. Uses the project's Compatibility renderer.

A roughly 48x22x40 m domain is sampled on a 1 m grid. Ground box, ellipsoid
ridge, subtractive cylindrical tunnel and box alcove, plus unioned platform,
form an implicit field. The scaled/perturbed ellipsoid is a distance estimate;
no exact-distance assumption or sphere-tracing guarantee is made.

The lattice is evaluated once per rebuild. Six consistent tetrahedra per cell
produce a triangle soup; winding uses the tetrahedron inside/outside direction
to remain robust at sharp intersections. Gradient normals provide shading.
Generation runs on a Thread with snapshot parameters; mesh upload and collision
creation occur on the main thread. Existing mesh stays until the result arrives.
This first demo rebuilds the entire block, not incremental chunks. Walkers reset
to the entrance after edits to avoid being trapped in replaced geometry.

Controls: click/mouse look, Esc release, WASD, Space/Ctrl fly vertical, Shift
faster fly, F walk/fly, Space jump, brackets tunnel radius, R irregularity.
Parameters are session-only and are not persisted.

Validation flags: --sdf-check checks the field, triangle count, open tunnel,
roof and floor collision. Add --sdf-edit-check for a larger-radius rebuild and
an automated capsule traversal. --sdf-capture saves user://sdf-demo.png after
150 ready frames and reports a 120-frame stationary average.

Measured on i5-10210U / Intel UHD Graphics at 960x600 Compatibility: 16,148
triangles; ~0.98–1.09 s generation, 44–47 ms mesh/collision install, ~60 FPS
short stationary sample. Not a whole-world performance claim. The install
pause still exceeds a 60 FPS frame budget. Main limits left open: incremental
rebuilds, adaptive sampling, chunk boundaries, LOD transitions, materials and
authoring tools. One-metre sampling cannot preserve arbitrarily thin features.
