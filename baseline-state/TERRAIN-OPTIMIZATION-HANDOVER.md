# Continuous terrain sculpting — 2026-10-08

Repository: `C:\Users\Bran the builder\Documents\Codex\2026-09-27\we-h\work\world-foundation`
Branch: `integration/world-foundation`. Current work remains uncommitted.

Use the existing **Terrain Demo** desktop shortcut. Its target/description were
updated and read back. F1 opens the same four tools; hold LMB to sculpt or draw a
ridge. Ctrl+S saves after the final queued update. Ctrl+Z undoes a whole stroke.
The repository AGENTS.md retains the user's request to update this same shortcut
for every newly targeted test.

## Cause and correction

The prior integration threw away the old editor's warm field/brush caches,
rebuilt every edited column in each affected 200 m tile, repeatedly evaluated
SDF gradients, and stopped accepting brush movement while rebuilding. It also
created a new brush for each dab. The user's performance complaint was valid.

Restored the earlier `sdf_field_cache.gd` path: cached base samples and 2D brush
kernels, compiled column offsets, cached sampled normals, and unchanged-section
reuse. New `terrain_drive_edit_cache.gd` keeps a bounded set of base meshes and
builders; vertical bounds use stable bands. Explicit packed-array duplication
protects cached base meshes from being mutated by appended edited geometry.

`terrain_drive_editor.gd` now retains a brush for the whole held stroke and
collects movement/time independently of worker progress. The old brush's path
interpolation is retained. `terrain_drive_destruction.gd` coalesces pending doses,
groups history by stroke, drains input before saving, and rebuilds with the cache.

`terrain_drive_recipe.gd` exactly merges repeated same-footprint additive brush
operations. It does not merge across tunnels, spheres or mountains. Identities
retain full numeric precision. Additive height brush Y values are irrelevant
and canonicalized. Existing save files remain compatible; loading consolidates
them in memory and the next explicit Save writes the compact representation with
a previous-save backup. No automatic overwrite of user saves or approximate
geometric simplification was performed.

## Evidence

- Matched moving-brush A/B, cached base: prior 282–1162 ms, optimized 31–87 ms.
  Warm updates were 31–85 ms. Warm and independent fresh replay mesh arrays match.
  Vertex deviation from the old analytical-normal implementation's surface was
  at most 0.031 mm; cached-gradient normals are used by the optimized path.
- Continuous three-second stationary + four-second moving/seam-crossing input:
  78 publications, median worker 41 ms, median publication 80 ms, p95 140 ms,
  worst 339 ms. No brush time was dropped. Expected height, continuous ridge
  collision, single-step stroke undo/redo and saved mesh replay passed.
- 600 identical stationary samples: one operation, feature-array JSON reduced
  from 98,291 bytes to 161 bytes. Compaction around a tunnel preserved the ordered
  field to less than 2e-12 in the test.
- Rendered four-second held mouse test used the real editor `_process` and input
  handlers, with a test-controlled ray target. It published 39 updates (median
  83 ms). Frame p95 was 20.4 ms; worst was 230 ms. Screenshot inspected.
- Existing four-tool/collision/undo/save/load/fresh-replay/far-ring checks and
  fused grenade seam/overlap/replay checks passed.

## Tests and artifacts

`game/benchmarks/profile_drive_brush.gd` uses the frozen
`drive_brush_reference.gd` for A/B comparison and compaction equivalence.
`check_drive_continuous_brush.gd` checks held input, interpolation, dose, history
and persistence. `check_drive_live_brush.gd` exercises rendered held input and
captures the editor. The tests use isolated save files under this chat's work
folder. Raw A/B, continuous, rendered and regression logs accompany this file.

## Limits

These are short local diagnostics, not a universal frame-rate guarantee. The
rendered run used plain terrain with satellite/backdrop disabled. First visits
to an uncached edit region are slower; whole-tile collider creation still happens
on the main thread and can hitch. Field-cache budget is 32 MiB; the separate base
mesh/builder cache is capped at 24 tiles, not included in that byte count.
Persisting compiled edited meshes and replacing smaller collider sections are
possible next improvements. Broad distant scenery still uses the original DEM.

Saved recipes remain authoritative; meshes and sampled fields are derived worker
outputs. This addresses the suggested out-of-band compilation without adding a
second terrain-rendering pass or approximating the user's sculpted result.
Unrelated existing workshop/import/UID changes were retained.

Final repeat after full-precision compaction-key hardening also passed: 74 publications, median worker 44 ms, median publication 88 ms, p95 139 ms, worst 344 ms. Expected height and saved mesh replay remained identical. See brush-continuous-final.log.

