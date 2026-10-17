> SUPERSEDED 2026-10-12: User rejected the forest-edge shadow loss. Aggressive overlap suppression and the subsequent CPU-cache changes were reverted. Historical measurements below do not describe the current build. Read HANDOVER-REBUILD-2026-10-12.md.

# Cached shadows and alien cover — validated 2026-10-12

Implemented in Rebuild Demo, available through the existing Rebuild Demo shortcut.

## Changes

- Visual tree LOD changes no longer invalidate shadow geometry. Actual transforms, membership, visibility changes and terrain re-grounding still invalidate it.
- Shadow membership is cached by 96 m cell and species. Camera obstruction checks rebuild only groups whose suppression mask changes. The aggressive any-overlap shadow rule remains enabled.
- Terrain and tree caster settings are registered when geometry appears and reapplied when settings change, replacing repeated scans and unchanged property writes.
- Alien cover caches construction offsets and terrain-grounded positions. Local terrain body replacement, construction movement and streaming invalidate the affected cache. Missing ground is retried. Clearance and threat checks remain live.
- F8 records cache counters. The loading briefing was updated and visually verified.

These are runtime caches. The separately authored canopy-density sidecar remains the editor-baked data. Camera-dependent obstruction still runs in real time; no navigation bake was added.

## Controlled CPU comparison

Same loaded tree snapshot, 160 paired views (80 stationary, 80 turning), alternating execution order. Both paths perform the same obstruction classification. The comparison asserts identical final shadow groups for every view.

| Measurement | Full group rebuild | Cached changed groups |
|---|---:|---:|
| Mean classify + group CPU time | 7.946 ms | 6.901 ms |
| Group arrays built across 160 views | 9409 | 585 |

2066 trees in the snapshot. This comparison isolates CPU grouping and does not establish an end-to-end FPS gain.

## Rendered world check

Intel UHD / Godot 4.5.1 Compatibility, 1366 × 749, uncapped and VSync disabled. Fixed-position camera turn for 480 frames. Aliens disabled to isolate foliage. Separate fixture saves contain 455 terrain edits, 3,668 trees and 26 construction parts.

- Mean 14.49 ms / **69.0 FPS**; p95 20.79 ms.
- Maximum observed shadow publication: 6.672 ms.
- Shadow snapshots rebuilt during camera turn: 0.
- Idle caster setting writes: 0.
- Cover terrain queries: 56 first refresh → 8 repeat; 12 cached construction entries, 52 live clearance queries retained.

An earlier isolated run in this task averaged 56.6 FPS (17.66 ms), p95 24.17 ms, with a 10.601 ms maximum publication. These samples are not a matched old/new whole-engine A/B. The 120 FPS target remains unmet; close foliage rendering and publication spikes still require attention.

## Validation

Passed script parse, CPU-cache correctness, shadow worker/stale-result handling, shadow proxies, 50,640-tree streaming/paint/undo/redo/collision regression, terrain-cache revisit regression, and the rendered world assertions. The paired group comparison produced identical results. Existing glTF material-conversion warnings remain; no script errors in the completed world run. Player saves were not used by tests. No commit was created.

Artifacts: cpu-cache-results.json, cpu-cache-world.log, cpu-cache-loading.png and cpu-cache-world.png in this outputs folder. Benchmark source: game/benchmarks/profile_cpu_cache.gd; focused regression: game/benchmarks/check_cpu_caches.gd.
