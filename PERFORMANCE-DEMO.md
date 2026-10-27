# Performance Demo — 2026-10-18

Work continues on branch `performance-demo`, based on `2f33164`, in the existing tree-demo checkout. Launch Desktop/Performance Demo.lnk and `game/world/performance_demo.tscn`. Keep Sky/Rebuild/Tree/Terrain shortcuts unchanged.

Player saves are separate copies under `C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/work/performance-player`. Tests must use all four `work/sky-test` overrides; never benchmark with player saves.

The evidence and ordered plan are in `C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/PERFORMANCE-PLAN-2026-10-18.md`. Do not present earlier tree-collision driving captures as a valid before/after comparison. The user specified an open-ground approach through the tree gap toward the boxes near spawn. `profile_performance_approach.gd` explicitly enters the Warthog, starts at (120,145), targets (-4,252), steers toward the target, brakes before the crates and rejects obstruction/timeouts.

Performance Demo now uses the articulated 2,796-triangle Tank derivative under game/assets/performance_tanks. Original source files remain unchanged. Turret, barrel and fourteen road wheels animate; smooth tread belts remain static. Other scenes retain Altay. The asset folder includes the reproducible splitter and exact triangle/attribute verification.

Performance briefing is `game/world/performance_demo_brief.json`; update and visually verify it for user-facing changes. Original dirty imports and prior handover changes predate this work; preserve them. No benchmark timing wrappers should remain in production scripts.

19 October implementation: cloud orientation caches invariant sizes/up axes and local array references; 61,440 transform comparisons pass, loop timings about 35% lower. Tree streaming skips redundant retirement scans only with invariant/paint invalidation tracking; production-versus-reference scenarios pass. Crater fixture validates depth, seams and stream reload; 100–121 ms total latency was chiefly worker/wait time, not a single-frame hitch. Full-scene approach results and remaining tree/shadow work are recorded in outputs/PERFORMANCE-HYBRID-2026-10-19.md in the rea task folder.


19 October pine test: Performance Demo now substitutes Pine_medium_3, Pine_small_2 and Pine_sapling_1 for the three existing saved species keys. All 3,966 placement records remain unchanged. The --original-trees user argument restores original render assets for comparison. See assets/performance_trees/README.md and rea/outputs/PERFORMANCE-PINES-2026-10-19.md. The paired approach measured 23.31 ms with pines versus 25.28 ms with original trees; earlier sessions were faster overall, so treat the timing gain as provisional. Mesh trunk alignment and normalized heights passed. Fuller billboard silhouettes remain an art review point.


20 October HUD audit: Performance Demo gates inherited diagnostic text at 10 Hz and skips hidden text work. Ammo text has immediate change-driven assignment/layout; camera, reticle, movement and frame sampling remain full rate. The pre-fix repeated hidden on-foot comparison measured 19.25 ms with text updates versus 15.00 ms without. Weapon-inactive results were inconclusive. Final-code visibility, ammo and vehicle-transition assertions pass. See rea/outputs/PERFORMANCE-HUD-2026-10-20.md. User logs average 25.5 FPS on foot and 31.8 driving while recording; complete native/vehicle physics remains the next profiling target.

20 October tree decision: regular fir trees are the default again, including the existing Performance Demo shortcut. Pine visuals require --pine-trees; --original-trees takes precedence if both flags are present. No placement records changed. HUD, tank and cloud improvements remain active.

20 October physics screening: regular-tree stationary tests and a fresh isolated current-save test near the boxes passed. Parked-vehicle freezing produced a modest, variable benefit; shadow rendering was a larger open-view cost than hiding cloud geometry. Temporary timing counters were removed. Crucial correction: engine process/physics monitors report preceding-interval maxima, not mean callback cost. F8 context now records viewport, window focus, VSync and physics object/pair counts. See rea/outputs/PERFORMANCE-PHYSICS-2026-10-20.md before drawing conclusions from the older 25–28 ms monitor readings.

20 October shadow pass: Performance Balanced uses a 1024 map with the same soft filter, two cascades and 121 m range. Other scenes and Detailed retain 2048. --high-resolution-shadows restores the former Performance resolution. Fixed-view repeated comparisons suggest roughly 1 ms saving, with substantial timing variation; see rea/outputs/PERFORMANCE-SHADOWS-2026-10-20.md. Static screenshots show softer shadow edges; motion shimmer remains a play-test consideration.

21 October cloud/daylight review: Ctrl+F3 > Cloud motion + sunrise / sunset review exposes opt-in drift/wrapping, evolution, 75% card coverage and a day-cycle preview. Use Billboards + high painterly layer. Existing sky remains default. Full-scene checks and 720p/768p UI fixture passed; no large FPS gain established. See rea/outputs/PERFORMANCE-CLOUD-REVIEW-2026-10-21.md for measurements and limitations.

21 October haze fix: fixed blue/orange time-of-day strobing caused by per-frame backdrop DAY_HORIZON overwrites fighting 10 Hz preview tint. Shared backdrop.horizon_color preserves the active preview across every frame and restores baseline on reset. Full-scene post-render regression: 921 incorrect material-frame samples before, zero after across held sunrise/sunset, animated sunset and reset (1,440 samples total). See rea/outputs/PERFORMANCE-HAZE-FIX-2026-10-21.md.
