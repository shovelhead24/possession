# Performance Demo handover — 2026-10-27 — living environments and world-lit weapons

## Session boundary / latest user direction

The user asked to stop here and write a session handoff resembling previous handovers. No further feature work is requested at this boundary. This document records the current working tree, not a committed or pushed release.

Latest accepted direction: the planet is now very large; the user realised they may not have reloaded earlier revisions, but explicitly likes its current size. KEEP IT. They also like the dark interval between sunlight and planet light and see potential gameplay value in it. Do not automatically brighten away that interval. The final implementation replaced the weapons' permanent studio lighting with world-responsive lighting; the user has not yet reported their in-game verdict on that last change.

## Workspace, branch and launcher — verified at handoff

- Repository: `C:/Users/Bran the builder/Documents/Codex/2026-10-08/tree-demo`
- Godot project: `game/project.godot`
- Branch: `performance-demo`
- HEAD: `2f33164a6ed25230d721dd79a3b043a665393ed5`
- Current scene: `res://world/performance_demo.tscn`
- Desktop launcher: `C:/Users/Bran the builder/Desktop/Performance Demo.lnk`
- Launcher target: `C:/Godot/Godot_v4.5.1-stable_win64.exe`
- Launcher working directory: repository `game` folder.
- Console executable for tests: `C:/Godot/Godot_v4.5.1-stable_win64_console.exe`
- Task artifacts: `C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/{outputs,work}`

Git status returned 216 changed/untracked entries BEFORE this handoff was written. Much of the work since the old HEAD is in the dirty working tree, including untracked scripts/assets. Do not reset, clean or discard it. No commit or push was made for the latest work. No claim is made that current files are backed up remotely. The old 17 October handover describes an earlier pushed checkpoint, NOT the current build.

Read `AGENTS.md`, `PERFORMANCE-DEMO.md`, `WILDERNESS-SHOWCASES.md`, `FLOATING-ORIGIN.md`, and the applicable older editor documentation. Those documents are chronological: later tuning entries supersede earlier numbers. This handoff summarises final current values.

## Preserve saves and other builds

Launcher arguments select these LIVE player files under:
`C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/work/performance-player/`

- `--drive-edits-file=.../terrain-drive-edits.json`
- `--tree-paint-file=.../painted-trees.json`
- `--forge-file=.../construction.json`
- `--actors-file=.../actors.json`

Never use those files for destructive tests. Existing test overrides are under `rea/work/sky-test/local-grass/` with the same four filenames. Always pass ALL FOUR flags for a full-scene test. Preserve associated grass/start/tuning data too. Do not overwrite the user's spawn or authored layouts for convenience.

Keep Sky, Rebuild, Tree and Terrain shortcuts unchanged. `game/mocks/dem` is a shared read-only junction, not disposable local content. Do not recursively search or modify it casually. Preserve baseline-state and original imported assets.

## Art and engineering intent

The target is an early-2000s / Halo-one-like wilderness: economical geometry, readable materials and deliberate composition. Low polygon count is appropriate, but the user rejected visibly crude replacement trees; the established firs are preferred. The Warthog captures the brief well.

Vistas are destinations in themselves, not just connective scenery. Geographic identity should be legible looking east versus west through vegetation, colour, wet/dry patches and roughness, not only silhouette. Avoid borrowing satellite imagery's farms/roads as promises of nonexistent gameplay. Slope-driven exposed rock, summit snow, marshes, river valleys and long yellow-brown grass are reference themes.

Long-term intent: canonical Halo-scale ring, expensive travel, mission-informed preparation of cached terrain; straightforward mission-respecting playthrough should remain under 100 GB final disk usage (upper ceiling, not a target to fill). Height fields and SDF-derived cached meshes are part of that direction. Do not assume canonical scale has been implemented: current RingFrame circumference is still 3,000,000 m, width 50,000 m. Terrain streaming/generation redesign is not part of the completed visual studies.

## Current environment defaults

Defaults start AFTER entering play, not while the loading briefing is open. Controls are under Ctrl+F4.

- Day/night enabled and animated: starts at hour 12, rate 0.02 game hours/second = 20-minute day.
- Weather automatically changes every 180 seconds, blending over 45 seconds.
- Sequence: Scattered → Overcast → Drizzle → Passing showers → Clear → Scattered → Mist → Scattered → Steady rain → Wind-driven rain → Overcast → Clear, repeating.
- Passing showers retain their internal pulses. Thick fog remains available manually.
- Weather selection or manual rain/wind/visibility edits pause automatic weather. The cycle checkbox restarts at Scattered.
- Scrubbing daylight holds that hour; Animate day resumes.
- Clouds: mode 2 (wind drift + evolving shapes), speed 1, animated.
- Vegetation wind: Gusts, tree bend 3.0. Existing spatially varied wind and billboard motion remain.
- These are session settings; restarting restores defaults. They do not persist edits into player saves.

Key orchestration: `game/world/performance_cloud_review.gd`, `performance_day_cycle.gd`, `performance_weather.gd`, `performance_showcases.gd`.

## Ring daylight and sky

Restored original tilted sun orbit from RingFrame.sun_direction, with shared sun/star rotation. Local lighting derives from camera ring-up, including floating-origin rebasing. Far terrain, walls, cloud cards and the high painterly cloud cylinder use their OWN regional daylight, not the player's local sun energy. Opposite hemisphere therefore darkens during local day and brightens during local night.

Both painterly sky backgrounds now include the original spherical starfield, with daytime visibility 0.4. The user explicitly wants daytime stars. Do not remove them for realism.

Far-ring haze now eases from a cap of 0.82 near the horizon to 0.55 beyond 120 km; transition spans 20–120 km. This is the manual far-ring shader haze, not a global removal of rain/fog.

Files: `performance_stars.gdshaderinc`, `performance_ring_light.gdshaderinc`, `performance_cycle_sky.gdshader`, `sky_painterly_background.gdshader`, `performance_cloud_cards.gdshader`, `performance_cloud_upper.gdshader`. Review code patches the current backdrop shaders without replacing the historical originals. Several setup stages patch shader source; preserve their ordering and exact replacement targets.

## Planet and moonlight — FINAL values

- Source: user-supplied blue planet copied unchanged into `game/world/materials/sky_blue_planet.png`.
- Sky sampling: `performance_planet.gdshaderinc`, cropped/masked in shader from the original image, mipmaps generated at load.
- Apparent diameter: **20 degrees** (radius 0.174532925 radians). Earlier 2-degree and 10-degree entries are obsolete. User likes the present large size.
- Fixed photographed phase, not a dynamic physically correct phase model.
- Planet direction rotates with the celestial frame. Sky/cloud geometry occludes it normally.
- Directional moonlight cap: 0.14, cool colour (.52,.66,1), shadows disabled.
- Nearby camera-following fill: OmniLight, radius 28 m, camera position + local up * 3 m, attenuation 1.2, energy = directional moon energy * 1.9, specular 0, shadows disabled.
- Both fade with local day, planet below horizon and cloud cover. This is an art-directed navigation aid, not simulated atmospheric scattering.
- Far terrain/walls have regional moon diffuse lighting before haze; cloud/weather attenuation remains.
- Water has a separate moon glint after the normal night tint. Current lobe: exponent 32 plus 0.22 * exponent 10 skirt; gain 0.9 multiplied by highlight_strength and moon colour.
- Both the local pool material AND shared `game/assets/showcases/water.res` receive live sun, moon and tint updates. The latter used to miss those live connections.

The last parameter-only adjustment (20-degree planet / stronger fill / wider shimmer) did not repeat a full landscape benchmark. Subsequent user feedback accepts the large planet. No new FPS claim was made.

## Most recent change: guns and hands respond to world light

Root cause was not simply unlit mesh flags: `rebuild_weapons.gd` renders first-person arms/guns in an isolated SubViewport with its own World3D, fixed white ambient energy .7 and a permanent studio directional light. The image is cached to avoid expensive repeated skinning/rendering.

New `game/world/weapon_world_lighting.gd` mirrors world sun, moon and ambient light into that viewport. Directional bases are transformed into camera space, so turning changes the lit faces. Nearby moon fill contributes a small ambient lift. The shared viewport applies this to arms and weapon models.

The active viewmodel checks lighting at 10 Hz. Quantized unchanged lighting retains the cache; changes request a redraw. Existing explicit redraws force a current light sample. Do not casually switch the viewport to UPDATE_ALWAYS in production: the cache is an important prior performance fix.

Verified actual Halo CE plasma rifle in daylight, turned view, moonlight and dark interval. Source gun glow/material channels were not rewritten. Outdoor directional/ambient response is implemented; **world occlusion/shadows and arbitrary nearby point lights are NOT mirrored**. This limitation was disclosed. User has not yet reviewed this last change in game.

## Existing landscapes and tooling retained

Four saved reference-inspired showcase scenes live in `game/assets/showcases`: autumn forest/lakes, alpine braided river, rocky pass, highland lake. Access via Ctrl+F4 Viewpoints. They are separate authored patches, not replacements for the original play area. Saved meshes/material masks are loaded from disk; no new runtime SDF generation scheduler was introduced.

Established fir meshes/billboards, height variation, spatial wind, grass cards/blades and ground materials are retained. Ground masks provide wet/dry/green/exposed variation and grass density. Snow is confined near summits. Grass painting is available alongside tree painting in F1, including undo/redo/save/load and density-dependent height variation. Halo CE Plasma Rifle (weapon index 4) remains default; projectile origin rebasing was repaired earlier. Floating-origin support and ring-relative HUD/log coordinates remain.

These remain art studies, not finished missions. Water has no swimming/buoyancy gameplay. Full ground dressing, material/grass polish and performance work remain. Do not interpret old screenshot FPS or load-time 2–3 FPS captures as settled gameplay measurements.

## Validation and evidence

Latest narrow weapon test:
- `game/benchmarks/check_weapon_world_lighting.gd`
- Log: `rea/work/weapon-light.log`, WEAPON_LIGHT_PASS.
- Actual-model rendered screenshots: `rea/outputs/weapon-light-{day,turned,moon,gap}.png`.
- Tests daylight/light copying, direction change, moon/dark gap and unchanged-cache retention. This is not a full-scene benchmark or verification of every imported weapon material.

Environment tests:
- `game/benchmarks/check_weather_cycle.gd`: all weather transitions, mist separation and manual override/restart.
- `game/benchmarks/profile_performance_weather.gd --ring-day-review`: full scene, all four isolated save flags. Checks automatic defaults, ring daylight, rebase/reset, planet/moon light and captures nighttime showcase vista.
- Passing logs: `rea/work/environment-defaults-final.log`, `ring-day-final.log`, `planet-final.log`, `moonlight-final.log`.
- Initial failed attempts in other logs include test-only assumptions about pulsing showers and float tolerance; use the FINAL passing logs.
- `moonlight-final.log` predates the final parameter-only brightness/size tuning and weapon lighting change. Do not claim it tested those final values.
- Screenshots: `moonlight-landscape.png`, `planet-night-scale.png`, `planet-night-detail.png`, `ring-day-{0,6,12,18}.png`. Planet screenshots may show the earlier 10-degree version; final value is in shader source.
- Briefings: `game/world/performance_demo_brief.json` and `performance_demo_pines_brief.json`. Updated for world-lit weapons. The latest weapon briefing JSON was updated but not separately rendered in the full game; earlier moonlight briefing was visually verified.

Full scene tests can take 90–240 seconds on this machine. Headless dummy rendering does NOT reliably preserve new MultiMesh transforms; use rendered tests/bakes for foliage geometry. Do not repeat all expensive tests for mere constant tuning without a concrete reason.

## Practical continuation notes

1. Start from this dirty working tree, not old HEAD. Read the user’s new request before choosing more work.
2. First likely follow-up: user art review of gun/hand brightness, especially during the dark gap. Preserve that gap's gameplay potential.
3. If indoor lighting or local flashes are requested, extend the weapon bridge deliberately; it currently samples only sun/moon/ambient and nearby moon fill.
4. Keep performance budgets in mind: cached viewmodel, no moon shadow maps, batched foliage, vertex-shader wind and offline landscape data.
5. Before claiming an FPS improvement, take settled comparable captures with matching camera, weather/hour and input; record frame times. Moving weather/daylight now run by default, so freeze them for fair comparisons.
6. Use `rg` scoped to world/benchmarks, avoid shared DEM traversal. Use UTF-8 explicitly in Python writes on Windows.
7. Godot console runs have needed approved elevated execution in this environment; sandbox startup may fail. Tests must remain isolated from player saves.
8. No shortcut, branch, commit or push was changed for this handoff. No new chat was created.

## Suggested next-session opener

Read this handover and the repository instructions. Continue from the current performance-demo working tree. Keep the accepted large planet, automatic environment defaults and dark sun-to-planet interval. The latest change is cached first-person weapons following world sun/moon/ambient light; wait for my feedback or new task before expanding scope.
