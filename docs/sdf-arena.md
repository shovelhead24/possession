# SDF arena in the ringworld

Run `res://world/sdf_arena.tscn` with Godot 4.5.1 Compatibility. The chat's
Open-SDF-Arena.ps1 launches it at 960x600. Original demos remain available.

The local arena is a 192 x 192 m implicit recipe: a gently rolling clearing,
low edge berms, a carved rock tunnel, cover outcrop and a raised ledge. Thirty-six
32 m chunks generate nearest-first on the existing worker, using 2 m samples.
The fixed arena retains those chunks; it does not evict them as the camera moves.
Finer geometry and mixed-resolution transitions remain future work.

The Warthog, three aliens and T-Rex reuse the gallery's original source importer,
rest-pose mesh baking, bounds normalization and materials. They are static models
with simple obstacle collision, not combat AI, animated characters or a drivable
vehicle. Actor placement samples the actual terrain collision triangles; the
Warthog also fits its footprint. Placement rays use layer 1, obstacles layer 2.
Edits affect only the tunnel ridge, away from the fixed actor/tree anchors.

Twenty-four deterministic firs currently pass the slope test. Tree rendering
reuses the archived fir pack, the ring's foliage material preparation, normalized
artist LOD meshes, and distance buckets in MultiMeshes. Trunks have simple
collision. These are scenery, not destructible trees. The seed is stable.

arena_ring_background.gd reuses ring_vibes via foundation_viewer without starting
its gameplay controller, home authoring patch, CDLOD bubble or automatic props.
The full 3,000 km circumference / 50 km width is real curved geometry. Existing
coarse DEM mips provide its relief; all 35 satellite splice previews plus home
imagery decode sequentially on the existing preview worker and use its disk
cache. Full-resolution home imagery/heightfields are not resident. This is the
textured far-band representation, not the full nearby CDLOD/ocean renderer.
The background has no collision: exploration in this scene is local to the arena.

A new band tessellation closes the old 262 km CDLOD gap. Added near rows flatten
the distant surface around the arena and blend toward geographic relief over
3.5 km. A material cutout reserves the local square for the SDF geometry. This
is a prototype transition, not seamless authoring of the surrounding geography.
The existing ring sky, rim walls, containment field and cloud layers are reused.
Sun, sky, props and distant terrain share the same phase/direction. Existing
distant haze tuning is retained. Local terrain uses the supplied grass and rock
materials; bridge classification is disabled for this scene.

Controls: 1 overview, 2 Warthog, 3 aliens, 4 T-Rex; click/mouse look, Esc release;
WASD movement; Space/Ctrl rise/lower when flying; Shift faster; F walk/fly once
local collision is ready; Space jump when walking; T texture comparison; C
cloud visibility; [ / ] tunnel size; R rock detail. Walking waits for adjacent
arena collision while loading. Walking/flying stay within 90 m of the centre.

--arena-check verifies all arena chunks, actor support and obstacle collision,
player floor contact and Warthog obstruction, tree population, full imagery and
ring dimensions.
--arena-capture fixes the overview camera and writes user://sdf-arena.png after
loading. Runtime captures/tests require a renderer for the existing pose baker.
DEM imagery remains in the preserved local data directory; its absence is an
external asset dependency, not terrain authoring data loss.

Verified on Intel UHD / Compatibility: 36 local chunks, five supported actors,
24 tree instances, all 36 imagery previews, player floor contact and obstruction
by the Warthog. Clean shutdown after owning the inherited contact-debug helper.
Earlier expanse collision/landmark/eviction regression also passed. Initial
overview ~36 FPS; adjusted overview ~42–45 FPS at 960x600. These are short
stationary observations, not worst-case frame-time measurements.
Final edge-readiness/floor/Warthog obstruction run passed, clean shutdown,
39 FPS in its capture.
