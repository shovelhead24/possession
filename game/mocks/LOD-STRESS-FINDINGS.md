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

## Ground-camera culling test (2026-07-27)

Added `[G]` ground camera, tile grid 8→12. Result: **tiled ~10% faster than one-mesh at 1024 subdiv** (57 fps, 96 draw calls, 4.75M tris, ground cam), and never worse. Minor pop-in on camera-adjacent tiles observed.

- **Caveat — conservative case:** 2km terrain is small enough to see whole at eye level, so ground culling was modest (~144 tiles → ~96 drawn). The ~10% is therefore a *floor*; the real game renders terrain to the horizon via LOD, sees only ~10–20% of the ring at once, so the culling win will be substantially larger. Tiling never lost.
- **The pop-in is the expected naive-version artifact**, and exactly what the real technique fixes: CDLOD vertex-morphing for LOD-level pop, plus a small frustum cull-margin for edge pop when turning.

**Direction (confirmed, not yet graduated to .decisions/main):** chunked/tiled LOD + CDLOD morphing. Draw calls proven cheap, tiling proven ≥ one-mesh and better at detail, maps onto the substrate tile pyramid, per-tile collision free. Remaining risk to retire before graduating: does CDLOD morphing actually kill the pop without being fiddly? → build a minimal tiled+CDLOD prototype next.
