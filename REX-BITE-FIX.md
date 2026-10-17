# T. rex bite/freeze correction - 12 October 2026

Use the existing Rebuild Demo shortcut after restarting the game. The larger T. rex is retained. F8 now includes its attack and movement state.

## Findings

The user's recording is Tree Demo/terrain-drive-traces/jitter-2026-10-12T12-30-31-267218519.jsonl. Its 1,334 captured/preroll frames show an unchanged on-foot viewpoint, no streaming jobs, no edit worker/pending edits, and normal frame progression: mean 14.58 ms, p95 17.27 ms, maximum 22.86 ms. It did not include T. rex state, so it cannot establish the exact phase of the reported freeze.

The size difference was a restoration error: the original measured raw mesh bounds (15.77014 m source height); the port used posed-skin bounds (4.373072 m). With the same nominal height constant, this changed model scale from 1.521863 to 5.488133, or 3.606193 times the original. The model asset hashes match. The current larger size is now an explicit multiplier on the original bounds calculation; it is no longer an accidental dependence on posed bounds.

Live isolated bite timers and procedural poses completed normally. A reproduction using copies of the current 807-edit world, 3,966 authored trees and current construction, at the recorded camera viewpoint, exposed a separate 23.4-second frozen pose after a completed bite. The restoration had dropped the original creature-specific tree collision exceptions. Its movement controller stopped at trunks and froze its walking animation, making an extended hold-like pose visible.

## Changes

- Restored original T. rex-only tree-trunk exceptions. Existing trunks are registered once; newly streamed trunks are handled by the node-added signal. No periodic all-tree scan was added. Tree collisions remain active for the Warthog, player and aliens. Construction remains solid to the Rex.
- An ongoing bite/recovery finishes before distance or missing-terrain suspension, releasing the victim. Normal movement remains gated by terrain residency and range. Explicit gameplay/menu pauses still pause gameplay.
- Held squad members prevent their encounter from unloading until released.
- F8 now records Rex position/health, attack number/kind/timer, recovery, held target, mouth distance, animation time/speed, activity/suspension reason, movement blocker and CPU counters.
- Updated and visually verified the actual loading briefing. Existing Warthog punts, forest shadows and player saves are preserved.

## Validation

- Existing alien, impact/punt, hill-footing and four-attack regressions passed.
- New regression calls the actual gated physics entry point with terrain unavailable and the camera more than 300 m away: the held attack completes, controls return, then ordinary simulation suspends.
- In the current saved-world copy, a controlled test against the same trunk blocks the Rex with its exception removed and passes with the exception restored. The trunk keeps collision layer 2.
- The 60-second before run started three attacks and froze outside an attack for 23.4 seconds. The 60-second fixed run completed all four attacks, including the stomp/eat sequence, and recorded zero frozen non-attack intervals. These are behavioral runs with nondeterministic enemy movement, not an FPS comparison or proof that no other blocker can ever occur.
- Final gameplay runs had no script errors. Existing Warthog material-conversion warnings remain. No user game was stopped; diagnostic processes exited themselves.

Relevant scripts: world/aliens/trex.gd, world/aliens/manager.gd, world/tree_patch.gd, world/terrain_drive_trace.gd, and world/rebuild_demo_brief.json. Regression/reproduction scripts: benchmarks/check_rebuild_rex_impacts.gd and benchmarks/diagnose_rex_world_bite.gd.
