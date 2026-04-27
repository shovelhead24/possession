extends CharacterBody3D
class_name EnemySoldier

enum State { PATROL, ALERT, CHASE, ATTACK, HIT, DEAD }

@export_group("Stats")
@export var health: float = 100.0
@export var attack_damage: float = 8.0
@export var attack_interval: float = 1.8
@export var attack_range: float = 35.0

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var run_speed: float = 7.0
@export var patrol_radius: float = 25.0

@export_group("Perception")
@export var sight_range: float = 80.0
@export var sight_fov_deg: float = 120.0
@export var hearing_range: float = 40.0

var state: State = State.PATROL
var _player: Node3D = null
var _spawn_pos: Vector3
var _patrol_target: Vector3
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _pre_hit_state: State = State.PATROL
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _settled: bool = false
var _anim_player: AnimationPlayer = null

func _ready():
	add_to_group("enemy")
	_spawn_pos = global_position
	_pick_patrol_target()
	call_deferred("_find_player")
	call_deferred("_attach_weapon")
	call_deferred("_setup_animations")
	set_physics_process(false)
	_settle_to_ground.call_deferred()

func _setup_animations():
	_anim_player = find_child("AnimationPlayer", true, false)
	if not _anim_player:
		return
	var clips := {
		"idle": "res://shooter animation/rifle aiming idle.fbx",
		"walk": "res://shooter animation/walking.fbx",
		"run":  "res://shooter animation/rifle run.fbx",
		"hit":  "res://shooter animation/hit reaction.fbx",
		"fire": "res://shooter animation/firing rifle.fbx",
	}
	for lib_name in clips:
		var lib = load(clips[lib_name])
		if lib and not _anim_player.has_animation_library(lib_name):
			_anim_player.add_animation_library(lib_name, lib)
	_play_anim("idle")

func _play_anim(lib_name: String):
	if not _anim_player:
		return
	# Mixamo names the clip "mixamo.com" inside each library
	for candidate in [lib_name + "/mixamo.com", lib_name + "/Take 001", lib_name]:
		if _anim_player.has_animation(candidate):
			if _anim_player.current_animation != candidate:
				_anim_player.play(candidate)
			return

func _attach_weapon():
	var skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		return
	# Try common Mixamo right-hand bone names
	var bone_idx = skeleton.find_bone("mixamorig:RightHand")
	if bone_idx < 0:
		bone_idx = skeleton.find_bone("RightHand")
	if bone_idx < 0:
		return
	var attach = BoneAttachment3D.new()
	attach.bone_name = skeleton.get_bone_name(bone_idx)
	skeleton.add_child(attach)
	# Placeholder rifle (box mesh) — swap for real weapon model later
	var gun = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.35)
	gun.mesh = box
	gun.position = Vector3(0.0, 0.0, -0.18)
	attach.add_child(gun)

func _settle_to_ground():
	# Retry until terrain physics mesh is ready under this soldier
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 5.0,
		global_position + Vector3.DOWN * 100.0
	)
	q.exclude = [self]
	var hit = space.intersect_ray(q)
	if hit:
		global_position = hit.position + Vector3.UP * 0.1
		_spawn_pos = global_position
		_settled = true
		set_physics_process(true)
	else:
		# Terrain not loaded yet — retry next frame
		await get_tree().process_frame
		_settle_to_ground()

func _find_player():
	_player = get_node_or_null("/root/World/Player")
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.PATROL:  _tick_patrol(delta)
		State.ALERT:   _tick_alert(delta)
		State.CHASE:   _tick_chase(delta)
		State.ATTACK:  _tick_attack(delta)
		State.HIT:     _tick_hit(delta)

	if state not in [State.DEAD, State.HIT]:
		_check_visibility()

	move_and_slide()

# ── State ticks ──────────────────────────────────────────────────────────────

func _tick_patrol(delta):
	var to_target = (_patrol_target - global_position) * Vector3(1, 0, 1)
	if to_target.length() < 2.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim("idle")
		_state_timer -= delta
		if _state_timer <= 0.0:
			_pick_patrol_target()
		return
	_play_anim("walk")
	_move_toward(to_target.normalized(), walk_speed, delta)

func _tick_alert(delta):
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim("idle")
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_patrol()

func _tick_chase(delta):
	if not _player:
		_enter_patrol()
		return
	var to_player = (_player.global_position - global_position) * Vector3(1, 0, 1)
	if to_player.length() <= attack_range:
		state = State.ATTACK
		_attack_timer = 0.5
		return
	_play_anim("run")
	_move_toward(to_player.normalized(), run_speed, delta)

func _tick_attack(delta):
	if not _player:
		_enter_patrol()
		return
	var to_player = (_player.global_position - global_position) * Vector3(1, 0, 1)
	if to_player.length() > attack_range * 1.25:
		state = State.CHASE
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_face_dir(to_player.normalized(), delta * 4.0)
	_play_anim("idle")
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_fire()
		_play_anim("fire")

func _tick_hit(delta):
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim("hit")
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = _pre_hit_state

# ── Perception ───────────────────────────────────────────────────────────────

func _check_visibility():
	if not _player:
		return
	var to_player = _player.global_position - global_position
	var dist = to_player.length()

	if dist > sight_range:
		if state in [State.CHASE, State.ATTACK]:
			_enter_alert()
		return

	# FOV check
	var forward = -global_transform.basis.z
	if rad_to_deg(forward.angle_to(to_player.normalized())) > sight_fov_deg * 0.5:
		return

	# LOS raycast
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.6,
		_player.global_position + Vector3.UP * 1.0
	)
	q.exclude = [self]
	var hit = space.intersect_ray(q)
	if hit.is_empty() or hit.collider == _player:
		_react_to_player()

func _react_to_player():
	if state in [State.PATROL, State.ALERT]:
		state = State.CHASE
		_alert_squad()
	elif state == State.CHASE:
		var dist = (_player.global_position - global_position).length()
		if dist <= attack_range:
			state = State.ATTACK
			_attack_timer = 0.5

# ── Combat ───────────────────────────────────────────────────────────────────

func _fire():
	if not _player:
		return
	var from = global_position + Vector3.UP * 1.6
	var to = _player.global_position + Vector3.UP * 1.0
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [self]
	var hit = space.intersect_ray(q)
	if hit and hit.collider == _player:
		if _player.has_method("take_damage"):
			_player.take_damage(attack_damage)

func take_damage(amount: float):
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		_die()
		return
	_pre_hit_state = state
	state = State.HIT
	_state_timer = 0.45

func _die():
	state = State.DEAD
	velocity = Vector3.ZERO
	get_tree().create_timer(3.0).timeout.connect(queue_free)

# ── Squad coordination ───────────────────────────────────────────────────────

func _alert_squad():
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == self:
			continue
		var dist = (node.global_position - global_position).length()
		if dist < 60.0 and node.has_method("alert_to_player"):
			node.alert_to_player(_player)

func alert_to_player(player: Node3D):
	if state in [State.DEAD, State.CHASE, State.ATTACK]:
		return
	_player = player
	state = State.CHASE

# ── Helpers ──────────────────────────────────────────────────────────────────

func _move_toward(dir: Vector3, speed: float, delta: float):
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_dir(dir, delta * 6.0)

func _face_dir(dir: Vector3, weight: float):
	if dir.length_squared() < 0.001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), weight)

func _enter_patrol():
	state = State.PATROL
	_pick_patrol_target()

func _enter_alert():
	state = State.ALERT
	_state_timer = 5.0

func _pick_patrol_target():
	var angle = randf() * TAU
	var r = randf_range(8.0, patrol_radius)
	_patrol_target = _spawn_pos + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
	_state_timer = randf_range(2.0, 4.0)
