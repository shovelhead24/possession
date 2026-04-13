---
plan: 01-02
phase: 01-editor-mode-infrastructure
status: complete
---

# Summary: Plan 01-02 — Camera Controls and Player Marker

## Files Modified

| File | Change | Notes |
|------|--------|-------|
| `game/editor_controller.gd` | +107 lines net | Full rewrite adding all camera controls and marker |

## What Was Built

- **Player marker**: Orange unshaded capsule (CapsuleMesh, radius 0.6, height 2.2) using `SHADING_MODE_UNSHADED` for GL Compatibility renderer visibility. Hidden in play mode, shown on editor enter.
- **WASD pan**: Camera-relative using `editor_camera.global_transform.basis` — survives orbit rotation. Speed scales with altitude.
- **Q/E altitude**: Continuous, clamped to ALTITUDE_STEPS range.
- **1/2 zoom**: Discrete ALTITUDE_STEPS (8 levels: 30–1200m) with 0.15s debounce.
- **Orbit**: Shift+LMB drag adjusts `_orbit_yaw` and `_orbit_pitch` (clamped -1.5 to -0.1 rad).
- **Mouse pan**: Ctrl+LMB drag pans focus point in screen plane.
- **Cursor**: Ctrl press → CURSOR_DRAG, release → CURSOR_ARROW. Also reset in `exit_editor_mode()`.
- **`_update_camera_transform()`**: Positions camera from focus point + spherical offset, always looks at focus.

## Tuning Decisions

- `BASE_PAN_SPEED = 50.0` — felt natural at mid-altitude; scales with altitude so high-up pans don't feel sluggish
- `ORBIT_SENSITIVITY = 0.005` — matches typical RTS camera feel
- `PAN_MOUSE_SENSITIVITY = 0.3` — screen-plane drag feels 1:1 at default altitude

## Open Issues for Plan 01-03

- `_zoom_step` is available for HUD display (Zoom: {_zoom_step})
- `_get_terrain_cursor_world_pos()` raycasts against collision layer 1 — confirm terrain uses layer 1
