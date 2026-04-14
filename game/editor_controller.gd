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
const BRUSH_RADIUS_MIN: float = 5.0
const BRUSH_RADIUS_MAX: float = 120.0
const BRUSH_RADIUS_STEP: float = 2.0
const BRUSH_STRENGTH_PER_SEC: float = 30.0
const BRUSH_BOOST_MULT: float = 2.0

@export var editor_hud_scene: PackedScene = preload("res://editor_hud.tscn")

var is_editor_active: bool = false
var player_ref: Node3D = null
var play_camera: Camera3D = null
var editor_camera: Camera3D = null
var player_marker: MeshInstance3D = null
var _brush_cursor: MeshInstance3D = null
var editor_hud_instance: CanvasLayer = null
var _info_label: Label = null

var _focus_point: Vector3 = Vector3.ZERO
var _camera_altitude: float = 150.0
var _zoom_step: int = 3
var _zoom_cooldown: float = 0.0
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = -1.0

var brush_radius: float = 15.0
var brush_falloff: int = 0  # 0=Gaussian 1=Linear 2=Hard — matches TerrainManager.BrushFalloff
var terrain_manager: Node = null
var _frame_dirty: Dictionary = {}  # Vector2i -> true, deduped across one frame

func _ready() -> void:
	player_ref = get_node_or_null("../Player")
	if player_ref:
		play_camera = player_ref.get_node_or_null("Head/Camera3D")
	editor_camera = Camera3D.new()
	editor_camera.fov = 50.0
	add_child(editor_camera)
	_create_player_marker()
	_create_brush_cursor()
	call_deferred("_spawn_editor_hud")
	terrain_manager = get_node_or_null("../TerrainManager")

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

func _create_brush_cursor() -> void:
	_brush_cursor = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 8
	_brush_cursor.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.0, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 1
	_brush_cursor.material_override = mat
	add_child(_brush_cursor)
	_brush_cursor.visible = false

func _update_brush_cursor() -> void:
	if _brush_cursor == null:
		return
	if not is_editor_active:
		_brush_cursor.visible = false
		return
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		_brush_cursor.visible = false
		return
	var pos_v = _get_terrain_cursor_world_pos()
	if pos_v == null:
		_brush_cursor.visible = false
		return
	var pos: Vector3 = pos_v
	_brush_cursor.visible = true
	_brush_cursor.global_position = Vector3(pos.x, pos.y + 0.5, pos.z)
	_brush_cursor.scale = Vector3(brush_radius, 1.0, brush_radius)

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek := event as InputEventKey
		if ek.physical_keycode == KEY_F3 and ek.pressed and not ek.echo:
			get_viewport().set_input_as_handled()
			_toggle()
			return
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
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				brush_radius = clamp(brush_radius + BRUSH_RADIUS_STEP, BRUSH_RADIUS_MIN, BRUSH_RADIUS_MAX)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				brush_radius = clamp(brush_radius - BRUSH_RADIUS_STEP, BRUSH_RADIUS_MIN, BRUSH_RADIUS_MAX)
				get_viewport().set_input_as_handled()
	if event is InputEventKey:
		var ek2 := event as InputEventKey
		if ek2.physical_keycode == KEY_F and ek2.pressed and not ek2.echo:
			brush_falloff = (brush_falloff + 1) % 3
			get_viewport().set_input_as_handled()

func _toggle() -> void:
	if is_editor_active:
		exit_editor_mode()
	else:
		enter_editor_mode()

func enter_editor_mode() -> void:
	is_editor_active = true
	if player_ref:
		var p := player_ref.global_position
		_focus_point = Vector3(p.x, p.y - 1.5, p.z)
	else:
		_focus_point = Vector3.ZERO
	# Reset camera to a usable overhead angle each time editor is entered
	_orbit_yaw = 0.0
	_orbit_pitch = -1.2
	_zoom_step = 3
	_camera_altitude = ALTITUDE_STEPS[_zoom_step]
	_update_camera_transform()
	editor_camera.current = true
	if player_marker:
		player_marker.visible = true
	if editor_hud_instance:
		editor_hud_instance.visible = true
	# Hide player HUD while editing
	var player_hud := _get_player_hud()
	if player_hud:
		player_hud.visible = false
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
	# Restore player HUD
	var player_hud := _get_player_hud()
	if player_hud:
		player_hud.visible = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _brush_cursor:
		_brush_cursor.visible = false
	emit_signal("editor_mode_changed", false)

func _get_player_hud() -> Node:
	if player_ref == null:
		return null
	# player.gd stores hud_instance as a property
	if player_ref.get("hud_instance") != null:
		return player_ref.hud_instance
	return null

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
	var pos: Variant = _get_terrain_cursor_world_pos()
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
	_tick_brush(delta)
	_flush_dirty_chunks()
	_update_brush_cursor()

func _tick_brush(delta: float) -> void:
	if not is_editor_active:
		return
	if terrain_manager == null:
		return
	# Skip brush while camera-drag modifiers are held (LMB is used for orbit/pan)
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		return
	var lmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not lmb and not rmb:
		return
	var pos_v = _get_terrain_cursor_world_pos()
	if pos_v == null:
		return
	var world_pos: Vector3 = pos_v
	var direction: float = 1.0 if lmb else -1.0
	var boost: float = BRUSH_BOOST_MULT if Input.is_key_pressed(KEY_R) else 1.0
	var strength: float = direction * BRUSH_STRENGTH_PER_SEC * boost * delta
	var dirty: Array = terrain_manager.apply_height_brush(world_pos, brush_radius, strength, brush_falloff)
	if dirty.size() > 0:
		_rebuild_dirty_chunks(dirty)

func _rebuild_dirty_chunks(dirty: Array) -> void:
	for c in dirty:
		_frame_dirty[c] = true

func _flush_dirty_chunks() -> void:
	if _frame_dirty.is_empty() or terrain_manager == null:
		return
	# Only rebuild chunks that were actually painted — rebuilding unmodified
	# neighbors from unchanged height_offsets creates seams with THEIR other
	# neighbors that are outside the rebuild set.
	var rebuilt: Array = []
	for coord in _frame_dirty.keys():
		if not terrain_manager.chunks.has(coord):
			continue
		var chunk = terrain_manager.chunks[coord]
		if chunk and chunk.has_method("rebuild_mesh"):
			chunk.rebuild_mesh()
			rebuilt.append("%s(LOD%d)" % [coord, chunk.current_lod])
	_frame_dirty.clear()
	_frame_dirty.clear()

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
