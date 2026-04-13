---
phase: 02-height-brush
plan: "01"
subsystem: terrain
tags: [terrain, height-brush, data-layer, offsets]
dependency_graph:
  requires: []
  provides: [height_offsets-storage, apply_height_brush-api]
  affects: [terrain_chunk.gd, terrain_manager.gd]
tech_stack:
  added: []
  patterns: [PackedFloat32Array per-vertex storage, bilinear interpolation, dirty-set return pattern]
key_files:
  created: []
  modified:
    - game/terrain_chunk.gd
    - game/terrain_manager.gd
decisions:
  - "Offsets stored as PackedFloat32Array on each chunk, sized to (resolution+1)^2"
  - "Bilinear interpolation used for sampling between grid vertices and for LOD resampling"
  - "_ensure_offsets_sized() called in both initialize() and generate_terrain() to guard against empty array"
  - "apply_height_brush returns dirty Array[Vector2i] — no mesh rebuild, caller owns that"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-13"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 2 Plan 1: Height Brush Data Layer Summary

**One-liner:** Per-vertex `PackedFloat32Array` offset storage on TerrainChunk with bilinear sampling, plus `apply_height_brush(world_pos, radius, strength, falloff)` dirty-set API on TerrainManager.

## What Was Built

### Task 1 — TerrainChunk height_offsets storage (commit `3938d8d`)

Added to `game/terrain_chunk.gd`:

- `var height_offsets: PackedFloat32Array` — per-vertex offset array, default empty
- `_ensure_offsets_sized()` — resizes to `(resolution+1)^2` with 0.0 fill; called in `initialize()` and at top of `generate_terrain()`
- `_sample_offset(local_x, local_z)` — bilinear interpolation over the offset grid using local chunk coordinates `[-chunk_size/2, +chunk_size/2]`
- `_resample_offsets(old_resolution)` — resamples offsets bilinearly from old to new resolution when `set_lod()` changes vertex count
- `get_height_at_world_pos()` modified to add `_sample_offset(local_x, local_z)` after fetching the procedural base height

All offsets default to 0.0 so terrain renders identically to pre-phase behaviour.

### Task 2 — TerrainManager apply_height_brush API (commit `4bc9627`)

Added to `game/terrain_manager.gd`:

- `enum BrushFalloff { GAUSSIAN = 0, LINEAR = 1, HARD = 2 }`
- `apply_height_brush(world_pos, radius, strength, falloff)` — iterates chunks overlapping the brush circle, applies `strength * weight` to each vertex within radius, returns `Array[Vector2i]` of dirty chunk coords. No mesh rebuild triggered here.

Falloff shapes:
- **GAUSSIAN** — `exp(-dist²/(2σ²))` with σ = radius*0.5
- **LINEAR** — `1 - (dist/radius)`
- **HARD** — uniform weight 1.0

## Decisions Made

- `_ensure_offsets_sized()` checks `size() != expected` rather than `is_empty()` so it also corrects an array that somehow has wrong size after a hypothetical corrupt state
- `set_lod()` captures `old_res` before updating `resolution`, then calls `_resample_offsets(old_res)` — this preserves all brush edits across LOD transitions
- `apply_height_brush` calls `chunk._ensure_offsets_sized()` defensively before iterating, in case a chunk was loaded before this phase was active

## Deviations from Plan

None — plan executed exactly as written.

The plan mentioned verifying chunk position convention (`position.x = coord.x * chunk_size` vs `+ chunk_size/2`). Reading the actual `initialize()` code confirmed position is `coords.x * chunk_size` (not `+ chunk_size/2`), making it the center-minus-half point of the chunk. The `_sample_offset` and `apply_height_brush` code both use `local_x = world_x - position.x` which is correct for this convention.

## Known Stubs

None. This plan is pure data layer — no UI, no rendering, no stub values.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary changes. Purely in-process terrain data mutation.

## Self-Check: PASSED

- `game/terrain_chunk.gd` — exists and contains all required symbols
- `game/terrain_manager.gd` — exists and contains `apply_height_brush` + `BrushFalloff`
- Commit `3938d8d` — verified in git log
- Commit `4bc9627` — verified in git log
