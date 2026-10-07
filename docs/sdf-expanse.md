# SDF expanse streaming proof

Scene: game/world/sdf_expanse.tscn. Inherits the small demo's camera/player and
parameterized tetrahedral mesher, supplying a global landscape field. It does
not load the ring viewer, DEM imagery, gallery models or authored tile saves.

Scope: 512 x 512 m bounded horizontal domain, y=-12..44 m, 32 m chunks, uniform
2 m sampling, 5x5 active neighborhood. Four landmarks: original tunnel/inset,
larger ellipsoidal ridge/pass, subtractive elliptical arch in a stone bridge,
and a basin in low-amplitude rolling ground. Field values are distance estimates,
not universally exact SDFs. There is no whole-world resident volume.

One worker snapshots radius/roughness and evaluates one nearest missing chunk.
Returned geometry installs with matching collision on the main thread. Chunk
keys, source revision and current desired neighborhood reject obsolete results.
Out-of-range scene nodes are queued for deletion. At most 25 dictionary-resident
chunks are retained; nodes being freed may briefly overlap for one frame.
Shared lattice positions and tetrahedron decomposition agree at equal-resolution
chunk faces. This is not a mixed-resolution transition solution.

Live controls only affect two finite ridges, so padded operation bounds mark
intersecting chunks stale. Unaffected nodes keep their geometry and advance the
revision. Changes return the player to fly mode to avoid mixed-edit collision.
Walking holds when its surrounding 3x3 collision neighborhood is unavailable.
F walks from the highest surface at the camera's horizontal position. No caves
are selected by that drop ray; enter them from outside. Flying can outrun loading.

Test flags: --expanse-check validates chunk edge collision, field cavities,
camera relocation and eviction; add --expanse-edit-check to assert unaffected
node retention and walk under the bridge across streaming boundaries.
--expanse-capture samples 120 steady frames after loading and saves
user://sdf-expanse.png. Original --sdf-check --sdf-edit-check regressions pass.

Measurements: initial headless chunks ~173–449 ms, rendered ~219–638 ms during
the checked run; install ~4–17 ms. Steady bridge view: 54,786 resident triangles,
25 chunks, ~60 FPS at 960x600 on i5-10210U/Intel UHD. Short display-limited sample,
not a traversal/worst-case benchmark. Other checks overlapped part of generation.

Open: distant coverage (current streaming edge is visible), fine near-field
resolution, LOD transitions, disk caching, material design, exact-surface error
bounds, larger coordinate precision, region authoring and ring integration.
The small original demo remains available with 1 m sampling; no previous saves
or source assets are replaced.

## Material pass (2026-09-30)

User-supplied limestone colour, meadow grass albedo/OpenGL normal, and mossy
granite albedo/OpenGL normal/roughness are wired through materials/expanse.gdshader.
World-space triplanar mapping, slope grass/rock blend, analytic bridge material
selection. Raw source images unchanged, runtime capped at 1024 with mipmaps.
See game/world/materials/README.md for provenance and export/licensing caveats.
T toggles diagnostic flat shading. Lighting reduced to avoid pale stone clipping.
--expanse-bridge starts at the bridge overview; --material-close starts nearer.
Neither changes geometry, generation, collision, renderer, engine, or saved data.

Rendered check on Godot 4.5.1 Compatibility/Intel UHD: no shader errors;
1280x800 close bridge sample ~59.7 FPS, 25 chunks / 54,786 triangles after loading.
Streaming edge/cavity/eviction tests and localized edit plus bridge traversal
regression passed. Still a coarse geometry prototype, not final arch masonry.
An additional rock-heavy close view measured ~46 FPS before avoiding unused
grass/rock texture samples outside slope transitions; frame rate is view-dependent.
