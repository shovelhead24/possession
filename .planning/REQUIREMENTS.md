# Possession — Requirements

## Milestone 1: Terrain Editor + World Shaping

### Validated (already exists)

- ✓ Procedural terrain generation with 4 LOD levels
- ✓ Biome system with per-biome noise traits
- ✓ Terrain shader (grass/stone/snow/sand by height + slope)
- ✓ Prop pool (trees, grass sprites)
- ✓ Player + vehicle controller
- ✓ Watch-and-run dev pipeline

### Active

#### Terrain Editor — Core
- [ ] In-engine terrain editor accessible via keybind (not a separate tool)
- [ ] Paint height — raise/lower terrain with a brush (radius + strength)
- [ ] Smooth brush — average heights in an area
- [ ] Flatten brush — level terrain to a target height (useful for roads, landing pads)
- [ ] Brush radius and strength controls (keyboard or scroll)
- [ ] Undo/redo for brush strokes (at least 10 steps)

#### Terrain Editor — Biome Painting
- [ ] Paint biome zones onto the terrain (overrides procedural biome at that location)
- [ ] Visual overlay showing current biome at each chunk (toggle on/off)

#### Terrain Editor — Landmark Placement
- [ ] Place/move/delete named landmark points in the world
- [ ] Landmark list panel showing all landmarks with coordinates
- [ ] Teleport to landmark from editor

#### Terrain Editor — Persistence
- [ ] Save terrain edits to a file (`terrain_edits.tres` or similar)
- [ ] Load terrain edits on startup (edits overlay procedural generation)
- [ ] Edits survive reload (D-pad Up / R key)

#### Snow Fix (deferred bug)
- [ ] Diagnose why snow doesn't appear above 600m despite height threshold being met
- [ ] Fix: either cliff_blend overriding, vertex_height wrong in shader, or LOD mesh too coarse

#### Performance Baseline
- [ ] Stable 30+ FPS on Intel UHD with editor open
- [ ] Editor doesn't regenerate chunks unnecessarily on brush stroke

### Out of Scope (Milestone 1)

- Coastline editor / water placement — deferred (complex, needs its own milestone)
- Multiplayer — not in scope
- Enemy AI improvements — not in scope for this milestone
- Saving full world state (enemies, items) — not in scope, terrain edits only

---
*Last updated: 2026-04-12*
