# Phase 1: Editor Mode Infrastructure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 01-editor-mode-infrastructure
**Areas discussed:** Toggle keybind, Fly-while-editing (pivoted to editor view), HUD style, Editor architecture

---

## Toggle Keybind

| Option | Description | Selected |
|--------|-------------|----------|
| Tab | Clean, obvious, not currently bound | ✓ |
| Backtick / tilde | Classic dev-console feel | |
| F2 | Function key, hard to hit accidentally | |
| E | Easy to reach, future conflict risk | |

**User's choice:** Tab
**Notes:** No conflict with existing bindings (F=fly, Q=weapon switch, T/Y/G=adjust modes).

---

## Editor View (formerly "Fly-while-editing")

This area pivoted significantly when the user described a much larger vision.

| Option | Description | Selected |
|--------|-------------|----------|
| FPS overlay (original question) | Freeze player in place, show HUD overlay, use FPS camera | |
| Isometric/overhead editor view | Dedicated overhead camera, pan/zoom/tilt, player as marker node | ✓ |

**User's choice:** Isometric/overhead view (not an FPS overlay)
**Notes:** User described the long-term vision: a full level editor with terrain manipulation (raise/lower/smooth/noise/carve/hollow/biomes/textures/trees/rocks/roads/vegetation/water/coastlines), prop/vehicle/script/sound placement, path-finding visualisation, and zoom from 10×10m to 10×10km. Editor preserves procedural generation compression — each 10×10km sector remains tiny on disk.

Camera controls specified precisely:
- WASD = pan
- Q/E = altitude up/down
- 1/2 = zoom in/out
- Shift + mouse = pitch and yaw
- Ctrl + mouse = pan with hand cursor icon

---

## Player Representation

| Option | Description | Selected |
|--------|-------------|----------|
| Simple mesh marker | Small capsule/arrow at player world position | ✓ |
| Full player model | Actual CharacterBody3D visible | |
| 2D icon overlay | CanvasLayer waypoint-style marker | |

**User's choice:** Simple mesh marker
**Notes:** Should stay visible at all zoom levels.

---

## Editor HUD

| Option | Description | Selected |
|--------|-------------|----------|
| Coordinates + zoom level | Top-left: cursor world position (X, Z) + zoom | ✓ |
| Full toolbar | Mode name, brush buttons, coordinates | |
| Nothing for Phase 1 | No HUD until brushes in Phase 2 | |

**User's choice:** Coordinates + zoom level
**Notes:** Minimal — just enough to orient. Crosshair hidden in editor mode.

---

## Editor Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Separate EditorController autoload | Singleton, player checks flag and self-freezes | ✓ |
| Extend player.gd | Consistent with fly_mode pattern but player.gd already 924 lines | |

**User's choice:** Separate EditorController autoload
**Notes:** EditorController grows independently from player code. Player.gd handles its own freeze when signalled.

---

## Claude's Discretion

- Exact isometric angle (45°, 30°, or free)
- Camera zoom range limits
- Pan speed scaling with zoom level
- Player marker mesh shape

## Deferred Ideas

- Full terrain manipulation toolset (Phases 2–3)
- Biome paint, texture paint (Phase 6)
- Prop/vehicle/trigger/sound placement (post-milestone)
- Path-finding visualisation (post-milestone)
- Water fill + coastline auto-resolve (post-milestone)
- Zoom range tuning from 10m to 10km (later phases)
- Click player marker to teleport (Phase 7 / stretch)
