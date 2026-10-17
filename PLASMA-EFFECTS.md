# Plasma projectiles and firing performance — 10 October 2026

Restart **Rebuild Demo**. E leaves the Warthog; 1 Carbine, 2 Railgun, 3 Plasma Rifle, 4 Doom Plasma Gun, 5 Halo CE Plasma Rifle. Q cycles; LMB fires; R reloads. Tab retains FPS. F8 records diagnostics.

## Behavior

The three plasma weapons fire 85 m/s projectiles with a 200 m maximum range. A swept ray over each physics step prevents skipping thin surfaces. Damage is applied once at the actual collision, not when the trigger is pressed. The camera aim ray only establishes initial direction. Moving targets can enter or leave the path. In-flight damage remains tied to its shot when switching weapons. The first sweep includes camera-to-muzzle space to prevent firing through nearby walls. Carbine and Railgun retain hitscan behavior.

The pool holds 32 live bolts; a full pool rejects a new shot without consuming ammunition. Four textured sprites per bolt and three per impact share one bounded world MultiMesh. The muzzle uses an additive canvas sprite. Recoil/reload move the cached viewmodel image instead of redrawing the skinned arms each frame. This is a screen-space recoil presentation, with no new dynamic lights or shadows.

The original Terminator MP3 is preserved. `terminator-single.wav` contains the first 0.265 seconds, with a 35 ms fade-out and 2 ms fade-in, excluding the next pulse. All three plasma guns use this trimmed blast.

## Assets

- Existing Plasma Rifle: original GLB, with the requested 180-degree correction retained.
- Doom Plasma Gun: converted from Downloads/doom plasma/doomplasmagun.blend to assets/doom-plasma.glb. Cameras/lights omitted; no animations exported.
- Halo CE Plasma Rifle: converted from Downloads/Halo - Combat Evolved - Weapons - Plasma Rifle/Plasma Rifle/FPplasmarifle.obj to assets/halo-ce-plasma.glb. Source texture references repaired to the supplied local PNGs and embedded; multipurpose masks are not treated as bump maps.
- Cyan-white world and muzzle effects retain the supplied plasma contrail texture.

## Investigation and validation

The user's F8 recording `jitter-2026-10-10T21-14-47-3025905003.jsonl` contains 1,012 frame samples, median 11.66 ms, p95 89.06 ms, maximum 501.97 ms. Terrain streaming/edit workers and publication stayed idle. Frames below 340 draws averaged 13.87 ms; frames above averaged 61.99 ms. These groups also contain different camera views, so this is correlation, not proof that weapon rendering caused the entire slowdown. The old capture has no weapon timing counters.

The projectile implementation initially scanned all active trees for each swept segment. It now reuses tree placement cells with a conservative ring-coordinate search and returns live items so ground updates and retirement are respected. Construction query geometry is cached by store revision, with a segment/sphere rejection before testing individual piece planes. Edits invalidate the cache. Projectile trails are clamped to start at the muzzle. F8 now includes selected weapon, held trigger, shot count, model redraw count, cumulative ray-query time/count, and live bolts.

`check_projectile_tree_index.gd`: PASS. 120 identical trunk hits across 2,400 trees, including the ring seam. Final full scan averaged 4,158.5 microseconds/query; indexed queries 43.9 microseconds/query. This is a CPU microbenchmark, not a whole-game FPS multiplier.

`check_rebuild_weapons.gd`: PASS. Ring-oriented damage, obstruction, ammo/cooldowns, mode gates, reload/selection, delayed plasma damage and in-flight switching.

`check_plasma_billboards.gd`: PASS. Five actual imported models, trimmed sound, delayed damage, thin-wall sweep, moving-target miss/intercept, no duplicate damage, pool rejection, range expiry, idle cleanup, zero extra model redraws during firing, and rendered loading-screen verification.

The isolated renderer measured 2.42 ms idle and 3.80 ms firing before the cache changes. The first saved-world fixed-view run measured 10.26 ms idle and 11.42 ms firing, and did not reproduce the user's worst hitch. All world tests use isolated terrain/tree/construction copies. No player save was edited. See plasma-world-after.log for the final sustained-fire run; these short stationary cases do not establish a 120 FPS route average or prove every hitch is eliminated.

Final saved-world sample (Intel UHD, 1366 x 749, uncapped, 3-second warmup and 180 measured frames per case): idle 10.79 ms (93 FPS), firing into scenery 12.74 ms (78 FPS), sustained sky fire with 18 live bolts 8.97 ms (111 FPS). No model redraws occurred during any measured case. Sky-fire query cost averaged 150 microseconds; the earlier uncached construction run averaged 528 microseconds and 14.83 ms per frame. The final trail-origin clamp was subsequently verified by the focused projectile test. Camera views differ between scenery and sky; these are not interchangeable FPS comparisons. The 120 FPS target remains unproven and was not reached in these scene samples.
