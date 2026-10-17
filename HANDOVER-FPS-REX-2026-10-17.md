# Sky Demo handover — 2026-10-17 — investigate idle FPS before further tuning

## Latest explicit user instructions — isolation and efficiency
Before making implementation changes, create a NEW Git branch from the current sky-demo checkout, a NEW scene starting with the current Sky Demo exactly as it is, and a NEW desktop shortcut for that scene. Choose clear names for the performance work. The starting build must include the rocket launcher and crate-physics fixes added after commit 309182c; use the latest sky-demo checkout. Preserve the existing Sky Demo scene/shortcut and all other demo shortcuts; do not retarget them. Read back the new shortcut target, arguments and working directory after creating it. Give the new scene independent copies of all four current Sky Demo save files and point its launcher flags to those copies. Never use those player-facing copies for destructive tests; create separate test copies.

The main objective is to make the CURRENT BUILD MORE EFFICIENT: recover FPS and reduce CPU/GPU frame time while preserving its established appearance and gameplay as far as practical. Start by measuring the idle regression, then movement/preparation and combat. Identify the actual costs and implement and validate improvements; do not stop at a profiling report or assume trees/terrain are responsible. Record comparable before/after results, including frame-time spikes. Keep the pending explosion transparency and Rex collision/animation requests in scope, and assess their performance impact. These instructions supersede earlier directions in this handover to continue using Sky Demo for new work.

## User priority and pending requests
The user reports substantial FPS losses over the last 2–3 builds, including while idle. They suspect overly detailed trees or terrain preparation, but explicitly say they do not know. Do not treat either as a confirmed cause. Establish a repeatable stationary baseline after loading settles, then isolate systems. They asked whether a fresh session would be better; this handover supports that transition. No new chat was created.

Also requested, NOT YET IMPLEMENTED:
- Make the orange explosion somewhat transparent.
- Fix Rex damage collision: shots currently only hurt near his feet.
- Improve Rex animation smoothness compared with the old tactical scene. User agrees a cap may be useful, but Rex is huge and distant animation stepping is obvious. Use apparent screen size rather than raw distance if retaining caps; profile cost before shipping.

## Workspace and state
Repository: C:\Users\Bran the builder\Documents\Codex\2026-10-08\tree-demo
Godot project: game/project.godot
Branch: sky-demo
Scene: res://world/sky_demo.tscn
Launcher: existing Desktop Sky Demo.lnk. Preserve other shortcuts.
Executable: C:\Godot\Godot_v4.5.1-stable_win64_console.exe
Read AGENTS.md, SKY-DEMO.md and TREE-DEMO-HANDOVER.md. game/mocks/dem is a shared read-only junction.

Earlier checkpoint: 309182c, Build sky demo and optimize terrain grenade craters (450 files, accumulated project work). An initial push was rejected by automatic approval review. After being informed of the exact repository, branch and payload, the user explicitly renewed the request to commit and push all latest changes on 2026-10-17. This handover is included in that new commit. Destination: https://github.com/shovelhead24/possession.git, branch sky-demo. Inspect git log and upstream status for the final commit and push state; do not assume 309182c is still HEAD.

The subsequent checkpoint includes the completed rocket launcher and crate freeze fix below, plus an unfinished diagnostic script. Preserve generated Godot cache dirt and other existing files; do not reset the checkout. No Godot process was running when handing over.

## Completed rocket / crate work, user accepted
Supplied model copied from Downloads/rocket_launcher into assets/rocket_launcher, with textures and original CC-BY-4.0 license (irons3th).
Weapon 6; Q/Triangle cycle; LMB/R2 fire; R/Square reload. Two rockets, 0.65 s firing interval, 1.5 s reload, unlimited reserve. 55 m/s swept projectiles, 350 m range, 10 m blast radius, 3 m crater request. Near-muzzle sweep prevents shooting through walls. Generated launch/blast audio.
Files: game/world/explosive_rocket.gd, rebuild_weapons.gd, weapon_aim.gd; brief JSONs; SKY-DEMO.md.

Confirmed crate freeze cause: aliens/manager.gd resident() returned false for every terrain edit. heavy_crate.gd then froze the body and ignored blasts while suspended. Changed resident() to streamed collision availability only. Old collision remains until the atomic terrain replacement physics tick. Missing terrain still suspends actors. No change to actual crater pipeline in that fix.

Passed checks:
- check_rocket_blasts.gd: three real chained rocket impacts/craters; three crate impulses; crate moving during every edit frame, no freeze; blast damage, wall shielding, missing-terrain suspension/resume and camera-to-muzzle collision.
- check_crater_preparation.gd: 120 full throw trajectories at 0/45/80 m/s; updated residency expectation during edits.
- check_rocket_scene.gd: full scene weapon selection, two impact craters, empty magazine guard, reload, controller cycling; isolated saves; no script/runtime errors. Briefing and model screenshot inspected.
Report: C:\Users\Bran the builder\Documents\Codex\2026-10-16\yo\outputs\ROCKET-LAUNCHER-2026-10-17.md
Screenshots in same outputs: rocket-first-person.png and rocket-ready-briefing.png.
Full scene log: same chat work/rocket-scene.log. First screenshot immediately after loading shows poor FPS, but that is NOT a settled idle benchmark.

## Confirmed Rex findings (fixes NOT applied)
Current script: game/world/aliens/trex.gd. Older comparison: prototypes/first-operation/trex.gd and tactical.tscn.
Current enlarged model uses SCALE_HEIGHT=24 and SIZE_MULTIPLIER=3.6061933. Its movement/damage shapes remain tiny fixed volumes at local heights 2.4–3.5 m, max capsule height 5.2 m. The actual animated torso/head are much higher. Do not merely enlarge a solid movement capsule: earlier comments explain that this traps actors beneath an invisible belly. Prefer separate animated damage regions, without changing the movement collision footprint.
Current weapons trace_segment uses mask 7 and default body-only queries; aim assistance scans direct child CollisionShape3Ds. Any separate Area3D damage regions require ray and aim candidate support, preserving ancestor-based take_hit resolution. Rockets currently apply splash around target feet; a direct head hit needs correct direct-hit damage without duplicate splash damage. Shielding and physics queries should not accidentally treat damage-only regions as solid scenery.

Current _process advances AnimationPlayer manually at distance caps 60 Hz below 35 m, 30 Hz below 110 m, 15 Hz farther out. It resets accumulated time to zero on each update. The old tactical version advances animation on physics ticks, without this distance throttle. Grounding is a SkeletonModifier3D (trex_grounding.gd); any skeletal hit regions should track the corrected pose.

New diagnostic only: game/benchmarks/check_rex_hit_regions.gd extends check_rebuild_rex_impacts.gd; instantiates real Rex in a small fixture, prints skeleton coordinates, then quits. It is NOT yet a regression test. Log: chat work/rex-hit-regions.log. Raw pose samples relative to Rex: hips roughly (-2,21,2), spine (-3,18,-7), head (-2,16,-20), eyes around y17/z-24, tail extends to z40. Poses change over time. Fixture exited with an ObjectDB leak warning (inherited standalone helper nodes need cleanup); no persistent process remains. No hit-region implementation or animation change has been made.
Explosion material still opaque in explosive_rocket.gd, terrain_grenade.gd and aliens/frag.gd.

## FPS investigation leads — unproven
- Tree foliage budgets exist in tree_foliage_budget.gd, with high/medium limits and density-aware selection. rebuild_demo.gd explicitly sets foliage_budget.enabled=false for both tree patches. Investigate why and compare enabled/disabled without changing visibility/collision. Existing profile_foliage.gd and profile_foliage_slice.gd provide isolation patterns, but contain OLD hardcoded output paths/save assumptions: adapt before use.
- terrain_drive_destruction.gd warms caches on a worker. Startup reserves nearby entries, awaits full grenade coverage, then prepares loaded nearby tiles as the player moves. Normally stationary prepared terrain should launch no new warm jobs. Measure worker/warming/warmed_tiles/preparation_keys, not just destruction.busy(), which combines preparation and editing.
- tree_edited_terrain_lods.gd can independently load base/cached distant edit meshes in another worker. It has a 0.25 s scan and a >220 m fallback; full edits return <180 m. Include it in background-work inspection.
- terrain_drive_cuts.gd refines affected 8 m cells to a 2 m lattice. Edited mesh render_lods are cleared to avoid filling small craters at distance. Determine whether cost is worker preparation, publication, ongoing rendering, or unrelated to terrain.
- Current world has multiple authored Rex actors, trees, sky billboards + high painterly layer, AI/navigation, collision debugging and diagnostics. Keep camera, layout and activity identical for comparisons. Measure idle first, then a no-explosion movement route with preparation enabled/disabled. Isolate tree visuals, tree shadows, LOD choice, AI/Rex, sky and worker activity as evidence dictates. Avoid speculative changes based on the user's hypotheses alone.

Prior crater timing report: outputs/CRATER-PERFORMANCE-2026-10-17.md in this chat. Full-scene request-to-publication 0.20–0.27 s; that was NOT an overall FPS fix (frame p95 38–46 ms, peaks 69–72 ms in those throw windows).

## Safe full-scene testing
All four save overrides are REQUIRED. Existing isolated copies:
C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/work/sky-test/
--drive-edits-file=<directory>/terrain-drive-edits.json
--tree-paint-file=<directory>/painted-trees.json
--forge-file=<directory>/construction.json
--actors-file=<directory>/actors.json
Never run destructive tests on the user's live Sky Demo or Rebuild saves. Read actual flags in current launcher if needed; preserve it. Existing harness check_rocket_scene.gd shows a valid full launch setup. Godot execution requires sandbox escalation in this environment. Do not run a second GPU-heavy scene alongside the user's game; ask them to close it if necessary.

User prefers concise communication and action, dislikes speculative fixes and unnecessary token use. Do not spawn agents unless explicitly authorized. Update player-facing briefing for shipped changes and inspect its visible result as required by AGENTS.md. Save new reports in the new chat's outputs directory.
