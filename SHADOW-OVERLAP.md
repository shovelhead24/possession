> SUPERSEDED 2026-10-12: User rejected the forest-edge shadow loss. Aggressive overlap suppression and the subsequent CPU-cache changes were reverted. Historical measurements below do not describe the current build. Read HANDOVER-REBUILD-2026-10-12.md.

# Aggressive obstructed-tree shadows - 2026-10-11

Enabled by default in Rebuild Demo. F1 > Forest density & performance > Hide obstructed tree shadow proxies toggles it for comparison. Loading briefing updated and visually verified.

Any positive overlap between projected canopy bounds removes the farther tree's shadow proxy. There is no minimum density or overlap percentage. Tree meshes, collision and placements are untouched. This deliberately accepts canopy gaps and bounding-box overestimation as obstruction. Nearby bounding boxes are ordered by their centre depth. Off-view trees retain shadow support. Trees whose shadows are removed still obstruct other trees.

Shadow batches are grouped by 96 x 96 metre terrain cell and species. Each instance uses a 48-triangle, shadow-only model formed from three closed cones. Removal is per tree within the batch, not per whole cell. The separate authored density field uses 24 m cells; it is not the shadow batching grid and does not gate this aggressive rule.

The quarter-second shadow refresh schedules the camera-dependent check. Immutable tree snapshots are cached while the camera turns; snapshots rebuild after relevant tree revisions or movement. Projection, overlap testing and grouping run on a worker. The main thread publishes changed batches and transforms. Stale results after edits are rejected. Disabling the rule restores shadows. In detailed lighting mode, enabling the rule uses filtered tree proxies; disabling it restores original detailed tree shadow casting. Legacy Tree Demo defaults remain unchanged.

## Validation

- Tiny positive overlap, non-overlap restoration, obstruction chains, turns, behind-camera rejection and unchanged tree transforms passed.
- Worker publication, stale-edit rejection, toggle, shutdown and detailed-mode restoration passed.
- Existing shadow proxy idle cache, terrain re-grounding, visibility and erase regression passed.
- Rendered full-world A/B and turning comparisons passed with isolated terrain/tree/construction saves. Tree save identity unchanged. Editor and loading screen visually checked.
- F8 records the enabled rule, removed caster count, last overlap worker cost and main-thread publication time.

## Measurements

Intel UHD / Godot Compatibility, 1366 x 749, uncapped. Aliens disabled for foliage isolation. Stationary samples: 360 frames after two-second warmup. Results are short samples with appreciable variation, not full-game acceptance.

| View | All shadows mean ms | Obstructed shadows removed mean ms | Casters removed |
|---|---:|---:|---:|
| Forest edge | 11.83 | 12.04 | 252 |
| Forest edge repeat | 12.30 | 12.99 | 252 |
| Close canopy | 15.35 | 15.00 | 475 |

Turning sample: mean 16.71 -> 14.19 ms, p95 23.99 -> 20.04 ms. With the rule enabled, maximum observed snapshot work was 0.492 ms and publication 2.186 ms. Maximum sampled worker overlap time was 25.07 ms, off the main thread. These maxima are sampled telemetry, not a formal worst-case bound. Disabled-rule worker/publication values in the raw JSON can retain the preceding enabled sample and are not applicable to its timing.

The rule demonstrably removes 252 shadow casters at the edge and 475 in the close view, but does not show a consistent stationary FPS improvement. It remains enabled as requested for visual/performance evaluation. The 120 FPS target is still unmet. No claim is made that canopy bounds are exact occlusion.
