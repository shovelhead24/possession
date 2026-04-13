extends Node3D

signal editor_mode_changed(active: bool)

var is_editor_active: bool = false
var player_ref: Node3D = null
var play_camera: Camera3D = null
var editor_camera: Camera3D = null

# Camera state (1.2 will populate orbit/pan/zoom logic; 1.1 just places it overhead)
var _focus_point: Vector3 = Vector3.ZERO
var _camera_altitude: float = 150.0

func _ready() -> void:
	player_ref = get_node_or_null("../Player")
	if player_ref:
		play_camera = player_ref.get_node_or_null("Head/Camera3D")
	editor_camera = Camera3D.new()
	editor_camera.fov = 50.0
	add_child(editor_camera)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_editor"):
		_toggle()

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
	editor_camera.global_position = _focus_point + Vector3(0, _camera_altitude, 0)
	editor_camera.look_at(_focus_point, Vector3(0, 0, -1))
	editor_camera.current = true
	emit_signal("editor_mode_changed", true)

func exit_editor_mode() -> void:
	is_editor_active = false
	editor_camera.current = false
	if play_camera:
		play_camera.current = true
	emit_signal("editor_mode_changed", false)
