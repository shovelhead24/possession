# Expanded SDF arena

Open `game/world/sdf_arena_expanded.tscn`. This is a separate extension of the original arena; its scene and source assets remain available.

The local arena is 1536 by 1536 metres. Its implicit recipe combines rolling hills, a deep winding canyon, two bored tunnels with real roofs, and a stone overpass with graded approaches. Grass and stone use the existing triplanar materials. The textured full ring remains distant scenery, not newly playable terrain.

The friendly FOB and hostile relay compound reconstruct the layouts in `prototypes/first-operation/study.gd` and `tactical.gd`. Their terrain pads share explicit elevation anchors with their meshes and collision. Gate, doors and windows retain openings. Planning/support/rearm props are visual only; old mission logic is not connected. Firs remain static; interactive launches now use the live actors described below.

## Live actor prototype

`arena_live_content.gd` preserves skinned models instead of baking their rest pose. `arena_actor.gd` adapts the alien rig's named clips and the Rex's previously established walk interval. Aliens patrol and can fire; possession enables direct movement and attack. Aliens react to an active walking/possessed target in line of sight, but leave the observer alone. The Rex has patrol/manual walking and a simple forward-area bite with additive head motion. Its earlier grab/throw/stomp/eat behavior and ragdolls are not ported. Combat is a demonstration, not a finished encounter system.

The Warthog uses the earlier wishbone/linkage/tyre dynamics with restored tactical setup, paint, sound, driver/gunner views, turret pitch and spool-up. The Altay uses its original controller, eight suspension contacts, articulated turret/cannon and procedural tracks. P while driving releases the Warthog into its patrol route. Character routes stay in the persistent central detail area and use physical collision; blocked patrols skip a waypoint after a stall. This is not full arena-wide navigation or an in-game route editor. V displays routes. AI movement pauses without nearby terrain collision; vehicles limit speed as prepared terrain runs out and suspend physics if present contacts lack collision.

On foot, the archive carbine and railgun use the earlier first-person transforms and hand poses, a separate viewmodel viewport, ray damage, ammo/reload, recoil, tracers and source sounds. Their damage routes through the live actor adapter. Tab cycles possession of aliens/Rex; E enters/exits a nearby actor or Warthog; H moves the observer beside the Warthog; Backspace releases control. WASD moves/drives, Shift runs, Space jumps or brakes. LMB fires/bites; Q switches weapons; R reloads on foot (still terrain detail in observer mode). P toggles character patrol/hold or sends a driven vehicle on patrol. Y resets actors, vehicle, health and ammo. Death returns a controlled actor/player to observer mode.

Use `-- --gameplay-check --gameplay-capture` for live verification. It checks skin/clip retention, patrol motion, ray damage, alien fire/death/reset, Rex bite, weapon switching, possession/release, and actual four-wheel vehicle driving. Captures are saved as `user://sdf-arena-gameplay.png` and `user://sdf-arena-railgun.png`. Terrain-only check/capture flags intentionally retain the static content adapter for deterministic terrain tests.

The expanded arena now spans 1536 x 1536 metres. Detailed terrain streams around
the camera while retaining the central actor area and neighborhoods under both
vehicles. Its regional tiers are 2m near samples, 8m middle samples and 16m far
samples. Fine borders match the piecewise-linear coarse field; the middle region
blends to the far field at its outer boundary. This is not general adaptive CDLOD.
Walking waits for nearby collision; coarse layers have no collision.

Two bounded worker jobs generate/cache arrays off the main thread. Main-thread
installation uses a soft time budget, but an individual upload/collision creation
can still exceed it. Complementary opaque dithering fades chunk adoption and
retirement. Reusable mesh/collision chunks have a count and estimated-byte cap;
this is not an OS memory reservation. Vehicle look-ahead prepares a travel-time
corridor, protects present contacts and limits speed if collision preparation
cannot keep up. Frozen vehicles do not accumulate suspension forces.

The original tactical Warthog and Altay controllers, articulated suspension,
turret/cannon, paint/tracks, sounds and tuning menus have been restored. K focuses
the tank, E enters/exits, C switches vehicle view, G switches Warthog seat and F2
opens tuning. Legacy saved tuning is read as a fallback without overwriting the
legacy files.

The current scene is separately preserved for the visual ray-marching experiment;
see `terrain-raymarch-comparison.md`. That experiment does not replace this scene.

Generated vertex/normal arrays are cached under Godot's `user://sdf-expanded-geometry/`. The recipe, mesher, engine version, sampling layout and edit parameters identify entries. Cache loading disallows objects; the cache is disposable derived data, not terrain authorship. First visits still generate geometry, while revisits reuse it. Main-thread upload and collision setup remain necessary.

Controls: 0 overview, 1–4 original actor views, 5 FOB, 6 relay, 7 canyon/overpass, 8 west tunnel, 9 east tunnel. WASD and mouse fly; Shift speeds up; Space/Ctrl rise/descend; F switches walking/flying once collision is ready; T toggles textures; C toggles clouds. Original central tunnel edit controls remain available.

Verification: run with `-- --expanded-check --expanded-capture --expanded-view=3`. Checks exercise actual generated tunnel passages and roofs, deck and canyon collision, compound pad elevations, open gate/doors, blocking walls, and bounded detailed residency. Capture is saved to `user://sdf-arena-expanded.png`.
