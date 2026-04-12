# Phase 1: Editor Mode Infrastructure - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Enter/exit a full isometric editor view from the running game. Tab toggles between play mode and editor mode. In editor mode: player is frozen, an orthographic/isometric camera takes over with pan/zoom/tilt controls, the player is represented as a marker node, and a minimal HUD shows world coordinates + zoom level.

This phase establishes the editor infrastructure only. No terrain manipulation tools — those are Phase 2+.

</domain>

<decisions>
## Implementation Decisions

### Toggle Keybind
- **D-01:** Tab key toggles editor mode on/off. No conflict with existing bindings (F=fly, Q=weapon switch, T/Y/G=adjust modes, WASD=move).

### Editor Camera View
- **D-02:** Entering editor mode switches to an overhead/isometric camera perspective. The play camera is suspended; a dedicated editor Camera3D takes over.
- **D-03:** Camera starts at a reasonable overhead position above the player's current world location.

### Editor Camera Controls
- **D-04:** WASD = pan across the map (world-space panning)
- **D-05:** Q = move camera up, E = move camera down (altitude)
- **D-06:** 1 = zoom in, 2 = zoom out
- **D-07:** Shift + mouse drag = pitch and yaw (orbital rotation around focus point)
- **D-08:** Ctrl + mouse drag = mouse-driven pan (hand cursor icon while Ctrl held)

### Player Representation
- **D-09:** Player is shown as a simple capsule or arrow mesh marker at their world position in the editor view. Marker stays visible at all zoom levels.

### Editor HUD
- **D-10:** Minimal HUD: top-left corner label showing cursor world position (X, Z) and current zoom level. No toolbar in Phase 1 — brush tool HUD added in Phase 2+.
- **D-11:** Crosshair is hidden when in editor mode.

### Architecture
- **D-12:** Editor state lives in a separate `EditorController.gd` autoloaded singleton. Player.gd checks an `editor_mode` flag and freezes its own input/physics. Clean separation so the editor grows independently from player code.
- **D-13:** `player.gd` remains the owner of its freeze logic (sets `set_physics_process(false)` and releases mouse when EditorController signals mode change). EditorController doesn't reach into player internals.

### Claude's Discretion
- Exact isometric angle (45°, 30°, or free) — choose what looks clearest at typical editing zoom levels
- Camera zoom range limits (min/max altitude)
- Pan speed scaling with zoom level (faster pan at high altitude, slower when zoomed in close)
- Marker mesh choice (capsule vs arrow vs chevron)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above.

### Key files to read before planning
- `game/player.gd` — Existing mode flags (fly_mode, arms_adjust_mode), mouse mode handling, HUD instantiation pattern
- `game/terrain_manager.gd` — TerrainManager autoload structure (EditorController follows same pattern)
- `game-trees/hud.tscn` — Existing HUD scene (CanvasLayer with Crosshair) — editor HUD extends this or adds alongside

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Input.MOUSE_MODE_VISIBLE / MOUSE_MODE_CAPTURED` — already toggled in player.gd focus events; editor toggle reuses same pattern
- `hud_instance` (CanvasLayer) — player already manages a HUD; editor HUD overlay can be a second CanvasLayer child or extend hud.tscn
- `hud_scene` (PackedScene) — loaded dynamically; editor HUD scene follows same load pattern

### Established Patterns
- Boolean mode flags on player: `fly_mode`, `arms_adjust_mode`, `weapon_adjust_mode`, `prop_adjust_mode` — editor_mode follows this pattern on the player side (the flag), even though logic lives in EditorController
- Autoload pattern: `terrain_manager.gd` is added as autoload in project.godot — EditorController registers the same way
- `get_tree().quit()` for clean reload — editor state must survive or cleanly reinitialize across D-pad Up reloads (deferred to Phase 5 persistence, but architect to not break it)

### Integration Points
- `player.gd` `_input()` / `_physics_process()` — editor mode disables these when active
- `world.tscn` — EditorController node added here or as autoload; editor camera is a child of world or a separate scene
- Project autoloads (project.godot) — EditorController registered as autoload alongside TerrainManager

</code_context>

<specifics>
## Specific Ideas

- User described the long-term vision as "a build tool that allows us to configure the game world while preserving the memory compression afforded by procedural generation, so each 10x10km sector is tiny on disk." Editor mode is the shell for this.
- Zoom levels intended to span 10×10m detail view all the way to 10×10km sector view — Phase 1 establishes the camera zoom infrastructure; extreme zoom limits refined later.
- User wants the editor to eventually feel like a full level editor (terrain, biomes, props, vehicles, triggers, sounds, paths) — architecture should not trap this in a corner.

</specifics>

<deferred>
## Deferred Ideas

The following were raised during discussion but belong in future phases:

- **Terrain manipulation tools** (raise, lower, smooth, noise, carve, hollow) — Phase 2–3
- **Biome paint + texture paint** — Phase 6
- **Prop/vehicle/trigger/sound placement** — Post-milestone
- **Path-finding visualisation** — Post-milestone
- **Tree/rock/vegetation painting** — Post-milestone
- **Water fill + coastline auto-resolve** — Post-milestone (flagged out of scope for Milestone 1)
- **Zoom range 10m→10km** — Phase 1 establishes camera; extreme zoom limits and sector-level LOD tuned in later phases
- **Click player marker to teleport** — Phase 7 (landmark/teleport phase) or can be added as stretch in Phase 1 if trivial

</deferred>

---

*Phase: 01-editor-mode-infrastructure*
*Context gathered: 2026-04-12*
