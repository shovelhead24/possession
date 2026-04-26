extends Node3D
class_name ObjectiveManager

@export var objective_x: float = 3000.0   # metres downring (positive X)
@export var reach_radius: float = 35.0    # trigger distance

var _player: Node3D = null
var _beacon: MeshInstance3D = null
var _hud_label: Label = null
var _active: bool = true
var _start_time: float = 0.0
var _hud_ready: bool = false

func _ready():
	_start_time = Time.get_ticks_msec() / 1000.0
	_find_player()
	call_deferred("_deferred_init")

func _deferred_init():
	_spawn_beacon()
	# HUD setup deferred further — player adds hud with call_deferred too
	await get_tree().process_frame
	await get_tree().process_frame
	_setup_hud()

func _find_player():
	_player = get_node_or_null("/root/World/Player")
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

func _spawn_beacon():
	var tm = get_node_or_null("/root/World/TerrainManager")
	var obj_y = 55.0
	if tm and tm.has_method("get_height_at_position"):
		obj_y = tm.get_height_at_position(Vector3(objective_x, 0.0, 0.0))
	global_position = Vector3(objective_x, obj_y, 0.0)

	# Glowing vertical pillar visible from distance
	var cyl = CylinderMesh.new()
	cyl.height = 300.0
	cyl.top_radius = 4.0
	cyl.bottom_radius = 4.0
	cyl.radial_segments = 8

	_beacon = MeshInstance3D.new()
	_beacon.mesh = cyl
	_beacon.position.y = 150.0
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 1.0, 0.3, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 1.0, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon.material_override = mat
	add_child(_beacon)

	# Bright point light at base of beacon
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.4)
	light.light_energy = 4.0
	light.omni_range = 80.0
	add_child(light)

	print("ObjectiveManager: beacon placed at X=%.0f Y=%.0f" % [objective_x, obj_y])

func _setup_hud():
	if not _player:
		_find_player()
	if not _player or not "hud_instance" in _player:
		return
	var hud = _player.hud_instance
	if not hud:
		return

	_hud_label = Label.new()
	_hud_label.name = "ObjectiveLabel"
	_hud_label.add_theme_font_size_override("font_size", 22)
	_hud_label.add_theme_color_override("font_color", Color(0.15, 1.0, 0.35))
	_hud_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_label.offset_left  = -260
	_hud_label.offset_top   = 8
	_hud_label.offset_right = -12
	_hud_label.offset_bottom = 70
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(_hud_label)
	_hud_ready = true

func _process(delta):
	if not _active:
		return

	# Lazy HUD init if it wasn't ready in _deferred_init
	if not _hud_ready:
		_setup_hud()

	if _beacon:
		_beacon.rotate_y(delta * 0.4)

	if not _player:
		return

	var dist = _flat_dist()

	if _hud_label:
		var arrow = "▶▶" if _player.global_position.x < objective_x else "◀◀"
		_hud_label.text = "OBJECTIVE %s\n%.0f m" % [arrow, dist]

	if dist < reach_radius:
		_trigger_win()

func _flat_dist() -> float:
	if not _player:
		return 99999.0
	return Vector2(_player.global_position.x - objective_x,
				   _player.global_position.z).length()

func _trigger_win():
	_active = false
	var elapsed = Time.get_ticks_msec() / 1000.0 - _start_time
	var mins = int(elapsed / 60.0)
	var secs = fmod(elapsed, 60.0)

	if _hud_label:
		_hud_label.queue_free()

	if _player and "hud_instance" in _player and _player.hud_instance:
		var lbl = Label.new()
		lbl.text = "OBJECTIVE REACHED\n%d:%04.1f" % [mins, secs]
		lbl.add_theme_font_size_override("font_size", 56)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_color_override("font_color", Color(0.15, 1.0, 0.35))
		_player.hud_instance.add_child(lbl)

	print("ObjectiveManager: REACHED in %d:%04.1f" % [mins, secs])
	await get_tree().create_timer(5.0).timeout
	get_tree().reload_current_scene()
