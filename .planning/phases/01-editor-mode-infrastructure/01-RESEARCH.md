# Phase 1: Editor Mode Infrastructure - Research

**Researched:** 2026-04-12
**Domain:** Godot 4 — camera switching, autoload singletons, input isolation, 3D UI overlay
**Confidence:** HIGH (all findings verified against codebase directly)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Tab key toggles editor mode on/off.
- **D-02:** Entering editor mode switches to an overhead/isometric camera. Play camera suspended; dedicated editor Camera3D takes over.
- **D-03:** Editor camera starts overhead above the player's current world location.
- **D-04:** WASD = pan across the map (world-space panning).
- **D-05:** Q = move camera up, E = move camera down (altitude).
- **D-06:** 1 = zoom in, 2 = zoom out.
- **D-07:** Shift + mouse drag = pitch and yaw (orbital rotation around focus point).
- **D-08:** Ctrl + mouse drag = mouse-driven pan (hand cursor icon while Ctrl held).
- **D-09:** Player shown as simple capsule or arrow mesh marker at their world position. Visible at all zoom levels.
- **D-10:** Minimal HUD: top-left label showing cursor world X,Z and current zoom level. No toolbar in Phase 1.
- **D-11:** Crosshair hidden in editor mode.
- **D-12:** Editor state lives in `EditorController.gd` autoloaded singleton. Player checks `editor_mode` flag and freezes itself.
- **D-13:** `player.gd` owns its freeze logic (`set_physics_process(false)` + mouse release). EditorController signals mode change; does NOT reach into player internals.

### Claude's Discretion

- Exact isometric angle (45°, 30°, or free) — choose what looks clearest at typical editing zoom levels.
- Camera zoom range limits (min/max altitude).
- Pan speed scaling with zoom level.
- Marker mesh choice (capsule vs arrow vs chevron).

### Deferred Ideas (OUT OF SCOPE)

- Terrain manipulation tools (Phase 2–3)
- Biome paint + texture paint (Phase 6)
- Prop/vehicle/trigger/sound placement (post-milestone)
- Path-finding visualisation (post-milestone)
- Tree/rock/vegetation painting (post-milestone)
- Water fill + coastline (post-milestone)
- Zoom range 10m→10km extreme limits (tuned in later phases)
- Click player marker to teleport (Phase 7 or stretch)
</user_constraints>

---

## Summary

Phase 1 adds an editor camera mode toggled by Tab. The architecture is already well-defined by the CONTEXT.md decisions. The main technical work is: (1) registering an EditorController autoload, (2) emitting a signal to player.gd to freeze input/physics and hand off mouse control, (3) spawning a dedicated Camera3D above the player position and making it `current`, (4) implementing WASD/Q/E/1/2 and Shift+drag/Ctrl+drag in EditorController's `_process`/`_input`, (5) rendering a player position marker mesh, (6) showing a minimal CanvasLayer HUD overlay.

The existing codebase has clear patterns for all of these. The HUD is a CanvasLayer instantiated by player.gd via a PackedScene; the editor HUD should follow the same pattern but be owned/spawned by EditorController. The player already has `set_physics_process(false)` and `Input.MOUSE_MODE_VISIBLE` patterns. TerrainManager is a plain Node3D in world.tscn (not a project autoload) — EditorController should follow the same pattern: a Node3D child of World with a script, not a project.godot autoload.

Key conflict to avoid: WASD in editor mode conflicts with the player's move_forward/back/left/right input actions. The player freezes via `set_physics_process(false)` but `_input()` still fires unless also disabled. The plan must explicitly call `set_process_input(false)` on the player (or guard with an `if editor_mode: return` early exit).

**Primary recommendation:** Implement EditorController as a Node3D child of World (matching TerrainManager pattern). Use a signal `editor_mode_changed(active: bool)` to notify player.gd. The editor Camera3D is a child of EditorController. Camera handoff is done via `camera.current = true/false`.

---

## Standard Stack

### Core
| Component | Godot API | Purpose | Why Standard |
|-----------|-----------|---------|--------------|
| Camera3D | `Camera3D` node, `current = true` | Activate/deactivate camera | Only one Camera3D with `current = true` renders at a time |
| CanvasLayer | `CanvasLayer` node | Editor HUD overlay | Same as existing HUD — always on top, screen-space |
| PhysicsDirectSpaceState3D | `PhysicsRayQueryParameters3D` + `get_world_3d().direct_space_state.intersect_ray()` | Terrain raycast for cursor world position | Standard Godot terrain picking |
| Signal | `signal editor_mode_changed(active: bool)` on EditorController | Decoupled notification to player | Matches project signal patterns |

### No External Libraries Needed
This phase is pure GDScript + Godot built-ins. No npm, no plugins.

---

## Architecture Patterns

### Recommended Structure

New files to create:
```
game/
├── editor_controller.gd       # EditorController — autoload behavior, camera, input
├── editor_hud.tscn             # CanvasLayer with EditorInfoLabel
```

Modifications to existing files:
```
game/world.tscn                 # Add EditorController node (child of World)
game/player.gd                  # Connect to EditorController.editor_mode_changed signal
game/project.godot              # Add toggle_editor input action (Tab key)
```

### Pattern 1: Camera Handoff

**What:** Make the editor Camera3D `current` when entering editor mode; restore play camera when exiting.

**Verified pattern** [VERIFIED: codebase — world.tscn line 64, 96]:
The play camera is `Player/Head/Camera3D`. In Godot 4, setting `camera.current = true` on any Camera3D in the scene tree makes it the active camera. Setting `current = false` (or setting another camera `current = true`) reverts it.

```gdscript
# EditorController.gd
func enter_editor_mode():
    editor_camera.global_position = player_ref.global_position + Vector3(0, 150, 0)
    editor_camera.current = true
    emit_signal("editor_mode_changed", true)

func exit_editor_mode():
    editor_camera.current = false
    # play camera automatically becomes current again (it's the only other Camera3D)
    emit_signal("editor_mode_changed", false)
```

Note: If the play camera does not have `current = true` set explicitly in world.tscn, Godot uses the first Camera3D it finds. The world.tscn currently has `Camera3D` under `Player/Head` with no explicit `current` property (meaning Godot defaults to it). Setting editor_camera `current = false` may not reliably restore the play camera unless the play camera also has `current = true`. The plan should set `play_camera.current = true` explicitly on exit.

### Pattern 2: Freeze Player Input

**What:** Disable player movement and mouse look when editor mode is active.

**Verified from codebase** [VERIFIED: player.gd lines 328–394]:
`_physics_process` handles all movement including fly mode and gravity. `_input` handles mouse look, shooting, keybinds. Both must be disabled.

```gdscript
# player.gd — connect to EditorController signal in _ready()
func _ready():
    # ... existing code ...
    var ec = get_node_or_null("/root/World/EditorController")
    if ec:
        ec.editor_mode_changed.connect(_on_editor_mode_changed)

func _on_editor_mode_changed(active: bool):
    set_physics_process(!active)
    set_process_input(!active)
    if active:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
```

**Critical detail:** The player's `_on_window_focus_lost` / `_on_window_focus_gained` callbacks [player.gd lines 139–143] also toggle mouse mode. These will NOT conflict because they only fire on window focus change, not during normal editor toggle. No changes needed there.

**Warning:** `_physics_process` on `CharacterBody3D` being disabled means the player body stops receiving gravity and collision updates — correct behavior for editor mode.

### Pattern 3: EditorController as World Node (not project autoload)

**What:** TerrainManager is NOT a project.godot autoload [VERIFIED: project.godot — no `[autoload]` section exists]. It is a Node3D child of World in world.tscn [VERIFIED: world.tscn line 134]. EditorController must follow the same pattern.

**Why:** The project uses `get_node_or_null("/root/World/TerrainManager")` access pattern [VERIFIED: player.gd line 219]. EditorController accessed the same way: `/root/World/EditorController`.

**Implementation:**
```gdscript
# In world.tscn — add node:
[node name="EditorController" type="Node3D" parent="."]
script = ExtResource("N_editor_ctrl")
```

### Pattern 4: Editor HUD CanvasLayer

**What:** A second CanvasLayer for editor info (cursor world XZ + zoom level), shown only in editor mode.

**Verified pattern** [VERIFIED: player.gd lines 110–133, hud.tscn]: The play HUD is instantiated dynamically from a PackedScene by player.gd and added to the scene tree via `get_parent().add_child.call_deferred(hud_instance)`.

EditorController follows the same pattern:
```gdscript
# EditorController.gd
@export var editor_hud_scene: PackedScene
var editor_hud_instance: Node = null

func enter_editor_mode():
    if editor_hud_scene and not editor_hud_instance:
        editor_hud_instance = editor_hud_scene.instantiate()
        get_tree().current_scene.add_child(editor_hud_instance)
    if editor_hud_instance:
        editor_hud_instance.visible = true
```

**Crosshair hiding** [VERIFIED: hud.tscn lines 7–18, player.gd lines 125–128]:
Crosshair is the `Crosshair` child of the HUD CanvasLayer. Player holds `hud_instance` reference. On editor mode change, player.gd can do:
```gdscript
if hud_instance:
    var crosshair = hud_instance.get_node_or_null("Crosshair")
    if crosshair:
        crosshair.visible = !active
```

### Pattern 5: Player Marker Mesh

**What:** A visible capsule or arrow mesh at player position in the editor view.

**Verified available mesh types** [ASSUMED — standard Godot API]: `CapsuleMesh`, `CylinderMesh`, `SphereMesh`, `PrismMesh`, `TorusMesh` are all built-in Godot mesh types usable without importing assets.

**Recommendation (Claude's discretion):** Use a flat arrow/chevron made from a `PrismMesh` scaled tall and thin with a bright emissive material. It's more readable at overhead angles than a capsule (which is symmetric and hard to see orientation). Alternative: a simple `CapsuleMesh` with a bright color. Either is trivial to implement.

```gdscript
# EditorController.gd
var player_marker: MeshInstance3D

func _create_player_marker():
    player_marker = MeshInstance3D.new()
    var mesh = CapsuleMesh.new()
    mesh.radius = 0.5
    mesh.height = 2.0
    player_marker.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.4, 0.0)  # Orange, visible against terrain
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.4, 0.0)
    mat.emission_energy = 2.0
    player_marker.material_override = mat
    add_child(player_marker)
    player_marker.visible = false

func _process(_delta):
    if is_editor_active and player_ref:
        player_marker.global_position = player_ref.global_position
```

### Pattern 6: Editor Camera Controls

**What:** WASD pan, Q/E altitude, 1/2 zoom, Shift+drag orbit, Ctrl+drag pan.

**WASD conflict resolution** [VERIFIED: project.godot — move_forward/back/left/right map to W/A/S/D]:
In editor mode, player input is fully disabled. The EditorController reads raw keys, NOT the input actions (to avoid ambiguity):
```gdscript
# EditorController.gd _process(delta)
if is_editor_active:
    var pan_speed = base_pan_speed * (editor_camera.position.y / 100.0)  # Scale with altitude
    if Input.is_key_pressed(KEY_W): _focus_point += Vector3(0, 0, -pan_speed * delta)
    if Input.is_key_pressed(KEY_S): _focus_point += Vector3(0, 0,  pan_speed * delta)
    if Input.is_key_pressed(KEY_A): _focus_point += Vector3(-pan_speed * delta, 0, 0)
    if Input.is_key_pressed(KEY_D): _focus_point += Vector3( pan_speed * delta, 0, 0)
    if Input.is_key_pressed(KEY_Q): _camera_altitude += altitude_speed * delta
    if Input.is_key_pressed(KEY_E): _camera_altitude -= altitude_speed * delta
    if Input.is_key_pressed(KEY_1): _zoom_in()
    if Input.is_key_pressed(KEY_2): _zoom_out()
```

**Important:** KEY_1 and KEY_2 are currently used for biome switching in player.gd (keys 1–7 switch biomes) [VERIFIED: player.gd lines 207–221]. Since the player is frozen, this code will not run in editor mode. No conflict.

**Shift+drag orbit / Ctrl+drag pan** — handled in `_input(event)`:
```gdscript
func _input(event):
    if not is_editor_active:
        return
    if event is InputEventMouseMotion:
        if Input.is_key_pressed(KEY_SHIFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _orbit_yaw   += event.relative.x * orbit_sensitivity
            _orbit_pitch += event.relative.y * orbit_sensitivity
            _orbit_pitch  = clamp(_orbit_pitch, -1.4, -0.1)
        elif Input.is_key_pressed(KEY_CTRL) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            # Pan in screen-plane
            var right = editor_camera.global_transform.basis.x
            var forward_flat = Vector3(editor_camera.global_transform.basis.z.x, 0,
                                       editor_camera.global_transform.basis.z.z).normalized()
            _focus_point -= right    * event.relative.x * pan_mouse_sensitivity
            _focus_point += forward_flat * event.relative.y * pan_mouse_sensitivity
```

**Ctrl cursor icon** [ASSUMED — Godot Input.set_default_cursor_shape]: Godot supports `DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)` or `Input.set_default_cursor_shape()` to change cursor appearance. The plan should include setting a hand/drag cursor when Ctrl is held and resetting it on release.

### Pattern 7: Terrain Raycast for Cursor World Position

**What:** Convert mouse screen position to a world-space position on the terrain surface, for the HUD X,Z readout and Phase 2 brush placement.

**Verified pattern** [ASSUMED — standard Godot 4 raycast API]:
```gdscript
func _get_terrain_cursor_world_pos() -> Vector3:
    var viewport = get_viewport()
    var mouse_pos = viewport.get_mouse_position()
    var ray_origin = editor_camera.project_ray_origin(mouse_pos)
    var ray_dir    = editor_camera.project_ray_normal(mouse_pos)
    var ray_length = 10000.0

    var query = PhysicsRayQueryParameters3D.create(
        ray_origin,
        ray_origin + ray_dir * ray_length
    )
    query.collision_mask = 1  # Terrain layer
    var result = get_world_3d().direct_space_state.intersect_ray(query)
    if result:
        return result["position"]
    return Vector3.ZERO
```

**Note on terrain collision:** The terrain chunks use `MeshInstance3D` with `StaticBody3D` + `CollisionShape3D` [VERIFIED: terrain_chunk.gd referenced in terrain_chunk.tscn]. The raycast will hit these naturally. The HUD should show `position.x` and `position.z` (height = `position.y`).

### Anti-Patterns to Avoid

- **Reaching into player from EditorController:** D-13 forbids this. Use signal + player self-manages freeze.
- **Using input action names for editor camera WASD:** Conflicts risk if actions are ever remapped. Read raw keys with `Input.is_key_pressed(KEY_W)` etc.
- **Forgetting `set_process_input(false)` on player:** `set_physics_process(false)` alone leaves mouse look and shooting active. Both must be disabled.
- **Not re-enabling play camera explicitly on exit:** Godot does not auto-restore a previous camera when a newer one's `current` is set to false. Explicitly call `play_camera.current = true` in `exit_editor_mode()`.
- **Making the editor camera a child of Player:** Camera should be a child of EditorController (which is a child of World), so it is independent of player position/rotation.
- **Spawning editor HUD before player HUD is ready:** Player HUD is added via `call_deferred`. EditorController should also defer its HUD instantiation, or connect to a post-ready signal.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Camera activation | Custom camera manager | `camera.current = true/false` — built into Godot |
| Screen-to-world ray | Manual ray math | `camera.project_ray_origin()` + `project_ray_normal()` + `PhysicsRayQueryParameters3D` |
| HUD layout | Manual pixel placement code | CanvasLayer + Label with anchor presets (match existing hud.tscn pattern) |
| Cursor shape change | Custom cursor texture | `DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)` |

---

## Common Pitfalls

### Pitfall 1: Camera Not Restoring on Exit
**What goes wrong:** Player perspective stays overhead after pressing Tab to exit.
**Why it happens:** When editor camera `current` is set to false, Godot picks the next available camera, not necessarily the play camera.
**How to avoid:** Store a reference to `player_camera` in EditorController and call `player_camera.current = true` explicitly in `exit_editor_mode()`.
**Warning signs:** Viewport stays overhead after toggle.

### Pitfall 2: Player Input Still Active in Editor
**What goes wrong:** Player rotates with mouse while in editor mode.
**Why it happens:** `set_physics_process(false)` does not stop `_input()`. Mouse motion events still reach `player.gd`.
**How to avoid:** Call `set_process_input(false)` in `_on_editor_mode_changed(true)`.
**Warning signs:** Camera spins when mouse is moved in editor mode.

### Pitfall 3: Tab Consumed by Godot UI
**What goes wrong:** Tab does not fire as game input because Godot's UI system consumes it.
**Why it happens:** Tab is a UI navigation key. If any Control node has focus, Godot's UI layer consumes it before the game input system sees it.
**How to avoid:** Either (a) use `_unhandled_input` for the Tab toggle rather than `_input`, or (b) ensure no Control node retains focus. Adding the action via `InputEventKey` with `physical_keycode=KEY_TAB` to project.godot and reading via `_unhandled_input` is the reliable path.
**Warning signs:** Tab does nothing at game launch, or sometimes works and sometimes doesn't depending on whether a Label was clicked.

### Pitfall 4: WASD Pan Direction Doesn't Match Camera Orientation
**What goes wrong:** Pressing W pans in world +Z regardless of camera yaw.
**Why it happens:** Pan is computed in world space without considering camera orientation.
**How to avoid:** After adding orbit controls (Shift+drag), pan must be relative to camera's horizontal facing. Compute pan in camera's local XZ plane:
```gdscript
var cam_basis = editor_camera.global_transform.basis
var right   = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
var forward = Vector3(-cam_basis.z.x, 0, -cam_basis.z.z).normalized()
```
**Warning signs:** Pan direction is always cardinal even after orbiting.

### Pitfall 5: Zoom by Moving Camera vs Changing FOV
**What goes wrong:** Using `camera.fov` for zoom produces perspective distortion at close range; using only altitude fails for isometric feel.
**How to avoid:** Use altitude (move camera Y position) for zoom. Keep FOV fixed at ~45°–60°. This phase establishes camera; zoom limits refined later. [ASSUMED — based on typical isometric editor pattern]
**Warning signs:** Buildings appear to lean/skew as you zoom in (FOV zoom artifact).

### Pitfall 6: Player Marker Visible in Play Mode
**What goes wrong:** Orange capsule marker visible during normal gameplay.
**Why it happens:** `visible` not reset on exit.
**How to avoid:** Set `player_marker.visible = false` in `exit_editor_mode()`.

---

## Code Examples

### EditorController Skeleton
```gdscript
# editor_controller.gd
extends Node3D

signal editor_mode_changed(active: bool)

var is_editor_active: bool = false
var player_ref: Node3D = null
var play_camera: Camera3D = null
var editor_camera: Camera3D = null
var player_marker: MeshInstance3D = null
var editor_hud_instance: Node = null

@export var editor_hud_scene: PackedScene

# Camera orbit state
var _focus_point: Vector3 = Vector3.ZERO
var _camera_altitude: float = 150.0
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = -1.0  # ~60 degrees down
var _zoom_step: int = 5          # Index into altitude steps

const ALTITUDE_STEPS = [30.0, 60.0, 100.0, 150.0, 250.0, 400.0, 700.0, 1200.0]
const BASE_PAN_SPEED = 50.0
const ORBIT_SENSITIVITY = 0.005
const PAN_MOUSE_SENSITIVITY = 0.3

func _ready():
    # Find player and play camera
    player_ref = get_node_or_null("../Player")
    if player_ref:
        play_camera = player_ref.get_node_or_null("Head/Camera3D")

    # Create editor camera
    editor_camera = Camera3D.new()
    editor_camera.fov = 50.0
    add_child(editor_camera)

    _create_player_marker()

func _unhandled_input(event):
    if event.is_action_pressed("toggle_editor"):
        _toggle()

func _toggle():
    if is_editor_active:
        exit_editor_mode()
    else:
        enter_editor_mode()

func enter_editor_mode():
    is_editor_active = true
    _focus_point = player_ref.global_position if player_ref else Vector3.ZERO
    _update_camera_transform()
    editor_camera.current = true
    player_marker.visible = true
    _show_editor_hud()
    emit_signal("editor_mode_changed", true)

func exit_editor_mode():
    is_editor_active = false
    editor_camera.current = false
    if play_camera:
        play_camera.current = true
    player_marker.visible = false
    _hide_editor_hud()
    emit_signal("editor_mode_changed", false)

func _process(delta):
    if not is_editor_active:
        return
    _handle_keyboard_pan(delta)
    _update_camera_transform()
    _update_hud()
    if player_ref:
        player_marker.global_position = player_ref.global_position

func _update_camera_transform():
    var offset = Vector3(
        sin(_orbit_yaw) * cos(_orbit_pitch),
        -sin(_orbit_pitch),
        cos(_orbit_yaw) * cos(_orbit_pitch)
    ).normalized() * _camera_altitude
    editor_camera.global_position = _focus_point + offset
    editor_camera.look_at(_focus_point, Vector3.UP)
```

### Player Connection (player.gd additions)
```gdscript
# In _ready(), after existing code:
var ec = get_node_or_null("/root/World/EditorController")
if ec:
    ec.editor_mode_changed.connect(_on_editor_mode_changed)

func _on_editor_mode_changed(active: bool):
    set_physics_process(!active)
    set_process_input(!active)
    if active:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        if hud_instance:
            var ch = hud_instance.get_node_or_null("Crosshair")
            if ch: ch.visible = false
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        if hud_instance:
            var ch = hud_instance.get_node_or_null("Crosshair")
            if ch: ch.visible = true
```

### project.godot Input Action (add to [input] section)
```
toggle_editor={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```
Note: `physical_keycode` for Tab is `KEY_TAB = 4194305` in Godot 4. [ASSUMED — verify against Godot 4 key constant table. The pattern itself is verified from project.godot.]

---

## Environment Availability

Step 2.6: SKIPPED — This phase is purely GDScript code changes. No external tools, CLIs, databases, or runtimes beyond Godot itself (already running in the dev pipeline).

---

## Validation Architecture

No formal test framework is present in this project [VERIFIED: no pytest.ini, jest.config, or test/ directories found]. Testing is manual UAT.

### Phase UAT Checklist

| Behavior | How to Verify |
|----------|---------------|
| Tab enters editor mode | Press Tab → player freezes, cursor appears, overhead camera activates |
| Tab exits editor mode | Press Tab again → play camera restores, cursor captured, movement works |
| Player marker visible | Orange capsule visible at player position in editor view |
| WASD pans camera | W/S/A/D moves the camera's focus point across terrain |
| Q/E changes altitude | Q raises camera, E lowers camera |
| 1/2 zooms in/out | Camera moves closer/farther from focus point |
| Shift+drag orbits | Hold Shift + left-drag → camera rotates around focus |
| Ctrl+drag pans | Hold Ctrl + left-drag → camera pans in screen plane |
| Crosshair hidden | Crosshair not visible while in editor mode |
| Editor HUD shows | Top-left label shows cursor world XZ and zoom level |
| HUD updates on move | Moving mouse updates cursor world position label |
| No ghost input | Moving mouse in editor does NOT rotate the player view |
| Return to play works | After editor, can walk/fly/shoot normally |

---

## Project Constraints (from CLAUDE.md)

- **Always commit after making code changes.** Short imperative commit message, no body.
- Dev pipeline: Codespaces edit → git push → PowerShell watcher on laptop auto-pulls and relaunches Godot.
- Changes are not testable until committed and pushed.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)` is the correct API for Ctrl hand cursor | Don'ts + Pattern 6 | Cursor shape does not change; cosmetic only, low impact |
| A2 | Tab physical_keycode is 4194305 (KEY_TAB) in Godot 4 | Code Examples | toggle_editor action doesn't fire; fix by checking correct constant |
| A3 | Using altitude (camera Y) rather than FOV for zoom is correct for isometric feel | Pitfall 5 | Zoom feels wrong; easy to adjust |

---

## Open Questions

1. **Terrain chunk collision — RESOLVED**
   - Verified [VERIFIED: terrain_chunk.gd line 18]: `has_collision: bool = true` for LOD 0 and LOD 1 chunks. `StaticBody3D` is built programmatically. Raycast cursor will work against nearby terrain. At extreme zoom-out (LOD 2+, no collision), the raycast may miss — acceptable for Phase 1 since far-out editing is Phase 2+.

2. **Renderer compatibility for emissive marker material**
   - What we know: project.godot uses `gl_compatibility` renderer [VERIFIED: project.godot line 113].
   - What's unclear: Emissive materials with high energy values may not bloom/glow in GL Compatibility mode (no post-processing).
   - Recommendation: Use a bright solid color without emission energy reliance. Just `albedo_color = Color(1.0, 0.4, 0.0)` is sufficient visibility — emission energy fallback not needed. Adjust in discretion.

---

## Sources

### Primary (HIGH confidence)
- `/workspaces/possession/game/player.gd` — all player patterns, mode flags, mouse mode, HUD instantiation
- `/workspaces/possession/game/world.tscn` — scene tree structure, camera locations, TerrainManager placement
- `/workspaces/possession/game/hud.tscn` — HUD CanvasLayer structure with CoordsLabel, SpeedLabel, Crosshair
- `/workspaces/possession/game/project.godot` — input action bindings, renderer, no autoload section
- `/workspaces/possession/game/terrain_manager.gd` — autoload pattern (none; plain Node3D), initialization
- `/workspaces/possession/game/terrain_chunk.gd` — collision presence verified (StaticBody3D, LOD 0-1 only)

### Tertiary (LOW confidence — Assumed)
- Godot 4 `Camera3D.current` API behavior for camera switching
- `DisplayServer.cursor_set_shape` for cursor icon
- Tab key physical_keycode value
- Emissive material behavior in GL Compatibility renderer

---

## Metadata

**Confidence breakdown:**
- Architecture/integration: HIGH — derived directly from reading codebase
- Godot 4 APIs (Camera3D.current, PhysicsRayQuery, signal patterns): MEDIUM-HIGH — well-established Godot patterns consistent with existing code
- Specific constant values (KEY_TAB int value): LOW — flagged as assumption

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable domain — Godot 4.x APIs, no fast-moving dependencies)
