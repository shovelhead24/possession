extends Node3D
class_name BattleBase

# Raised platform at a fixed position in the scene.
# Red (faction 0) soldiers attack it; purple (faction 1) soldiers defend it.

const EnemySoldierScene = preload("res://enemy_soldier.tscn")

@export var base_center: Vector3 = Vector3(70.0, 0.0, 0.0)
@export var platform_w: float = 18.0
@export var platform_d: float = 14.0
@export var platform_h: float = 3.5
@export var defender_count: int = 5
@export var attacker_count: int = 5

func _ready():
	_build_platform()
	_build_ramp()
	_build_crenelations()
	call_deferred("_spawn_combatants")

# ── Geometry ─────────────────────────────────────────────────────────────────

func _make_static_box(size: Vector3, pos: Vector3, color: Color, in_cover_group: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	if in_cover_group:
		body.add_to_group("cover")

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)
	body.global_position = pos
	return body

func _build_platform():
	var size := Vector3(platform_w, platform_h, platform_d)
	var pos := base_center + Vector3(0.0, platform_h * 0.5, 0.0)
	_make_static_box(size, pos, Color(0.55, 0.50, 0.45))

func _build_ramp():
	# A tilted box bridging ground to platform top on the front face (−X side).
	var ramp_len := platform_h * 2.5
	var ramp_body := StaticBody3D.new()

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(ramp_len, 0.3, 4.0)
	col.shape = shape
	ramp_body.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ramp_len, 0.3, 4.0)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.40, 0.35)
	mesh.material_override = mat
	ramp_body.add_child(mesh)

	# Pitch the ramp so it climbs from ground to platform_h
	var rise_angle := atan2(platform_h, ramp_len)
	ramp_body.rotation.z = rise_angle
	add_child(ramp_body)
	# Position: front face of platform, centred, midway up
	ramp_body.global_position = base_center + Vector3(
		-(platform_w * 0.5 + ramp_len * 0.5 * cos(rise_angle)),
		platform_h * 0.5,
		0.0
	)

func _build_crenelations():
	# Short battlements along three edges of the platform top (back + two sides).
	var top_y := base_center.y + platform_h
	var crenel_h := 1.2
	var crenel_w := 1.4
	var crenel_d := 0.6
	var gap := 2.2  # space between crenels
	var col := Color(0.50, 0.46, 0.40)

	# Back edge (+ X)
	var back_x := base_center.x + platform_w * 0.5 - crenel_d * 0.5
	var z := -platform_d * 0.5 + crenel_w * 0.5
	while z < platform_d * 0.5:
		_make_static_box(
			Vector3(crenel_d, crenel_h, crenel_w),
			Vector3(back_x, top_y + crenel_h * 0.5, base_center.z + z),
			col, true
		)
		z += crenel_w + gap

	# Left side (−Z)
	var left_z := base_center.z - platform_d * 0.5 + crenel_d * 0.5
	var x := base_center.x - platform_w * 0.5 + crenel_w * 0.5
	while x < base_center.x + platform_w * 0.5:
		_make_static_box(
			Vector3(crenel_w, crenel_h, crenel_d),
			Vector3(x, top_y + crenel_h * 0.5, left_z),
			col, true
		)
		x += crenel_w + gap

	# Right side (+Z)
	var right_z := base_center.z + platform_d * 0.5 - crenel_d * 0.5
	x = base_center.x - platform_w * 0.5 + crenel_w * 0.5
	while x < base_center.x + platform_w * 0.5:
		_make_static_box(
			Vector3(crenel_w, crenel_h, crenel_d),
			Vector3(x, top_y + crenel_h * 0.5, right_z),
			col, true
		)
		x += crenel_w + gap

# ── Combatants ────────────────────────────────────────────────────────────────

func _spawn_combatants():
	var top_y := base_center.y + platform_h + 0.1

	# Purple defenders spread across the platform top
	for i in range(defender_count):
		var angle := (i / float(defender_count)) * TAU
		var r := randf_range(1.0, platform_w * 0.3)
		var pos := Vector3(
			base_center.x + cos(angle) * r * 0.5,
			top_y,
			base_center.z + sin(angle) * r
		)
		var s := EnemySoldierScene.instantiate()
		s.faction = 1          # purple = defenders
		s.patrol_radius = 6.0  # stay near the base
		get_parent().add_child(s)
		s.global_position = pos

	# Red attackers approach from in front of the ramp
	for i in range(attacker_count):
		var spread_z := randf_range(-20.0, 20.0)
		var spread_x := randf_range(-15.0, -5.0)
		var pos := Vector3(
			base_center.x - platform_w * 0.5 + spread_x,
			1.0,
			base_center.z + spread_z
		)
		var s := EnemySoldierScene.instantiate()
		s.faction = 0          # red = attackers
		get_parent().add_child(s)
		s.global_position = pos
