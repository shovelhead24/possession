# Expanded arena

The playable footprint is 2160 × 2760 m (4 × 4 original-sized sectors).
`baked/arena.res` stores terrain meshes with render LODs, triangle collision,
the matching 3 m heightfield, tree meshes/placements, rock cover, compound
shells, squad homes and navigation masks. Startup loads this resource;
terrain generation runs only via `--headless --script res://bake_arena.gd`.
Rebake after changing `bake_arena.gd` or terrain definitions.

Sector habitats include clustered forests, treeline meadows, broad/wooded
valleys, high hills, bowl depressions and two miniature canyons (sectors 6
and 13). Canyon ends and a shallow crossing permit routes around/through
the steep sides. FOB and compound pads stay level; sector edges join.

Four 4,000-HP Tyrants initially approach (270, -1270) from four directions,
about 1.5 km away, near opposite outer corners. They prioritize visible rival Tyrants and ignore distant alien
distractions on rendezvous legs, but still respond to close threats.
Every patrol covers all sixteen sectors and revisits three common clearings:
(270, -1270), (-320, -740), (820, -1840), in X/Z coordinates.
They wait/scan for up to 90 seconds at a meeting point before moving on.
Encounters remain physical—not teleports, scripted damage or forced kills.
The outer-corner autonomous regression test recorded rival hits at 174 seconds
(previously 23 seconds). Actual timing varies with combat and obstruction.

Squads stream near the player or a Tyrant; casualties/health/positions persist
when streamed out. The original hostile relay has six additional five-alien
squads. Spawn positions preserve formation offsets and reserve 2.1 m actor
clearance rather than stacking multiple bodies at an 8 m navigation-cell centre.
Aliens do not inherit platform velocity from other moving bodies.

## Flight terrain editing

Press V to fly, then 6 and enable Terrain brush. Close the menu and aim down
at terrain: a yellow ring marks the brush. Hold Page Up / Page Down to raise /
lower it. Radius and height per stroke are adjustable in 6. The height range is
-30 to 100 m. FOB, course, track, relay foundations and rock bases are protected.
Trees follow the ground; terrain render LODs, collision and navigation are rebuilt
after edits. Editing can briefly hitch while rebuilding a sector.

Ctrl+S (with brush enabled), or Save terrain to disk in 6, writes
`baked/arena_edited.res`. The next launch automatically loads this edited bake;
the original `baked/arena.res` is untouched. Subsequent saves preserve the last
save as `arena_edited.res.backup`. Move the edited file aside to restore the base.
Unsaved edits are session-only. Saving the complete bake may pause briefly.

Combat indicators in 6 also show all four patrol circuits, each with a distinct
colour. Dim lines show planned waypoint legs; bright lines show current actual
navigation paths. Lines follow the terrain and refresh once per second while on.

Tests: `test_expanded_arena.gd`, `test_rendezvous.gd`,
`test_expanded_render.gd`, `test_trex_controls.gd`.
