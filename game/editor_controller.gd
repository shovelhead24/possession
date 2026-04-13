extends Node3D

signal editor_mode_changed(active: bool)

const ALTITUDE_STEPS: Array = [30.0, 60.0, 100.0, 150.0, 250.0, 400.0, 700.0, 1200.0]
const BASE_PAN_SPEED: float = 50.0
const ALTITUDE_SPEED: float = 60.0
const ZOOM_DEBOUNCE_SEC: float = 0.15
const ORBIT_SENSITIVITY: float = 0.005
const PAN_MOUSE_SENSITIVITY: float = 0.3
const PITCH_MIN: float = -1.5
const PITCH_MAX: float = -0.1

@export var editor_hud_scene: PackedScene = preload("res://editor_hud.tscn")

var is_editor_active: bool = false
var player_ref: Node3D = null
var play_camera: Camera3D = null
var editor_camera: Camera3D = null
var player_marker: MeshInstance3D = null
var editor_hud_instance: CanvasLayer = null
var _info_label: Label = null

var _focus_point: Vector3 = Vector3.ZERO
var _camera_altitude: float = 150.0
var _zoom_step: int = 3
var _zoom_cooldown: float = 0.0
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = -1.0

func _ready() -> void:
	player_ref = get_node_or_null("../Player")
	if player_ref:
		play_camera = player_ref.get_node_or_null("Head/Camera3D")
	editor_camera = Camera3D.new()
	editor_camera.fov = 50.0
	add_child(editor_camera)
	_create_player_marker()
	call_deferred("_spawn_editor_hud")

func _spawn_editor_hud() -> void:
	if editor_hud_scene == null:
		return
	editor_hud_instance = editor_hud_scene.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(editor_hud_instance)
	editor_hud_instance.visible = false
	_info_label = editor_hud_instance.get_node_or_null("InfoLabel") as Label

func _create_player_marker() -> void:
	player_marker = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.6
	mesh.height = 2.2
	player_marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	player_marker.material_override = mat
	add_child(player_marker)
	player_marker.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_editor"):
		_toggle()

func _input(event: InputEvent) -> void:
	if not is_editor_active:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if Input.is_key_pressed(KEY_SHIFT):
				_orbit_yaw += mm.relative.x * ORBIT_SENSITIVITY
				_orbit_pitch = clamp(_orbit_pitch + mm.relative.y * ORBIT_SENSITIVITY, PITCH_MIN, PITCH_MAX)
			elif Input.is_key_pressed(KEY_CTRL):
				var cam_basis := editor_camera.global_transform.basis
				var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
				var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
				var pan_scale: float = PAN_MOUSE_SENSITIVITY * (_camera_altitude / 100.0)
				_focus_point -= right * mm.relative.x * pan_scale
				_focus_point += forward * mm.relative.y * pan_scale
	elif event is InputEventKey:
		var ek := event as InputEventKey
		if ek.keycode == KEY_CTRL:
			if ek.pressed:
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _toggle() -> void:
	if is_editor_active:
		exit_editor_mode()
	else:
		enter_editor_mode()

func enter_editor_mode() -> void:
	is_editor_active = true
	if player_ref:
		_focus_point = player_ref.global_position
	else:
		_focus_point = Vector3.ZERO
	_update_camera_transform()
	editor_camera.current = true
	if player_marker:
		player_marker.visible = true
	if editor_hud_instance:
		editor_hud_instance.visible = true
	emit_signal("editor_mode_changed", true)

func exit_editor_mode() -> void:
	is_editor_active = false
	editor_camera.current = false
	if play_camera:
		play_camera.current = true
	if player_marker:
		player_marker.visible = false
	if editor_hud_instance:
		editor_hud_instance.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	emit_signal("editor_mode_changed", false)

func _get_terrain_cursor_world_pos() -> Variant:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var mouse_pos := viewport.get_mouse_position()
	var ray_origin := editor_camera.project_ray_origin(mouse_pos)
	var ray_dir := editor_camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_dir * 10000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result["position"]

func _update_hud() -> void:
	if _info_label == null:
		return
	var pos := _get_terrain_cursor_world_pos()
	if pos == null:
		_info_label.text = "X: --  Z: --  Zoom: %d" % _zoom_step
	else:
		var p: Vector3 = pos
		_info_label.text = "X: %d  Z: %d  Zoom: %d" % [int(p.x), int(p.z), _zoom_step]

func _update_camera_transform() -> void:
	var offset := Vector3(
		sin(_orbit_yaw) * cos(_orbit_pitch),
		-sin(_orbit_pitch),
		cos(_orbit_yaw) * cos(_orbit_pitch)
	).normalized() * _camera_altitude
	editor_camera.global_position = _focus_point + offset
	editor_camera.look_at(_focus_point, Vector3.UP)

func _process(delta: float) -> void:
	if not is_editor_active:
		return
	if _zoom_cooldown > 0.0:
		_zoom_cooldown -= delta
	_handle_keyboard(delta)
	_update_camera_transform()
	_update_hud()
	if player_ref and player_marker:
		player_marker.global_position = player_ref.global_position

func _handle_keyboard(delta: float) -> void:
	var pan_speed: float = BASE_PAN_SPEED * (_camera_altitude / 100.0)
	var cam_basis := editor_camera.global_transform.basis
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()

	if Input.is_key_pressed(KEY_W):
		_focus_point += forward * pan_speed * delta
	if Input.is_key_pressed(KEY_S):
		_focus_point -= forward * pan_speed * delta
	if Input.is_key_pressed(KEY_A):
		_focus_point -= right * pan_speed * delta
	if Input.is_key_pressed(KEY_D):
		_focus_point += right * pan_speed * delta

	if Input.is_key_pressed(KEY_Q):
		_camera_altitude = min(_camera_altitude + ALTITUDE_SPEED * delta, ALTITUDE_STEPS[ALTITUDE_STEPS.size() - 1])
	if Input.is_key_pressed(KEY_E):
		_camera_altitude = max(_camera_altitude - ALTITUDE_SPEED * delta, ALTITUDE_STEPS[0])

	if _zoom_cooldown <= 0.0:
		if Input.is_key_pressed(KEY_1):
			_zoom_step = max(_zoom_step - 1, 0)
			_camera_altitude = ALTITUDE_STEPS[_zoom_step]
			_zoom_cooldown = ZOOM_DEBOUNCE_SEC
		elif Input.is_key_pressed(KEY_2):
			_zoom_step = min(_zoom_step + 1, ALTITUDE_STEPS.size() - 1)
			_camera_altitude = ALTITUDE_STEPS[_zoom_step]
			_zoom_cooldown = ZOOM_DEBOUNCE_SEC
