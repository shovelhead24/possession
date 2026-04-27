extends CharacterBody3D
class_name EnemySoldier

enum State { PATROL, ALERT, CHASE, ATTACK, SEEK_COVER, HIT, DEAD }

@export_group("Stats")
@export var health: float = 100.0
@export var attack_damage: float = 8.0
@export var attack_interval: float = 1.8
@export var attack_range: float = 35.0
@export var shots_before_reload: int = 4

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var run_speed: float = 7.0
@export var patrol_radius: float = 25.0

@export_group("Perception")
@export var sight_range: float = 80.0
@export var sight_fov_deg: float = 120.0

var state: State = State.PATROL
var _player: Node3D = null
var _spawn_pos: Vector3
var _patrol_target: Vector3
var _cover_pos: Vector3
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _shot_count: int = 0
var _reloading: bool = false
var _pre_hit_state: State = State.PATROL
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
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

# ── Setup ─────────────────────────────────────────────────────────────────────

func _setup_animations():
	_anim_player = find_child("AnimationPlayer", true, false)
	if not _anim_player:
		return
	var clips := {
		"idle":     "res://shooter animation/rifle aiming idle.fbx",
		"walk":     "res://shooter animation/walking.fbx",
		"run":      "res://shooter animation/rifle run.fbx",
		"hit":      "res://shooter animation/hit reaction.fbx",
		"fire":     "res://shooter animation/firing rifle.fbx",
		"reload":   "res://shooter animation/reloading.fbx",
		"strafe_l": "res://shooter animation/strafe left.fbx",
		"strafe_r": "res://shooter animation/strafe right.fbx",
	}
	for lib_name in clips:
		var res = load(clips[lib_name])
		if res == null:
			continue
		if res is AnimationLibrary:
			if not _anim_player.has_animation_library(lib_name):
				_anim_player.add_animation_library(lib_name, res)
		else:
			var inst = res.instantiate()
			var src = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if src:
				for existing_lib in src.get_animation_library_list():
					var src_lib = src.get_animation_library(existing_lib)
					var dest_name = lib_name if existing_lib == "" else lib_name + "_" + existing_lib
					if not _anim_player.has_animation_library(dest_name):
						_anim_player.add_animation_library(dest_name, src_lib)
			inst.queue_free()
	_play_anim("idle")

func _play_anim(lib_name: String):
	if not _anim_player:
		return
	for candidate in [lib_name + "/mixamo_com", lib_name + "/mixamo.com",
					   lib_name + "/Take 001", lib_name]:
		if _anim_player.has_animation(candidate):
			if _anim_player.current_animation != candidate:
				_anim_player.play(candidate)
			return

func _attach_weapon():
	var skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		return
	var bone_idx = skeleton.find_bone("mixamorig_RightHand")
	if bone_idx < 0:
		bone_idx = skeleton.find_bone("mixamorig:RightHand")
	if bone_idx < 0:
		bone_idx = skeleton.find_bone("RightHand")
	if bone_idx < 0:
		return
	var attach = BoneAttachment3D.new()
	attach.bone_name = skeleton.get_bone_name(bone_idx)
	skeleton.add_child(attach)
	var carbine_scene = load("res://halo_-_carbine/scene.gltf")
	if carbine_scene:
		var carbine = carbine_scene.instantiate()
		carbine.scale = Vector3(0.03, 0.03, 0.03)
		carbine.position = Vector3(0.05, 0.02, -0.05)
		carbine.rotation_degrees = Vector3(-10, 90, 90)
		attach.add_child(carbine)

func _settle_to_ground():
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
		set_physics_process(true)
	else:
		await get_tree().process_frame
		_settle_to_ground()

func _find_player():
	_player = get_node_or_null("/root/World/Player")
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta):
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.PATROL:     _tick_patrol(delta)
		State.ALERT:      _tick_alert(delta)
		State.CHASE:      _tick_chase(delta)
		State.ATTACK:     _tick_attack(delta)
		State.SEEK_COVER: _tick_seek_cover(delta)
		State.HIT:        _tick_hit(delta)

	if state not in [State.DEAD, State.HIT]:
		_check_visibility()

	move_and_slide()

# ── State ticks ───────────────────────────────────────────────────────────────

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

	_face_dir(to_player.normalized(), delta * 4.0)

	if _reloading:
		_play_anim("reload")
		_state_timer -= delta
		if _state_timer <= 0.0:
			_reloading = false
			_shot_count = 0
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Strafe left/right slowly while attacking
	var strafe_dir = global_transform.basis.x * (1.0 if fmod(_state_timer, 4.0) < 2.0 else -1.0)
	velocity.x = strafe_dir.x * walk_speed * 0.5
	velocity.z = strafe_dir.z * walk_speed * 0.5
	_play_anim("strafe_l" if fmod(_state_timer, 4.0) < 2.0 else "strafe_r")

	_attack_timer -= delta
	_state_timer += delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_fire()
		_play_anim("fire")
		_shot_count += 1
		if _shot_count >= shots_before_reload:
			_reloading = true
			_state_timer = 2.2  # Reload duration

func _tick_seek_cover(delta):
	var to_cover = (_cover_pos - global_position) * Vector3(1, 0, 1)
	if to_cover.length() < 1.5:
		velocity.x = 0.0
		velocity.z = 0.0
		state = State.ATTACK
		_attack_timer = randf_range(0.8, 1.5)
		return
	_play_anim("run")
	_move_toward(to_cover.normalized(), run_speed * 1.2, delta)

func _tick_hit(delta):
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim("hit")
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = _pre_hit_state

# ── Perception ────────────────────────────────────────────────────────────────

func _check_visibility():
	if not _player:
		return
	var to_player = _player.global_position - global_position
	var dist = to_player.length()

	if dist > sight_range:
		if state in [State.CHASE, State.ATTACK]:
			_enter_alert()
		return

	var forward = -global_transform.basis.z
	if rad_to_deg(forward.angle_to(to_player.normalized())) > sight_fov_deg * 0.5:
		return

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
		if (_player.global_position - global_position).length() <= attack_range:
			state = State.ATTACK
			_attack_timer = 0.5

# ── Combat ────────────────────────────────────────────────────────────────────

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
	# 60% chance to break for cover when hit
	if randf() < 0.6 and state != State.SEEK_COVER:
		_seek_nearest_cover()

func _die():
	state = State.DEAD
	velocity = Vector3.ZERO
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _seek_nearest_cover():
	var best_dist = INF
	var best_pos = Vector3.ZERO
	var found = false
	for node in get_tree().get_nodes_in_group("cover"):
		var dist = (node.global_position - global_position).length()
		if dist < best_dist and dist < 60.0:
			var dir = Vector3.ZERO
			if _player:
				dir = (node.global_position - _player.global_position).normalized()
			best_dist = dist
			best_pos = node.global_position + dir * 1.8
			found = true
	if found:
		_cover_pos = best_pos
		_pre_hit_state = State.SEEK_COVER

# ── Squad coordination ────────────────────────────────────────────────────────

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

# ── Helpers ───────────────────────────────────────────────────────────────────

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
