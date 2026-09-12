# Arena integration — 2026-09-12

## Playable kit

Mouse look is captured on opening the valley. Escape releases it; right click recaptures it. C cycles seven local weapon exports, left click uses the selected weapon, and G enters/exits either nearby vehicle. WASD drives, Space brakes. The range targets are right of the FOB. Vehicles are parked left of it. Weapon aiming follows camera centre; the crosshair marks it.

Imported sources: game/fp_arms with its existing finger controller; game/halo_-_carbine; game/halo_railgun_redesigned; game/halo_warthog; game/altay_main_battle_tank_fbx.glb; the isolated workshop's blade, spear, club, improvised and rock model.glb files. Sources are local dependencies, loaded by absolute path without copying binary art into this prototype's Git history. GLTF image/buffer bytes are embedded in memory to avoid the main project's texture-import remaps. Loading the full kit can take tens of seconds on this machine. Missing sources generate warnings; the rest remain usable.

These are existing reference assets and unfinished workshop outputs, not newly approved production art. The Warthog's old specular/gloss materials produce Godot conversion warnings; their appearance needs comparison with the original project. Arms reuse the old 49-bone controller and original firearm transforms. Melee hand sockets are provisional. No claim of complete animation, IK or correct grips for every weapon.

The guns use a simple collision ray and recoil; the other five items use a short-range interaction ray. A rock is not yet thrown. No ammo, reload, damage model or enemy AI is integrated. Target hit counts establish interaction only. Both vehicles have basic capsule-player entry/checked exit, box collision, gravity, steering and braking. Suspension, slope alignment, moving wheels/tracks, original handling tables and vehicle weapons remain unintegrated. This fixture must not silently become the authoritative vehicle physics implementation.

## Resolving terrain with real height data

Preserve the latest ring_vibes CDLOD, coordinate conventions, DEM splice selection and haze as the large-scale baseline. The arena supplies a local tactical edit recipe, not a second world renderer.

1. Select an actual patch and operation anchor; inspect elevation, slope and source resolution before deciding where the valley fits.
2. Express the arena relative to that anchor. Preserve the DEM's broad slope/drainage; fit ridge/gully edits to it rather than flattening a rectangle and pasting this fixture on top.
3. Bake constrained local height deltas: building pads and access first, then tactical ridges, sheltered approaches and cover. Blend the deltas continuously to zero beyond the operation. Keep roads passable and water downhill; reject a bake that breaks either.
4. Derive collision and placement from the same composed, rendered height representation. Test foot contact, vehicle ground contact and LOD boundaries. Do not add separate invisible procedural bumps for physics.
5. Use map metadata for roads, field patterns and land-use evidence. Bake coherent boundaries, gates, drainage and vegetation exclusions against the edited terrain. Imagery remains a reference, not unquestioned close-range geometry.
6. Check the approach at eye height, vehicle height and from above before expanding to other regions. Regional generators need different structural rules, but share these height/placement contracts.

The current tactical mesh is still an authored synthetic test patch. No real DEM integration has been performed by this kit pass.

## Cloud continuity

The existing game/mocks/ring_clouds.gd is the next cloud baseline, with its cloud_layer_shader.gdshader lineage: layered coverage, drift versus churn, lighting and ring-scale integration. Preserve its behaviour and compare it in the latest ring_vibes scene before changing the appearance. The painterly pass should simplify the density/colour masses and edge treatment while retaining world anchoring and convincing slow motion. The study's alternate sky is an experiment, not its replacement. Schedule this after local terrain/asset integration and before approving outdoor asset fidelity.

## Fidelity review rules to test in this arena

- Judge silhouette and material separation at held, nearby and vehicle-distance views under the same world lighting.
- Reserve close detail for hands, grips, vehicle contact points and readable mechanical parts. Mesh/texture density must not turn simpler neighbours into toys.
- Preserve practical proportions and source dimensions; attack range is separate from mesh length. Imported branded/reference models establish comparison cases, not the final game's asset catalogue.
- Establish measured triangle, material and texture budgets plus LODs after profiling the combined scene on the target hardware. Existing assets are not evidence that their cost is acceptable at scale.
- Keep the autonomous worker paused; calibration and complete per-asset briefs remain prerequisites. Fourth-failure stop remains installed.
