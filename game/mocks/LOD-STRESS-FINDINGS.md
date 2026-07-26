# UHD Stress Findings (terrain-lod branch, 2026-07-26)

Measured on the real target (Intel UHD, Godot 4.5 Compatibility / OpenGL 3.3) with `uhd_stress.tscn`, vsync off. Camera is bird's-eye (sees the whole 2000m terrain — so no frustum-cull benefit shows here; note that when reading draw-call results).

## Numbers

| Config | draw calls | tris | FPS | frame |
|---|---|---|---|---|
| 768 subdiv, TILED 8x8, displace on, 5k trees | 67 | 4.57M | 62 | 16.2ms |
| 768 subdiv, ONE MESH, displace on, 5k trees | 12 | 4.70M | 52 | 19.1ms |
| + overdraw on (4000 alpha cards) | 13 | 4.71M | 48 | 20.8ms |

## Conclusions

1. **~4.7M tris + vertex displacement + foliage holds ~50 fps.** Millions of triangles are affordable — the base terrain is not the scary cost. (Earlier finding: 200k dense cones ≈ 142M tris was the wall — foliage needs LOD/billboards/culling, base terrain does not.)
2. **Draw-call count is NOT a bottleneck at these levels** (12 vs 67 ≈ same perf). The 62-vs-52 gap is camera-angle variance (submitted tri counts are ~equal), not tiled-being-faster. **This kills the main argument for a geometry clipmap** ("few draw calls suit weak GPUs" — untrue on this chip up to ~67).
3. **Overdraw is cheap** (4000 stacked alpha layers cost ~4 fps) — haze + foliage-alpha are safe.
4. **Vertex texture fetch is affordable** (displacement on throughout).

## What the test could NOT show

Frustum culling: the aerial camera sees the entire terrain, so tiling had nothing to cull (tri counts equal). At *ground level* the camera sees only a near wedge + horizon, where tiling culls most of the ring — a real advantage over a clipmap (which renders its full concentric rings regardless of facing). A ground-camera culling test would confirm the magnitude.

## Revised LOD lean (was: clipmap)

**Chunked/tiled LOD with CDLOD morphing** now looks the better fit:
- draw calls are cheap (proven) → clipmap's headline advantage is moot
- ground-level frustum culling favours tiles
- tiles map directly onto the substrate 128m tile pyramid (already decided) — one structure
- per-tile CPU meshes → trivial collision → render-authoritative placement for free
- CDLOD vertex-morphing (not skirts) addresses the seam cracks/pops that made past chunked-LOD attempts frustrating

Not yet a decision — next prototype step is a minimal tiled+CDLOD terrain (or first a ground-camera culling measurement). Clipmap kept as fallback if CDLOD morphing proves fiddly.
