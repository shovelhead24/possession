extends Node3D
const Damage = preload("res://damage.gd")
class_name Creature
# Generic startle/flee proxy — the wildlife.md primitive. One behavior, parameterized:
# deer (calm, flees far) and wolf (approaches, fast, night) are the same code, different presets.
# Silhouette-first crude proxy (aesthetic.md pillar): body + 4 legs + head, procedural gait.
# Terrain-agnostic: caller injects a `height_fn` (Callable: (x, z) -> y) and a `threat_fn`
# (Callable: () -> Vector3 threat position, or a sentinel for "no threat").

enum State { GRAZE, ALERT, FLEE, APPROACH }

# --- preset params (set via configure()) ---
var walk_speed := 3.0
var flee_speed := 14.0
var alert_radius := 45.0      # threat within this -> ALERT
var trigger_radius := 25.0    # threat within this -> FLEE/APPROACH
var calm_radius := 90.0       # threat beyond this -> back to GRAZE
var approaches := false       # false = deer (flees), true = wolf (closes in)
var body_color := Color(0.42, 0.34, 0.24)
var body_len := 1.6
var body_height := 1.1
var max_health := 40.0
var health := 40.0
var dead := false

var height_fn: Callable
var threat_fn: Callable

var _state: State = State.GRAZE
var _vel := Vector3.ZERO
var _heading := 0.0
var _gait := 0.0
var _graze_timer := 0.0
var _legs: Array[MeshInstance3D] = []
var _head: MeshInstance3D

# --- signals for the null-write acceptance test (simulation.md) ---
# GRAZE/ALERT/FLEE emit nothing to any threat channel by design; only a wolf in APPROACH
# is allowed to write an encounter/intensity signal. The slice's debug overlay asserts this.
signal became_threat(active: bool)
signal died

# Shared locational damage (game/damage.gd). Wildlife share the same head/torso/limb model
# as the player and soldiers; a hit also startles it into FLEE regardless of preset.
func take_damage(amount: float, zone: String = "") -> void:
	if dead:
		return
	health -= Damage.resolve(amount, zone)
	if _state != State.FLEE:
		_state = State.FLEE
	if health <= 0.0:
		dead = true
		died.emit()
		queue_free()

func configure(preset: String) -> void:
	match preset:
		"deer":
			walk_speed = 2.5; flee_speed = 15.0
			alert_radius = 50.0; trigger_radius = 28.0; calm_radius = 100.0
			approaches = false
			body_color = Color(0.45, 0.33, 0.22); body_len = 1.5; body_height = 1.1
		"wolf":
			walk_speed = 4.0; flee_speed = 17.0
			alert_radius = 70.0; trigger_radius = 55.0; calm_radius = 140.0
			approaches = true
			body_color = Color(0.22, 0.20, 0.19); body_len = 1.3; body_height = 0.85

const SEP_RADIUS := 4.5   # creatures push apart within this (no-clip fix)

func _ready() -> void:
	add_to_group("mock_creature")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.95
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(body_height * 0.6, body_height * 0.55, body_len)
	body.mesh = bm
	body.position.y = body_height
	body.material_override = mat
	add_child(body)
	_head = MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(body_height * 0.35, body_height * 0.35, body_height * 0.5)
	_head.mesh = hm
	_head.material_override = mat
	_head.position = Vector3(0, body_height + 0.1, body_len * 0.5 + 0.1)
	add_child(_head)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = body_color.darkened(0.3)
	for i in 4:
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.height = body_height; lm.top_radius = 0.06; lm.bottom_radius = 0.05
		leg.mesh = lm
		leg.material_override = leg_mat
		var fx := 0.22 if i < 2 else -0.22
		var fz := body_len * 0.35 * (1 if i % 2 == 0 else -1)
		leg.position = Vector3(fx, body_height * 0.5, fz)
		add_child(leg)
		_legs.append(leg)
	_graze_timer = randf() * 3.0

func _process(delta: float) -> void:
	if not height_fn.is_valid():
		return
	var threat_pos: Vector3 = threat_fn.call() if threat_fn.is_valid() else Vector3(1e12, 0, 0)
	var to_threat := threat_pos - global_position
	to_threat.y = 0.0
	var dist := to_threat.length()

	var prev_state := _state
	match _state:
		State.GRAZE:
			if dist < alert_radius:
				_state = State.ALERT
		State.ALERT:
			if dist < trigger_radius:
				_state = State.APPROACH if approaches else State.FLEE
			elif dist > calm_radius:
				_state = State.GRAZE
		State.FLEE:
			if dist > calm_radius:
				_state = State.GRAZE
		State.APPROACH:
			if dist > calm_radius:
				_state = State.GRAZE

	# wolf APPROACH is the only state permitted to raise a threat signal (null-write law)
	if approaches and (_state == State.APPROACH) != (prev_state == State.APPROACH):
		became_threat.emit(_state == State.APPROACH)

	var move := Vector3.ZERO
	match _state:
		State.GRAZE:
			_graze_timer -= delta
			if _graze_timer <= 0.0:
				_graze_timer = randf_range(2.0, 6.0)
				_heading += randf_range(-1.0, 1.0)
			# amble slowly, occasionally
			if _graze_timer < 1.5:
				move = Vector3(sin(_heading), 0, cos(_heading)) * walk_speed
			_head.position.y = body_height + 0.1 + sin(Time.get_ticks_msec() * 0.002) * 0.15  # head bob, grazing
		State.ALERT:
			_heading = atan2(to_threat.x, to_threat.z)  # face threat, still
			_head.position.y = body_height + 0.35  # head up
		State.FLEE:
			_heading = atan2(-to_threat.x, -to_threat.z)  # away from threat
			move = Vector3(sin(_heading), 0, cos(_heading)) * flee_speed
		State.APPROACH:
			_heading = atan2(to_threat.x, to_threat.z)  # toward threat
			move = Vector3(sin(_heading), 0, cos(_heading)) * flee_speed

	# separation: push apart from nearby creatures so a herd/pack spreads instead of merging
	var sep := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("mock_creature"):
		if other == self:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var dd := away.length()
		if dd > 0.01 and dd < SEP_RADIUS:
			sep += away.normalized() * (SEP_RADIUS - dd)
	move += sep * 3.0

	var np := global_position + move * delta
	np.y = height_fn.call(np.x, np.z)
	global_position = np
	rotation.y = _heading

	# procedural gait: legs swing proportional to speed
	var spd := move.length()
	_gait += spd * delta * 2.5
	for i in _legs.size():
		var phase := _gait + (0.0 if i < 2 else PI)
		_legs[i].position.z = _legs[i].position.z  # keep base
		_legs[i].rotation.x = sin(phase + i) * clampf(spd * 0.06, 0.0, 0.6)
