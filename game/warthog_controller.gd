extends VehicleBody3D

# Warthog vehicle controller
# Allows player to enter/exit and drive the vehicle

# Vehicle settings
@export_group("Engine")
@export var engine_power: float = 5000.0  # High power for responsive acceleration
@export var max_rpm: float = 1000.0
@export var brake_power: float = 150.0

@export_group("Steering")
@export var max_steer_angle: float = 0.6  # Radians - tighter turning
@export var steer_speed: float = 8.0  # Fast steering response like a quad bike

@export_group("Turret")
@export var turret_rotation_speed: float = 2.0
@export var turret_damage: float = 15.0
@export var turret_fire_rate: float = 0.1  # Seconds between shots

# Wheel references (assign in inspector or find automatically)
@export var front_left_wheel: VehicleWheel3D
@export var front_right_wheel: VehicleWheel3D
@export var rear_left_wheel: VehicleWheel3D
@export var rear_right_wheel: VehicleWheel3D

# State
var is_occupied: bool = false
var driver: Node3D = null
var current_steer: float = 0.0
var turret_node: Node3D = null
var can_fire: bool = true

# Entry/exit
@export var exit_offset: Vector3 = Vector3(3, 0, 0)  # Where player exits
var interaction_area: Area3D = null

# References
var terrain_manager: Node = null

@export var auto_enter: bool = true  # Spawn player in vehicle automatically

# Tuning variables (adjusted at runtime with XCVBNM keys)
var current_suspension_stiffness: float = 80.0
var current_mass: float = 800.0
var current_com_height: float = -0.5  # Center of mass Y offset
var current_downforce: float = 3000.0  # Downward force to keep vehicle planted
var current_damping: float = 4.0  # Wheel damping multiplier

func _ready():
	# Lower center of mass for stability (prevents tipping)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.5, 0)  # Lower than default

	# Find terrain manager
	terrain_manager = get_node_or_null("/root/World/TerrainManager")

	# Find turret if not assigned
	turret_node = find_node_by_name(self, "Gun")
	if turret_node:
		print("Warthog: Found turret node")

	# Set up wheel references if not assigned
	setup_wheels()

	# If no wheels found the asset pack is missing - freeze physics to prevent engine crash
	var has_wheels = (front_left_wheel != null or front_right_wheel != null
					or rear_left_wheel != null or rear_right_wheel != null)
	if not has_wheels:
		freeze = true
		print("Warthog: No wheels found (halo_warthog asset pack missing) - physics frozen")
		return

	# Create interaction area for entering vehicle
	setup_interaction_area()

	# Position on terrain
	call_deferred("position_on_terrain")

	# Auto-enter player if enabled
	if auto_enter:
		call_deferred("auto_enter_player")

	print("Warthog: Ready!")

func auto_enter_player():
	await get_tree().process_frame
	await get_tree().process_frame
	var player = get_node_or_null("/root/World/Player")
	if player:
		enter_vehicle(player)
		print("Warthog: Auto-entered player")

func setup_wheels():
	# Find VehicleWheel3D children if not manually assigned
	for child in get_children():
		if child is VehicleWheel3D:
			var wheel_name = child.name.to_lower()
			if "front" in wheel_name and "left" in wheel_name:
				front_left_wheel = child
			elif "front" in wheel_name and "right" in wheel_name:
				front_right_wheel = child
			elif "rear" in wheel_name and "left" in wheel_name:
				rear_left_wheel = child
			elif "rear" in wheel_name and "right" in wheel_name:
				rear_right_wheel = child

	# Configure front wheels as steering
	if front_left_wheel:
		front_left_wheel.use_as_steering = true
	if front_right_wheel:
		front_right_wheel.use_as_steering = true

	# Configure rear wheels as traction
	if rear_left_wheel:
		rear_left_wheel.use_as_traction = true
	if rear_right_wheel:
		rear_right_wheel.use_as_traction = true

func setup_interaction_area():
	# Create Area3D for player to enter vehicle
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"

	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 4.0  # Detection radius
	collision.shape = shape
	interaction_area.add_child(collision)

	add_child(interaction_area)

	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

var player_nearby: Node3D = null

func _on_body_entered(body: Node3D):
	if body.name == "Player" and not is_occupied:
		player_nearby = body
		print("Warthog: Press E to enter")
		# Could show UI prompt here

func _on_body_exited(body: Node3D):
	if body == player_nearby:
		player_nearby = null

func position_on_terrain():
	await get_tree().process_frame
	await get_tree().process_frame

	if terrain_manager and terrain_manager.has_method("get_height_at_position"):
		var terrain_height = terrain_manager.get_height_at_position(global_position)
		global_position.y = terrain_height + 1.5  # Slight offset so wheels touch ground
		print("Warthog: Positioned at height ", terrain_height)

func _physics_process(delta):
	# Check for enter/exit input
	if Input.is_action_just_pressed("interact"):  # E key
		if is_occupied:
			exit_vehicle()
		elif player_nearby:
			enter_vehicle(player_nearby)

	if not is_occupied:
		return

	# Get input
	var throttle = Input.get_axis("move_back", "move_forward")
	var steer_input = Input.get_axis("move_right", "move_left")
	var brake_input = Input.is_action_pressed("ui_cancel")  # Or a brake key

	# Smooth steering
	current_steer = lerp(current_steer, steer_input * max_steer_angle, steer_speed * delta)
	steering = current_steer

	# Apply engine force
	engine_force = throttle * engine_power

	# Apply brakes
	if brake_input or (throttle == 0 and linear_velocity.length() > 0.5):
		brake = brake_power * 0.3  # Light brake when coasting
	else:
		brake = 0.0

	# Handbrake with Space
	if Input.is_action_pressed("ui_accept"):
		brake = brake_power

	# Turret control with mouse (if we have a turret)
	if turret_node and Input.is_action_pressed("shoot"):
		fire_turret()

	# Physics tuning controls (XCVBNM)
	handle_tuning_input()

	# Apply downforce to keep vehicle planted
	if current_downforce > 0:
		apply_central_force(Vector3.DOWN * current_downforce)

func enter_vehicle(player: Node3D):
	if is_occupied:
		return

	driver = player
	is_occupied = true

	# FIRST: Disable player collision BEFORE reparenting to prevent physics explosion
	var player_collision = driver.get_node_or_null("CollisionShape3D")
	if player_collision:
		player_collision.disabled = true

	# Hide player and disable their controls
	if driver.has_method("set_in_vehicle"):
		driver.set_in_vehicle(true, self)
	else:
		driver.set_physics_process(false)
		driver.set_process(false)

	# Hide player mesh
	driver.visible = false

	# NOW reparent player to vehicle so they move together
	var old_parent = driver.get_parent()
	if old_parent:
		old_parent.remove_child(driver)
	add_child(driver)
	driver.position = Vector3(0.5, 1.3, 0)  # Seat position inside vehicle
	driver.rotation.y = PI  # Face forward (vehicle model's front is +Z, player default faces -Z)

	print("Warthog: Player entered!")

func exit_vehicle():
	if not is_occupied or not driver:
		return

	# Calculate exit position (side of vehicle)
	var exit_pos = global_position + global_transform.basis * exit_offset

	# Adjust for terrain height
	if terrain_manager and terrain_manager.has_method("get_height_at_position"):
		var terrain_height = terrain_manager.get_height_at_position(exit_pos)
		exit_pos.y = terrain_height + 1.0

	# Reparent player back to world BEFORE re-enabling collision
	remove_child(driver)
	var world = get_node("/root/World")
	if world:
		world.add_child(driver)

	# Move player to exit position
	driver.global_position = exit_pos

	# NOW re-enable player collision (after they're away from vehicle)
	var player_collision = driver.get_node_or_null("CollisionShape3D")
	if player_collision:
		player_collision.disabled = false

	driver.visible = true
	driver.set_physics_process(true)
	driver.set_process(true)

	# Re-enable player controls
	if driver.has_method("set_in_vehicle"):
		driver.set_in_vehicle(false, null)

	print("Warthog: Player exited at ", exit_pos)

	driver = null
	is_occupied = false

func fire_turret():
	if not can_fire:
		return

	can_fire = false

	# Create bullet/tracer effect
	# For now, just do a raycast hit
	if driver and driver.has_node("Head/Camera3D"):
		var camera = driver.get_node("Head/Camera3D")
		var from = turret_node.global_position if turret_node else global_position + Vector3(0, 2, 0)
		var to = from + (-global_transform.basis.z * 200.0)  # Forward direction

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)

		if result:
			var hit = result.collider
			if hit.has_method("take_damage"):
				hit.take_damage(turret_damage)
				print("Warthog turret hit: ", hit.name)

	# Cooldown
	await get_tree().create_timer(turret_fire_rate).timeout
	can_fire = true

func handle_tuning_input():
	var changed = false

	# X/C - Suspension stiffness (lower/higher)
	if Input.is_key_pressed(KEY_X):
		current_suspension_stiffness = max(5.0, current_suspension_stiffness - 1.0)
		changed = true
	if Input.is_key_pressed(KEY_C):
		current_suspension_stiffness = min(300.0, current_suspension_stiffness + 1.0)
		changed = true

	# V/B - Mass (lighter/heavier)
	if Input.is_key_pressed(KEY_V):
		current_mass = max(100.0, current_mass - 10.0)
		mass = current_mass
		changed = true
	if Input.is_key_pressed(KEY_B):
		current_mass = min(3000.0, current_mass + 10.0)
		mass = current_mass
		changed = true

	# N/M - Center of mass height (lower/higher)
	if Input.is_key_pressed(KEY_N):
		current_com_height = max(-3.0, current_com_height - 0.05)
		center_of_mass = Vector3(0, current_com_height, 0)
		changed = true
	if Input.is_key_pressed(KEY_M):
		current_com_height = min(1.0, current_com_height + 0.05)
		center_of_mass = Vector3(0, current_com_height, 0)
		changed = true

	# 1/2 - Downforce (less/more) - keeps vehicle planted
	if Input.is_key_pressed(KEY_1):
		current_downforce = max(0.0, current_downforce - 50.0)
		changed = true
	if Input.is_key_pressed(KEY_2):
		current_downforce = min(10000.0, current_downforce + 50.0)
		changed = true

	# 3/4 - Damping (less bouncy / more bouncy)
	if Input.is_key_pressed(KEY_3):
		current_damping = max(0.5, current_damping - 0.1)
		changed = true
	if Input.is_key_pressed(KEY_4):
		current_damping = min(20.0, current_damping + 0.1)
		changed = true

	# Apply settings to all wheels
	if changed:
		for wheel in [front_left_wheel, front_right_wheel, rear_left_wheel, rear_right_wheel]:
			if wheel:
				wheel.suspension_stiffness = current_suspension_stiffness
				wheel.damping_compression = current_damping
				wheel.damping_relaxation = current_damping * 1.2
		print("Stiff: %.0f | Mass: %.0f | CoM: %.2f | Down: %.0f | Damp: %.1f" % [current_suspension_stiffness, current_mass, current_com_height, current_downforce, current_damping])

# Helper to find nodes by name (iterative)
func find_node_by_name(root: Node, target_name: String) -> Node:
	var queue: Array = [root]
	while queue.size() > 0:
		var node = queue.pop_back()
		if node.name == target_name:
			return node
		for child in node.get_children():
			queue.push_back(child)
	return null

# Called when vehicle is destroyed
func destroy():
	if is_occupied:
		exit_vehicle()
	# Could add explosion effect here
	queue_free()
