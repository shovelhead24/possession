# Possession — Project Context

## What This Is

A Godot 4.5 sci-fi FPS set on a Halo-style ringworld. The player explores a procedurally generated alien landscape — ancient structures, mountains, valleys, water — from on foot or in a Warthog-style vehicle. Target: 100+ hour open-world ambition, shipped incrementally. Primary hardware target is Intel UHD / integrated GPU (Dell Latitude 5410 — "potato hardware").

## Stack

| Layer | Choice |
|---|---|
| Engine | Godot 4.5 |
| Renderer | GL Compatibility (OpenGL 3.3 — Intel UHD safe) |
| Language | GDScript |
| Dev pipeline | GitHub Codespaces (edit) → git push → PowerShell watcher on laptop (auto-pull + relaunch Godot) |
| Version control | GitHub — `shovelhead24/possession`, branch `main` |

## What Exists (Validated)

- ✓ Procedural terrain — chunk-based (100m chunks), 4 LOD levels [16,6,3,2] verts, 1600m render distance
- ✓ Biome system — 7 biome types; active: River Valley (wide valleys + distant peaks)
- ✓ Terrain shader — grass/stone/snow/sand blending by absolute world Y; fog hides chunk boundary at 1200–1900m
- ✓ Prop pool — object-pooled trees and grass sprites (LOD0-1 only)
- ✓ Ancient structures — procedural monoliths, deterministic per chunk, LOD0-1 only
- ✓ Day/night cycle
- ✓ Player controller — WASD + mouse, fly mode (F), zoom (R3 cycles 1×/1.5×/3×/10×), jump
- ✓ Vehicle — Warthog with enter/exit, driver camera, physics driving
- ✓ Weapons — Plasma Carbine + Railgun, weapon switch (Q), first-person arms viewport
- ✓ Enemies — enemy GLTF with controller
- ✓ Watch-and-run pipeline — PowerShell watcher, D-pad Up reloads via `git pull` + `quit()`
- ✓ Gaussian mountain amplifier — localized peak boost at world (-1137, 431), ~620m tall

## Known Bugs / Open Issues

- **Snow not appearing on peak** — peak reaches Y:633 (above 600m threshold), slope suppression disabled, cliff blend still seems to override. Root cause unknown. Deferred.
- Snow thresholds kept at 600m/650m (realistic altitude, not to be changed without a matching terrain_height increase)

## Key Decisions

| Decision | Rationale | Outcome |
|---|---|---|
| GL Compatibility renderer | Must run on Intel UHD (no Vulkan) | Locked |
| 100m chunk size | 4× larger than original 25m — same polygon budget, 4× render distance | Locked |
| LOD resolutions [16,6,3,2] | Balances detail vs. polygon count at distance | Locked |
| Fog begin=1200m end=1900m | Hides 1600m chunk boundary before terrain ends | Locked |
| `get_tree().quit()` for reload | `reload_current_scene()` leaves stale GDScript static vars | Locked |
| Gaussian peak amplifier | More natural than global terrain_height increase; user wants snow only on that peak | Locked |
| Slope-based snow suppression | Disabled for now — pure height-based blending | Pending revisit |
| Structures spawn LOD0-1 only | LOD2+ too sparse/coarse to worth the node cost | Locked |

## Next Milestone

**Milestone 1 — Terrain Editor + World Shaping**

Give the designer (the user) direct control over the world: paint terrain height, place biome zones, set landmark points, save/load edits. This is the foundation for all future content authoring.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

---
*Last updated: 2026-04-12 after session 1 initialization*
