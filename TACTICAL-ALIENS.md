# Tactical aliens restored — 11 October 2026

Launch Rebuild Demo on the desktop. It still targets world/rebuild_demo.tscn and the separate Rebuild Demo saves. No player saves were used for testing.

## Restored behavior

Reference: C:/Games/possession/prototypes/first-operation, the tactical patrol/combat implementation. The lizard GLB matches that reference by SHA-256 86091C90E68AEDECC85977357083233215D4D57A339DFC41A10E7BFB828D20DD.

Four encounter sites surround the initial vehicle spawn. At most two squads are resident: one purple captain and four green grunts per squad. The nearest sites start roughly 75 and 135 metres from the initial vehicle. Approach or fire nearby to engage. E enters foot mode, G throws a combat frag, F7 resets encounters. B remains the terrain-editing grenade.

Restored: 14 animation clips, patrol formations, vision/FOV and hearing, flanking, construction cover, alternating search teams, crouching, social idle animations, small-obstacle jumps, captain grenade dives, captain-death routing and ragdolls. Contact memory transitions to hold after 2 seconds, hunt after 30 seconds, and patrol after 300 seconds. Grunts have 50 HP and captains 175 HP.

Enemy green/red plasma uses swept travelling projectiles; walls block it. Player health starts at 100. Defeat pauses combat and returns the player near the initial spawn after three seconds when a safe landing is available. Casualties survive encounter unloading within this session. F7 or restarting the application resets casualties; they are not written to the player save.

## Performance and integration

Rigs are prepared once per size during loading. The scale/translation correction is restricted to the verified lizard asset. Mesh LODs are regenerated after baking, shadows disabled, and animation updates reduce with distance. Caps: 10 active aliens, 64 hostile bolts, four combat grenades. Only three 19-body ragdolls simulate together; they settle after four seconds. Simultaneous deaths beyond the cap use the authored death pose instead of leaving upright frozen bodies. Corpses hide after 30 seconds.

Navigation uses bounded 4 m grids around encounters, sampled incrementally (12 cells / approximately 1 ms per physics tick), invalidated by terrain, construction and completed tree edits. Characters hold while routes build. Short collision feelers supplement the coarse grid. This is outdoor tactical navigation, not complete building-interior or arbitrary multi-storey navigation. Cover slots currently come from Forge construction. Terrain must be resident and finished publishing before units move.

Tab hides alien labels and the existing HUD while retaining FPS, including during respawn. The loading-screen briefing is updated and its actual rendered screen inspected. F8 traces include squad, actor and enemy bolt counts, health and manager timing. Manager timing excludes individual actor movement/animation and is not total alien cost.

## Validation

check_rebuild_aliens.gd covers clips, unit skeleton scale, memory transitions, FOV, captain dive, travelling projectile damage, wall obstruction, pause gate, captain morale, 19-bone ragdolls and cap, navigation invalidation, cleared encounters, captain casualty streaming, grenade rest fuse, explosion cover, and player respawn.

check_rebuild_aliens_world.gd covers real edited-terrain placement, moving patrols, combat, rendered briefing, HUD/FPS behavior and short performance samples. All three save paths are isolated test copies.

The 120 FPS target remains unproven and was not met in saved-world samples. Exact final results are in the chat output tactical-aliens-performance.json. These short stationary samples are not a driving-route or long combat stress benchmark.
