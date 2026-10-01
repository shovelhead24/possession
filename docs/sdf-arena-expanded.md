# Expanded SDF arena

Open `game/world/sdf_arena_expanded.tscn`. This is a separate extension of the original arena; its scene and source assets remain available.

The local arena is 768 by 768 metres. Its implicit recipe combines rolling hills, a deep winding canyon, two bored tunnels with real roofs, and a stone overpass with graded approaches. Grass and stone use the existing triplanar materials. The textured full ring remains distant scenery, not newly playable terrain.

The friendly FOB and hostile relay compound reconstruct the layouts in `prototypes/first-operation/study.gd` and `tactical.gd`. Their terrain pads share explicit elevation anchors with their meshes and collision. Gate, doors and windows retain openings. Planning/support/rearm props are visual only; old mission logic is not connected. Original Warthog, aliens, T-Rex and firs remain static scale references.

Detailed terrain streams around the camera while retaining the central actor area. A separate coarse implicit mesh supplies distant coverage. Fine borders blend to the same piecewise-linear field used by the coarse tetrahedra; both visual meshes and fine collision use the resulting samples. This is a fixed two-level prototype, not general adaptive CDLOD. Walking waits for nearby collision, and coarse terrain has no collision.

Generated vertex/normal arrays are cached under Godot's `user://sdf-expanded-geometry/`. The recipe, mesher, engine version, sampling layout and edit parameters identify entries. Cache loading disallows objects; the cache is disposable derived data, not terrain authorship. First visits still generate geometry, while revisits reuse it. Main-thread upload and collision setup remain necessary.

Controls: 0 overview, 1–4 original actor views, 5 FOB, 6 relay, 7 canyon/overpass, 8 west tunnel, 9 east tunnel. WASD and mouse fly; Shift speeds up; Space/Ctrl rise/descend; F switches walking/flying once collision is ready; T toggles textures; C toggles clouds. Original central tunnel edit controls remain available.

Verification: run with `-- --expanded-check --expanded-capture --expanded-view=3`. Checks exercise actual generated tunnel passages and roofs, deck and canyon collision, compound pad elevations, open gate/doors, blocking walls, and bounded detailed residency. Capture is saved to `user://sdf-arena-expanded.png`.
