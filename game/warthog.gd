extends CharacterBody3D
class_name Warthog

# Driveable vehicle.  Press E to enter/exit driver seat.
# A gunner NPC sits in the back and auto-fires at the nearest enemy.

@export var faction: int = 0
@export var max_speed: float = 22.0
@export var acceleration: float = 14.0
@export var brake_force: float = 20.0
@export var turn_speed: float = 2.2
@export var gunner_damage: float = 12.0
@export var gunner_fire_interval: float = 0.9
@export var gunner_range: float = 60.0

# Faction tint colours matching soldier markers
const FACTION_COLORS: Array = [Color(1.0, 0.15, 0.15), Color(0.7, 0.1, 1.0)]
const ENTER_RADIUS: float = 5.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player: Node3D = null
var _occupied: bool = false          # player is driving
var _player_saved_pos: Vector3
var _gunner_timer: float = 0.0
var _shoot_sound: AudioStreamPlayer3D = null
var _prompt_label: Label3D = null

func _ready():
	add_to_group("warthog")
	_build_mesh()
	_build_prompt_label()
	_setup_audio()
	call_deferred("_find_player")

# ── Build visuals ─────────────────────────────────────────────────────────────

func _build_mesh():
	# Collision capsule
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.2, 4.8)
	col.shape = shape
	col.position = Vector3(0, 0.6, 0)
	add_child(col)

	# Body mesh
	var body_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.8, 4.8)
	body_mesh.mesh = box
	body_mesh.position = Vector3(0, 0.7, 0)
	var mat := StandardMaterial3D.new()
	var col_faction: Color = FACTION_COLORS[clamp(faction, 0, 1)]
	mat.albedo_color = col_faction.lerp(Color(0.5, 0.5, 0.5), 0.7)
	body_mesh.material_override = mat
	add_child(body_mesh)

	# Cab
	var cab_mesh := MeshInstance3D.new()
	var cab_box := BoxMesh.new()
	cab_box.size = Vector3(2.0, 0.7, 1.8)
	cab_mesh.mesh = cab_box
	cab_mesh.position = Vector3(0, 1.45, 0.5)
	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = Color(0.3, 0.3, 0.3)
	cab_mesh.material_override = cab_mat
	add_child(cab_mesh)

	# Turret ring at rear
	var turret_mesh := MeshInstance3D.new()
	var turret_box := BoxMesh.new()
	turret_box.size = Vector3(0.5, 0.5, 0.5)
	turret_mesh.mesh = turret_box
	turret_mesh.position = Vector3(0, 1.45, -1.6)
	var turret_mat := StandardMaterial3D.new()
	turret_mat.albedo_color = col_faction
	turret_mat.emission_enabled = true
	turret_mat.emission = col_faction
	turret_mat.emission_energy_multiplier = 2.0
	turret_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	turret_mesh.material_override = turret_mat
	add_child(turret_mesh)

func _build_prompt_label():
	_prompt_label = Label3D.new()
	_prompt_label.text = "[E] Enter"
	_prompt_label.position = Vector3(0, 2.2, 0)
	_prompt_label.pixel_size = 0.01
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.modulate = Color(1, 1, 0.4)
	add_child(_prompt_label)

func _setup_audio():
	_shoot_sound = AudioStreamPlayer3D.new()
	var stream = load("res://plasma_rifle.mp3")
	if stream:
		_shoot_sound.stream = stream
	_shoot_sound.max_distance = 80.0
	_shoot_sound.volume_db = 2.0
	add_child(_shoot_sound)

func _find_player():
	_player = get_node_or_null("/root/World/Player")
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

# ── Input / driving ───────────────────────────────────────────────────────────

func _input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if _occupied:
			_exit_vehicle()
		elif _player and (global_position - _player.global_position).length() < ENTER_RADIUS:
			_enter_vehicle()

func _physics_process(delta: float):
	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	# Show prompt when player is nearby and not driving
	if _prompt_label:
		var near = _player and (global_position - _player.global_position).length() < ENTER_RADIUS
		_prompt_label.visible = near and not _occupied

	if _occupied:
		_drive(delta)
	else:
		# Friction when unoccupied
		velocity.x = move_toward(velocity.x, 0.0, brake_force * delta)
		velocity.z = move_toward(velocity.z, 0.0, brake_force * delta)

	move_and_slide()

	# Gunner fires regardless of whether player is driving
	_tick_gunner(delta)

func _drive(delta: float):
	var fwd_input := Input.get_axis("move_back", "move_forward")
	var turn_input := Input.get_axis("move_right", "move_left")

	# Steering — only when moving
	if abs(fwd_input) > 0.05:
		rotation.y += turn_input * turn_speed * delta * sign(fwd_input)

	var forward := -global_transform.basis.z
	var target_speed := fwd_input * max_speed
	var current_speed := Vector3(velocity.x, 0, velocity.z).dot(forward)
	var new_speed := move_toward(current_speed, target_speed, acceleration * delta)

	velocity.x = forward.x * new_speed
	velocity.z = forward.z * new_speed

	# Sync player camera to vehicle
	if _player:
		_player.global_position = global_position + Vector3(0, 1.1, 0)
		_player.rotation.y = rotation.y

func _enter_vehicle():
	_occupied = true
	_player_saved_pos = _player.global_position
	if _player.has_method("set_physics_process"):
		_player.set_physics_process(false)
	var pcol := _player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if pcol:
		pcol.disabled = true
	if _player.has_node("Head"):
		_player.get_node("Head").rotation.x = 0.0
	print("Warthog: player entered")

func _exit_vehicle():
	_occupied = false
	if _player:
		_player.global_position = global_position + global_transform.basis.x * 3.0 + Vector3.UP * 1.2
		var pcol := _player.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if pcol:
			pcol.disabled = false
		if _player.has_method("set_physics_process"):
			_player.set_physics_process(true)
	print("Warthog: player exited")

# ── Gunner AI ─────────────────────────────────────────────────────────────────

func _tick_gunner(delta: float):
	_gunner_timer -= delta
	if _gunner_timer > 0.0:
		return
	_gunner_timer = gunner_fire_interval

	# Find nearest enemy of the opposing faction
	var opp_group := "faction_1" if faction == 0 else "faction_0"
	var best_dist := gunner_range
	var best_target: Node3D = null
	for node in get_tree().get_nodes_in_group(opp_group):
		if not is_instance_valid(node):
			continue
		var d: float = ((node as Node3D).global_position - global_position).length()
		if d < best_dist:
			best_dist = d
			best_target = node

	if not best_target:
		return

	# LOS check
	var from := global_position + Vector3.UP * 1.4
	var to := best_target.global_position + Vector3.UP * 1.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or hit.collider == best_target:
		if best_target.has_method("take_damage"):
			best_target.take_damage(gunner_damage)
		if _shoot_sound:
			_shoot_sound.pitch_scale = randf_range(0.9, 1.1)
			_shoot_sound.play()
