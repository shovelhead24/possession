# Arena backdrop ownership and zero seam

2026-10-05: the SDF authoring workshop extends to +/-740m, but inherited a
backdrop opening of only +/-96m. The unrelated, non-colliding map mesh could
therefore cover the actual SDF surface. Its opening now derives from the scene's
movement limit, rounded out to a 32m chunk boundary (768m for this workshop).
No backdrop faces are emitted inside this square; the shader also clips using
ring arc/lateral coordinates rather than world X/Z (which confused the far side
of the ring with the local arena).

All background height sampling first normalises arc to the signed half-ring
interval. Splice lookup already handled periodicity; home DEM and procedural
fallback did not. The fallback imagery now uses that same signed coordinate,
avoiding a texture phase jump between -100m and circumference-100m.

The nearby +/-8km square is a separate mesh with nominal 128m spacing plus
coarse boundary anchor rows. The outer band omits this square. Fine boundary
vertices interpolate actual coarse edge positions, including ring curvature,
so no runtime stitching jobs are introduced. The distant ring remains coarse.
This adds roughly 18k local vertices, not fine lateral rows all around the ring.
Near heights still come from the existing 512-square DEM tier: denser triangles
improve shape interpolation, not the underlying data resolution. The local
height transition uses square distance consistently with the arena opening.

The map backdrop remains scenery, not a second physical terrain. The visual test
exposed gaps it had been hiding between streamed chunks. `workshop_far_terrain.gd`
now fills those with 36 coarse SDF tiles (256m each, 16m samples), derived from the
same ordered authored recipe. These non-colliding meshes are hidden wherever a
published detailed chunk owns the surface, including empty cuts. They use a
separate field cache so they cannot contaminate editor picking. A single worker
shares the two-job ceiling with fine terrain; edits take priority. Only changed
recipe tiles are regenerated; disk caches persist under `sdf-authoring-meshes/scenery`.
Initial loading counts the scenery tiles before admitting play. Later launches
reuse them. This is coarse pre-generation of the small workshop, NOT a whole-ring
bake or detailed pre-generation of unvisited terrain.

Coarse/fine SDF edges are a visual LOD approximation, not an exact transition mesh;
small cuts and tunnels can disappear in the 16m scenery tier. Detailed terrain is
still required for physics. An exact authored-terrain-to-DEM boundary blend and
distant playable terrain remain separate work. Saved SDF recipes are unchanged
and old caches are not deleted.

Regression: `benchmarks/check_arena_backdrop.gd` verifies periodic source
sampling (including explicit DEM/noise fallback), the zero seam, no emitted
triangles over the arena, and fine/coarse edge alignment. Workshop flag
`--authoring-backdrop-check` captures central and outer streamed views without
saving edits; optional `--backdrop-shot=<absolute prefix>` writes two PNGs.
`benchmarks/check_workshop_far.gd` checks authored scenery, cache reuse and Undo.
