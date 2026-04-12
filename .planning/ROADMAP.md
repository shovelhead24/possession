# Possession — Roadmap

## Milestone 1: Terrain Editor + World Shaping

> Give the designer direct in-engine control over the world. Paint height, smooth, flatten, save/load edits. Foundation for all future content authoring.

---

### Phase 1 — Editor Mode Infrastructure
*Tab toggles an overhead isometric editor camera. Player freezes, cursor appears, HUD shows cursor world XZ + zoom. Full camera navigation (pan/orbit/zoom) but no brushes yet.*

**Plans:** 3 plans
- [ ] 01-01-PLAN.md — Editor mode toggle, EditorController autoload, camera handoff, player freeze signal
- [ ] 01-02-PLAN.md — Editor camera controls (WASD pan, Q/E altitude, 1/2 zoom, Shift/Ctrl+drag) and player marker mesh
- [ ] 01-03-PLAN.md — Editor HUD overlay (cursor XZ + zoom label) and crosshair hide

**UAT:** Press Tab → player freezes, overhead camera, orange marker at player, HUD shows live X/Z/zoom. WASD/QE/12 navigate, Shift-drag orbits, Ctrl-drag pans. Tab again → back to play.

---

### Phase 2 — Height Brush (Raise/Lower)
*Paint height changes onto terrain in real time. Affects the procedural mesh.*

**Plans:**
- 2.1 Brush input — scroll to resize, hold key to strengthen, left/right click for raise/lower
- 2.2 Height delta accumulation — store per-chunk height offsets that add to procedural heights
- 2.3 Chunk rebuild on brush stroke — dirty-flag affected chunks, rebuild mesh only when needed
- 2.4 Shader parameter propagation — rebuilt chunks pick up correct snow/grass thresholds

**UAT:** Paint raises a hill. Move away and return — hill persists. FPS stays 30+.

---

### Phase 3 — Smooth + Flatten Brushes
*Secondary brush modes for terrain cleanup and road-building.*

**Plans:**
- 3.1 Brush mode selector (cycle with key or number keys)
- 3.2 Smooth brush — Gaussian-weighted average of nearby height offsets
- 3.3 Flatten brush — sample height at click, level surrounding area to that height
- 3.4 Visual mode indicator in HUD

**UAT:** Smooth removes spiky artifacts from aggressive raise. Flatten produces a driveable surface.

---

### Phase 4 — Undo/Redo
*At least 10 undo steps for brush strokes.*

**Plans:**
- 4.1 Stroke history stack — snapshot dirty chunk offsets before each stroke
- 4.2 Undo (Ctrl+Z) — pop and restore previous offsets, rebuild affected chunks
- 4.3 Redo (Ctrl+Y) — reapply undone strokes
- 4.4 Stack limit and memory cap

**UAT:** Paint 12 strokes, undo 10 of them — terrain reverts correctly. Redo restores them.

---

### Phase 5 — Save / Load Terrain Edits
*Persist height edits across reloads.*

**Plans:**
- 5.1 Serialise height offset map to `terrain_edits.json` (chunk coords → offset array)
- 5.2 Auto-save on edit (debounced, every 5s of inactivity)
- 5.3 Load edits on `TerrainManager._ready()`, apply before first chunk build
- 5.4 D-pad Up reload picks up saved edits cleanly

**UAT:** Paint a hill, reload (D-pad Up), hill is still there.

---

### Phase 6 — Biome Paint + Overlay
*Override procedural biome per chunk. Toggle visual overlay.*

**Plans:**
- 6.1 Biome paint brush — click chunk to assign biome type
- 6.2 Biome override map serialised alongside height edits
- 6.3 Chunk rebuild uses overridden biome traits when available
- 6.4 Overlay toggle — colour each chunk by biome type

**UAT:** Paint biome over a chunk, chunk changes appearance. Overlay shows biome colours. Survives reload.

---

### Phase 7 — Landmark Placement
*Named point-of-interest markers with teleport.*

**Plans:**
- 7.1 Place landmark at cursor position (click in editor mode)
- 7.2 Landmark list panel — name, coordinates, delete button
- 7.3 Rename landmark inline
- 7.4 Teleport player to landmark (from panel or map)
- 7.5 Landmarks serialised to `terrain_edits.json`

**UAT:** Place 3 landmarks, rename them, teleport to each, reload — all persist.

---

### Phase 8 — Snow Bug Fix
*Diagnose and fix snow not appearing above 600m.*

**Plans:**
- 8.1 Add debug visualisation — display `vertex_height` as colour in shader to confirm values reaching chunk at peak
- 8.2 Identify root cause (cliff_blend override? LOD mesh too coarse? material param not set on that chunk?)
- 8.3 Fix and verify snow appears on mountain peak at (-1137, 431)
- 8.4 Remove debug visualisation

**UAT:** Fly to peak, Y > 600, peak is visibly snow-capped.

---

## Backlog (Future Milestones)

- Coastline / water placement editor
- Enemy spawner placement in editor
- Foliage density painting
- Export terrain as heightmap image
- Multiplayer foundations
- Quest / narrative system

---
*Last updated: 2026-04-12*
