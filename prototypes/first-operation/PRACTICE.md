# Arena forest and first combat practice pass

The Warthog keeps its existing wishbone solver, contact rays and spring/tyre forces. Only its visible structure changes: thicker angular-section arms, dark damper bodies and fixed brackets/crossmembers connect the suspension hardpoints into the chassis. H still exposes the mechanism and its diagnostic coils. This is a Warthog-inspired rendering pass, not a restored source-model suspension rig.

The arena contains 150 seeded firs from the existing realistic fir pack, with three variants, grounded trunk collision and distance-batched MultiMeshes. The ring_vibes foliage fixes are reused: wrapped lighting, double-sided normal correction and normalized LOD sizing. Runtime textures gain mipmaps. The far band retains LOD2 geometry because the generic crossed-quad shortcut misreads this pack's billboard atlas. This bounded arena does not need the ringworld's 27,000-tree optimization. The suspension lane, primary approaches, FOB/compound and practice lane are excluded from planting. Trees use the same authored arena height field, not imported DEM placement data.

## Practice

Find the E / RESET PRACTICE console just beyond the FOB, beside the existing range. Shoot a practice enemy to activate the group. E at the console resets the group and player health. The three simple combat rigs are provisional mechanics tests, not final species or character designs:

- Orange scout: low health and lateral movement.
- Blue guard: frontal shield; flank to bypass it or break it with damage.
- Red heavy: slow approach, armoured body and a vulnerable high eye.

Eyes enlarge before a shot; the shot aims at your earlier position, giving time to move. Walls and trunks block firing rays. Practice enemies pause while driving or adjusting vehicle settings. Defeat returns the player to the FOB; reset at the console for another round.

Q cycles weapons, left mouse fires, R reloads away from the FOB planning table. The carbine fires while held and has 24 rounds; the railgun has six rounds and a slower firing interval. Both use the existing local audio clips. Magazines refill without a reserve-ammo economy. Melee has limited reach, with a longer spear reach. The rock remains a melee placeholder. Reloads currently use timing and HUD feedback, not a finished hand animation; grip/IK, throwing, muzzle alignment and final balance remain work for later passes.

Checks: test_forest.gd covers ground alignment and lane exclusion; test_practice.gd covers frontal/flank shield behaviour, heavy weakpoint, empty magazine and reload. Existing test_kit.gd covers wall obstruction, weapon/vehicle imports, driving/exit and relay/strike interactions. Captures inspect close/mid/far foliage, the suspension connections and practice silhouettes. These are functional checks; combat feel and performance still need playtesting.
