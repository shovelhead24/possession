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

## Shadows on UHD (2026-07-27, cdlod build 15→16)

Enabling directional-light shadows with the **terrain casting** dropped cdlod from ~140 fps to **~8 fps**. Directional shadows re-render caster geometry into the shadow map each frame; the full double-sided (`cull_disabled`) LOD terrain is a huge caster.

**Fix (build 16):** terrain `cast_shadow = OFF` (receive-only — it only needs the car/tree shadows *on* it), `SHADOW_ORTHOGONAL` (single split), `directional_shadow_max_distance = 300`. Lesson for the real game: **big terrain never casts sun shadows on this GPU** — bake/skip terrain self-shadow; let only props (car, trees, characters) cast into a short near-camera CSM band.

## Object LOD: trees (2026-07-27, cdlod build 17→22, `object-lod` branch)

**Tagged reference point: `lod-reference-b22`** (git tag on `object-lod`) — pin to this commit when porting the systems below elsewhere.

Naive single-mesh trees (`low_poly_red_spruce...`, 5,799 tris, no LODs shipped) cost **5.5M tris at ~1000 instances** — this alone dropped cdlod from ~140fps to ~8fps (not the shadow pass, which was a red herring first diagnosed and fixed separately; the real cost was `cull_disabled` + alpha-`discard` foliage overdraw at that tri count). Confirms the earlier "200k cones = 142M tris" object-LOD wall from a second angle: opaque terrain tolerates millions of tris, discard-alpha foliage does not.

**Fix: found a pre-made LOD pack** (`realistic_fir_trees_pack_lods_gameready`, 3 variants, real LOD0/1/2 geometry + LOD3 pre-baked billboard) instead of hand-authoring impostors. Parsed by regex on GLTF node names (`<variant>_LOD<n>`), one combined mesh per (variant, LOD), one MultiMeshInstance3D per (variant, LOD) — trees are bucketed into the right MultiMesh every frame by distance² to camera (cheap, no per-tree draw calls).

**Tuned bands** (`_tree_lod_dist`, tunable live via `[G]`/`[B]`): full geometry (12,969 tris) only within **20m** (the "immediate vicinity" the game will actually want), LOD1 (6,633 tris) to 35m, LOD2 (3,268 tris) to 55m, billboard (20 tris) to 220m — then culled. In FLY mode the billboard band multiplies ×14 (~3km) since billboards are ~free and aerial views need forest-to-horizon, not a pop-wall at 220m.

**Gotchas fixed along the way:**
- Each LOD mesh must be **normalized to the same height + shared pivot** (unit height, base at y=0, centred X/Z) before scaling to world size — otherwise different LODs of the same tree have different intrinsic bounding boxes and switching tiers visibly resizes/jumps the tree.
- Foliage/billboard materials import **unshaded** (baked lighting assumption) — must force per-pixel shading or they read flat and don't match the lit near geometry.
- Billboards are a **cross of flat quads**; the up-facing quad's normal points straight at the sun (near-`N·L`=1, blown out) while the vertical quads go dark — plain Lambert lighting on a billboard cross reads as harsh per-plane contrast. Fixed with a **wrapped/half-Lambert diffuse** custom shader (`tree_foliage.gdshader`, `light()` override): `w = clamp(ndl*(1-wrap)+wrap, 0, 1)` with `wrap≈0.55` compresses the range so the canopy reads as one soft mass instead of lit metal plates.
- Discard-alpha foliage should not cast shadows (`cast_shadow = OFF` on the tree MultiMeshInstances) — same shadow-cost lesson as the terrain, worse per-pixel due to discard breaking early-Z.

**Result:** 27,500 trees (2.4km × 2.4km patch) at 64–85fps on Intel UHD, LOD populations shown live in HUD (`LOD0/1/2/bill` counts). Not yet graduated to `.decisions/` — validated in the `object-lod` mock; next step is porting into the "real" ring scene (`ring_vibes.gd`), which is where render-authoritative placement, walls, and full ring context already live.
