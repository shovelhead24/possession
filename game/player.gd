extends CharacterBody3D

const SPEED = 10.0  # 50% reduced from 20.0
const FLY_SPEED = 100.0
const FLY_SPRINT_SPEED = 200.0  # Sprint speed while flying (Ctrl key)
const JUMP_VELOCITY = 8.0
const SENSITIVITY = 0.003
const STICK_SENSITIVITY = 2.5  # Radians/sec at full stick deflection

var fly_mode = false  # Walk mode by default
var current_speed: float = 0.0  # Tracked for HUD display
var hud_instance: Node = null  # Reference to HUD for updates

# Player health
@export var max_health: float = 100.0
var health: float = 100.0
var damage_flash_timer: float = 0.0
var is_dead: bool = false

# Weapon system
enum WeaponType { CARBINE, RAILGUN }
var current_weapon: WeaponType = WeaponType.CARBINE

# Bullet variables (Carbine)
@export var bullet_scene: PackedScene  # Drag bullet.tscn here in inspector
@export var bullet_speed = 50.0
@export var shoot_cooldown = 0.2  # Time between shots

# Railgun variables
@export var railgun_damage = 100.0
@export var railgun_cooldown = 1.5  # Slower fire rate
@export var rail_beam_duration = 0.3  # How long the beam stays visible

@export var hud_scene: PackedScene
@onready var camera = $Head/Camera3D
@onready var head = $Head
@onready var weapon_holder = $WeaponViewport/SubViewportContainer/SubViewport/WeaponCamera/WeaponHolder
@onready var weapon_camera = $WeaponViewport/SubViewportContainer/SubViewport/WeaponCamera
@onready var weapon_viewport = $WeaponViewport/SubViewportContainer/SubViewport

# Weapon model references
@onready var carbine_model = $WeaponViewport/SubViewportContainer/SubViewport/WeaponCamera/WeaponHolder/Carbine
@onready var railgun_model = $WeaponViewport/SubViewportContainer/SubViewport/WeaponCamera/WeaponHolder/Railgun
@onready var fp_arms = $WeaponViewport/SubViewportContainer/SubViewport/WeaponCamera/WeaponHolder/FPArms

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2.0  # 100% increased
var can_shoot = true

# Weapon animation variables
var weapon_base_position: Vector3
var bob_time: float = 0.0
@export var bob_frequency: float = 12.0  # How fast the bobbing cycles
@export var bob_amplitude_x: float = 0.0006  # Side-to-side bob amount (20% of original)
@export var bob_amplitude_y: float = 0.001  # Up-down bob amount (20% of original)
@export var bob_lerp_speed: float = 10.0  # How fast to return to center

# Recoil variables
var current_recoil: Vector3 = Vector3.ZERO
var current_recoil_rotation: Vector3 = Vector3.ZERO
@export var recoil_amount: float = 0.02  # How far back the gun kicks
@export var recoil_rotation_amount: float = 0.05  # How much the gun rotates up

# FP Arms adjustment mode (hold T to enable)
var arms_adjust_mode: bool = false
# Weapon model adjustment mode (hold Y to enable)
var weapon_adjust_mode: bool = false
var adjust_move_speed: float = 0.01  # Position adjustment per keypress
var adjust_scale_speed: float = 0.005  # Scale adjustment per keypress (5x faster)
@export var recoil_recovery_speed: float = 15.0  # How fast recoil recovers

# Prop offset adjustment mode (hold G to enable)
var prop_adjust_mode: bool = false
var grass_offset: float = -0.15  # Current grass Y offset
var small_tree_offset: float = 0.0  # Current small tree Y offset

@onready var carbine_sound = $Plasma_rifle_sound
@onready var railgun_sound = $Railgun_sound

# Rail beam effect
var rail_beams: Array = []  # Active rail beams

# Vehicle state
var in_vehicle: bool = false
var current_vehicle: Node3D = null
var _weapon_switch_timer: float = 0.0  # Debounce: prevents double-switch on same press

# Zoom — R3 cycles through magnification steps
const ZOOM_FOVS: Array = [75.0, 50.0, 25.0, 7.5]  # 1× 1.5× 3× 10×
var _zoom_index: int = 0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Auto-release mouse when window loses focus, re-capture on click
	get_viewport().get_window().focus_exited.connect(_on_window_focus_lost)
	get_viewport().get_window().focus_entered.connect(_on_window_focus_gained)

	# Allow climbing steeper slopes (default is ~45 degrees / 0.785 radians)
	floor_max_angle = deg_to_rad(70.0)  # Can climb up to 70 degree slopes

	# Store weapon base position for animations
	if weapon_holder:
		weapon_base_position = weapon_holder.position
		# Set all weapon meshes to layer 2 so only weapon camera sees them
		_set_layer_recursive(weapon_holder, 2)

	# Resize weapon viewport to match window
	if weapon_viewport:
		weapon_viewport.size = get_viewport().size
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Load HUD scene if not assigned in inspector
	if not hud_scene:
		# Try to load HUD scene from common paths
		if ResourceLoader.exists("res://hud.tscn"):
			hud_scene = preload("res://hud.tscn")
		else:
			push_error("HUD scene not found! Please assign it in the inspector or create hud.tscn")
	
	# Only instantiate HUD if we have a valid scene
	if hud_scene:
		hud_instance = hud_scene.instantiate()
		get_parent().add_child.call_deferred(hud_instance)
		await get_tree().process_frame

		# Setup crosshair if it exists
		var reticle = hud_instance.get_node_or_null("Crosshair")
		if reticle:
			var viewport_center = get_viewport().get_visible_rect().size / 2
			reticle.position = viewport_center

		# Initialize health display
		health = max_health
		update_health_display()

	# Load bullet scene if not assigned in inspector
	if not bullet_scene:
		bullet_scene = preload("res://bullet.tscn")

func _on_window_focus_lost():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_window_focus_gained():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_viewport_size_changed():
	if weapon_viewport:
		weapon_viewport.size = get_viewport().size

func _set_layer_recursive(node: Node, layer: int):
	# Set visual layer on VisualInstance3D nodes (meshes, etc.)
	if node is VisualInstance3D:
		node.layers = layer
	# Recurse into children
	for child in node.get_children():
		_set_layer_recursive(child, layer)

func _process(delta):
	# Sync weapon camera with main camera rotation every frame
	if weapon_camera and camera:
		weapon_camera.global_transform = camera.global_transform
	if _weapon_switch_timer > 0.0:
		_weapon_switch_timer -= delta

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotate_x(-event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -1.5, 1.5)
	
	# Add shooting
	if event.is_action_pressed("shoot") and can_shoot:
		shoot()
	
	# Release mouse (Escape)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Re-capture mouse on left click when window is focused but mouse is free
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# D-pad Up / R key — git pull latest commits then reload scene
	if event.is_action_pressed("reload_scene"):
		_pull_and_reload()

	# Zoom — R3 cycles 1× → 1.5× → 3× → 10× → back to 1×
	if event.is_action_pressed("zoom"):
		_zoom_index = (_zoom_index + 1) % ZOOM_FOVS.size()
		if camera:
			camera.fov = ZOOM_FOVS[_zoom_index]

	# Toggle fly mode — F key or D-pad Right
	if event.is_action_pressed("toggle_fly"):
		fly_mode = !fly_mode
		print("Fly mode: ", "ON" if fly_mode else "OFF")

	# Weapon switching — all paths go through switch_weapon() which has a debounce guard
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_weapon()
	if event.is_action_pressed("switch_weapon"):
		switch_weapon()

	# Biome switching with number keys 1-7
	if event is InputEventKey and event.pressed:
		var biome_key = -1
		match event.keycode:
			KEY_1: biome_key = 0  # Ring Edge Mountains
			KEY_2: biome_key = 1  # Rolling Plains
			KEY_3: biome_key = 2  # Dense Forest
			KEY_4: biome_key = 3  # Highland Plateau
			KEY_5: biome_key = 4  # River Valley
			KEY_6: biome_key = 5  # Rocky Badlands
			KEY_7: biome_key = 6  # Coastal Lowlands

		if biome_key >= 0:
			var terrain_manager = get_node_or_null("/root/World/TerrainManager")
			if terrain_manager and terrain_manager.has_method("switch_biome"):
				terrain_manager.switch_biome(biome_key)

	# Adjustment modes - Hold T for arms, Y for weapons
	if event is InputEventKey:
		if event.keycode == KEY_T:
			arms_adjust_mode = event.pressed
			weapon_adjust_mode = false  # Disable other modes
			prop_adjust_mode = false
			if event.pressed:
				print("=== FP ARMS ADJUSTMENT MODE ===")
				print("IJKL = Move X/Z, U/O = Move Y, +/- = Scale, R = Rotate Y")
				print("P = Print current transform, Shift = fine adjust")
				if fp_arms:
					print("Current pos: ", fp_arms.position, " scale: ", fp_arms.scale.x)

		if event.keycode == KEY_Y:
			weapon_adjust_mode = event.pressed
			arms_adjust_mode = false  # Disable other mode
			prop_adjust_mode = false
			if event.pressed:
				var weapon_name = "CARBINE" if current_weapon == WeaponType.CARBINE else "RAILGUN"
				print("=== WEAPON ADJUSTMENT MODE (" + weapon_name + ") ===")
				print("IJKL = Move X/Z, U/O = Move Y, +/- = Scale, R = Rotate Y")
				print("P = Print current transform, Shift = fine adjust")
				var active_weapon = carbine_model if current_weapon == WeaponType.CARBINE else railgun_model
				if active_weapon:
					print("Current pos: ", active_weapon.position, " scale: ", active_weapon.scale)

		if event.keycode == KEY_G:
			prop_adjust_mode = event.pressed
			arms_adjust_mode = false
			weapon_adjust_mode = false
			if event.pressed:
				print("=== PROP OFFSET ADJUSTMENT MODE ===")
				print("U/O = Adjust grass offset, I/K = Adjust small tree offset")
				print("P = Print current offsets, Shift = fine adjust")
				print("Current grass_offset: ", grass_offset, ", small_tree_offset: ", small_tree_offset)

		# Process prop adjustment keys when G is held
		if prop_adjust_mode and event.pressed:
			var speed = 0.05
			if Input.is_key_pressed(KEY_SHIFT):
				speed = 0.01  # Fine adjustment

			match event.keycode:
				KEY_U:
					grass_offset += speed
					print("grass_offset = ", grass_offset)
					update_nearby_props()
				KEY_O:
					grass_offset -= speed
					print("grass_offset = ", grass_offset)
					update_nearby_props()
				KEY_I:
					small_tree_offset += speed
					print("small_tree_offset = ", small_tree_offset)
					update_nearby_props()
				KEY_K:
					small_tree_offset -= speed
					print("small_tree_offset = ", small_tree_offset)
					update_nearby_props()
				KEY_P:
					print("=== COPY THESE VALUES TO terrain_chunk.gd ===")
					print("grass_ground_offset = ", grass_offset)
					print("small_tree ground_offset = ", small_tree_offset)

		# Process adjustment keys when T (arms) or Y (weapon) is held
		if event.pressed:
			var target_node: Node3D = null
			var node_name: String = ""

			if arms_adjust_mode and fp_arms:
				target_node = fp_arms
				node_name = "FPArms"
			elif weapon_adjust_mode:
				if current_weapon == WeaponType.CARBINE and carbine_model:
					target_node = carbine_model
					node_name = "Carbine"
				elif current_weapon == WeaponType.RAILGUN and railgun_model:
					target_node = railgun_model
					node_name = "Railgun"

			if target_node:
				var speed = adjust_move_speed
				var scale_spd = adjust_scale_speed
				if Input.is_key_pressed(KEY_SHIFT):
					speed *= 0.1  # Fine adjustment
					scale_spd *= 0.1

				match event.keycode:
					KEY_I: target_node.position.z -= speed  # Forward
					KEY_K: target_node.position.z += speed  # Back
					KEY_J: target_node.position.x -= speed  # Left
					KEY_L: target_node.position.x += speed  # Right
					KEY_U: target_node.position.y += speed  # Up
					KEY_O: target_node.position.y -= speed  # Down
					KEY_EQUAL: target_node.scale += Vector3.ONE * scale_spd  # Scale up (+)
					KEY_MINUS: target_node.scale -= Vector3.ONE * scale_spd  # Scale down (-)
					KEY_R: target_node.rotation.y += 0.1  # Rotate Y
					KEY_P:  # Print current transform for copying to scene
						print("=== COPY THIS TRANSFORM TO world.tscn for " + node_name + " ===")
						print("Position: ", target_node.position)
						print("Rotation: ", target_node.rotation)
						print("Scale: ", target_node.scale)
						var t = target_node.transform
						print("Full Transform3D: Transform3D(", t.basis.x.x, ", ", t.basis.x.y, ", ", t.basis.x.z, ", ", t.basis.y.x, ", ", t.basis.y.y, ", ", t.basis.y.z, ", ", t.basis.z.x, ", ", t.basis.z.y, ", ", t.basis.z.z, ", ", t.origin.x, ", ", t.origin.y, ", ", t.origin.z, ")")

func _physics_process(delta):
	# Gamepad right-stick look — active always (including while in vehicle)
	var look_input = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_input.length() > 0.0:
		rotate_y(-look_input.x * STICK_SENSITIVITY * delta)
		head.rotate_x(-look_input.y * STICK_SENSITIVITY * delta)
		head.rotation.x = clamp(head.rotation.x, -1.5, 1.5)

	# Skip player movement when in a vehicle
	if in_vehicle:
		return

	# full auto shooting (only for carbine)
	if current_weapon == WeaponType.CARBINE and Input.is_action_pressed("shoot") and can_shoot:
		shoot()

	if fly_mode:
		# FLY MODE - move in camera direction, no gravity
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

		# Get camera forward and right vectors
		var cam_basis = camera.global_transform.basis
		var forward = -cam_basis.z
		var right = cam_basis.x

		# Calculate movement direction in 3D (follows camera look direction)
		var direction = (right * input_dir.x + forward * -input_dir.y).normalized()

		# Sprint with Ctrl key while flying
		var is_sprinting = Input.is_key_pressed(KEY_CTRL)
		var fly_speed = FLY_SPRINT_SPEED if is_sprinting else FLY_SPEED

		# Vertical movement - Space up, Shift down
		var vertical = 0.0
		if Input.is_action_pressed("ui_accept"):  # Space
			vertical = 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			vertical = -1.0

		if direction.length() > 0 or vertical != 0:
			velocity.x = direction.x * fly_speed
			velocity.y = vertical * fly_speed
			velocity.z = direction.z * fly_speed
		else:
			velocity = velocity.move_toward(Vector3.ZERO, fly_speed * 0.5)

	else:
		# WALK MODE - normal gravity-based movement
		if not is_on_floor():
			velocity.y -= gravity * delta

		# Handle jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Get input direction
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Track current speed for HUD display
	current_speed = velocity.length()

	# Update weapon animations
	update_weapon_animation(delta)

	# Update HUD with coordinates and speed
	update_hud()

func update_hud():
	if not hud_instance:
		return

	var coords_label = hud_instance.get_node_or_null("CoordsLabel")
	if coords_label:
		var pos = global_position
		coords_label.text = "X: %.0f  Y: %.0f  Z: %.0f" % [pos.x, pos.y, pos.z]

	var speed_label = hud_instance.get_node_or_null("SpeedLabel")
	if speed_label:
		var mode_text = "FLY" if fly_mode else "WALK"
		var sprint_text = " [SPRINT]" if fly_mode and Input.is_key_pressed(KEY_CTRL) else ""
		speed_label.text = "%s%s: %.1f m/s" % [mode_text, sprint_text, current_speed]

	# Debug stats (press Tab to toggle)
	var debug_label = hud_instance.get_node_or_null("DebugLabel")
	if debug_label:
		update_debug_stats(debug_label)

func update_weapon_animation(delta: float):
	if not weapon_holder:
		return

	# Get horizontal movement speed (ignore vertical for bobbing)
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()

	# Calculate bobbing based on movement
	var bob_offset = Vector3.ZERO
	if horizontal_velocity > 0.5 and is_on_floor():
		# Increase bob time based on speed
		bob_time += delta * bob_frequency * (horizontal_velocity / SPEED)

		# Calculate bob offsets using sine waves
		bob_offset.x = sin(bob_time) * bob_amplitude_x * horizontal_velocity
		bob_offset.y = abs(cos(bob_time)) * bob_amplitude_y * horizontal_velocity
	else:
		# Gradually reset bob time when not moving
		bob_time = lerp(bob_time, 0.0, delta * bob_lerp_speed)

	# Recover from recoil
	current_recoil = current_recoil.lerp(Vector3.ZERO, delta * recoil_recovery_speed)
	current_recoil_rotation = current_recoil_rotation.lerp(Vector3.ZERO, delta * recoil_recovery_speed)

	# Apply all offsets to weapon position
	var target_position = weapon_base_position + bob_offset + current_recoil
	weapon_holder.position = weapon_holder.position.lerp(target_position, delta * bob_lerp_speed)

	# Apply recoil rotation
	weapon_holder.rotation = weapon_holder.rotation.lerp(current_recoil_rotation, delta * bob_lerp_speed)

func apply_recoil():
	# Add recoil offset (kick back and up)
	current_recoil += Vector3(
		randf_range(-0.002, 0.002),  # Small random horizontal
		randf_range(0.0, 0.005),      # Slight upward kick
		recoil_amount                  # Backward kick
	)

	# Add recoil rotation (gun tilts up)
	current_recoil_rotation += Vector3(
		-recoil_rotation_amount,  # Pitch up
		randf_range(-0.01, 0.01),  # Small random yaw
		randf_range(-0.02, 0.02)   # Small random roll
	)

func update_debug_stats(label: Label):
	# Memory stats
	var mem_static = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0  # Convert to MB
	var mem_msg = Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX) / 1048576.0

	# Object counts
	var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var resources = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)

	# FPS
	var fps = Performance.get_monitor(Performance.TIME_FPS)

	# Chunk and prop pool stats
	var chunks_loaded = 0
	var chunks_queued = 0
	var pool_available = 0
	var pool_borrowed = 0
	var pool_total = 0

	var terrain_manager = get_node_or_null("/root/World/TerrainManager")
	if terrain_manager:
		if "chunks" in terrain_manager:
			chunks_loaded = terrain_manager.chunks.size()
		if "chunk_load_queue" in terrain_manager:
			chunks_queued = terrain_manager.chunk_load_queue.size()
		if "prop_pool" in terrain_manager and terrain_manager.prop_pool:
			var pool = terrain_manager.prop_pool
			if pool.has_method("get_stats"):
				var stats = pool.get_stats()
				pool_available = stats.get("available", 0)
				pool_borrowed = stats.get("borrowed", 0)
				pool_total = stats.get("total", 0)

	label.text = """FPS: %d
Memory: %.1f MB
Nodes: %d
Objects: %d
Resources: %d
---
Chunks: %d loaded
Queue: %d pending
---
Tree Pool: %d/%d
  Available: %d
  Borrowed: %d chunks""" % [
		fps,
		mem_static,
		nodes,
		objects,
		resources,
		chunks_loaded,
		chunks_queued,
		pool_total - pool_available, pool_total,
		pool_available,
		pool_borrowed
	]

func _pull_and_reload():
	print("=== RELOAD: pulling latest commits... ===")
	# git pull from the project root (one level up from res://)
	var project_dir = ProjectSettings.globalize_path("res://").rstrip("/")
	var parent_dir = project_dir.get_base_dir()  # repo root is parent of game/
	var output = []
	var exit = OS.execute("git", ["-C", parent_dir, "pull", "--ff-only", "origin", "main"], output, true)
	for line in output:
		print("git: ", line)
	print("=== RELOAD: git exit code ", exit, " — quitting so watcher relaunches ===")
	get_tree().quit()  # Watcher detects exit and relaunches Godot with new code

func switch_weapon():
	if _weapon_switch_timer > 0.0:
		return
	_weapon_switch_timer = 0.4
	if current_weapon == WeaponType.CARBINE:
		current_weapon = WeaponType.RAILGUN
		if carbine_model:
			carbine_model.visible = false
		if railgun_model:
			railgun_model.visible = true
		if fp_arms and fp_arms.has_method("set_weapon_pose"):
			fp_arms.set_weapon_pose("railgun")
		print("Switched to: RAILGUN")
	else:
		current_weapon = WeaponType.CARBINE
		if carbine_model:
			carbine_model.visible = true
		if railgun_model:
			railgun_model.visible = false
		if fp_arms and fp_arms.has_method("set_weapon_pose"):
			fp_arms.set_weapon_pose("carbine")
		print("Switched to: CARBINE")

func shoot():
	if not can_shoot:
		return

	if current_weapon == WeaponType.CARBINE:
		shoot_carbine()
	else:
		shoot_railgun()

func shoot_carbine():
	if not bullet_scene:
		return
	can_shoot = false

	# Apply recoil to weapon
	apply_recoil()

	# Play plasma rifle sound
	if carbine_sound:
		carbine_sound.pitch_scale = randf_range(0.9, 1.1)
		carbine_sound.play()

	# Create bullet
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)

	# Spawn bullet from weapon muzzle position
	var spawn_position: Vector3
	if weapon_holder:
		var muzzle_offset = Vector3(0, 0, -0.5)
		spawn_position = weapon_holder.global_position + camera.global_transform.basis * muzzle_offset
	else:
		var bullet_offset = Vector3(0.2, -0.2, -1.5)
		spawn_position = global_position + global_transform.basis * bullet_offset

	# Cast ray from camera through center of screen
	var viewport_center = get_viewport().get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(viewport_center)
	var ray_end = ray_origin + camera.project_ray_normal(viewport_center) * 1000

	# Perform raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	query.collision_mask = 0xFFFFFFFF
	var result = space_state.intersect_ray(query)

	var target_point = result.position if result else ray_end

	bullet.global_position = spawn_position
	var direction = (target_point - spawn_position).normalized()
	bullet.global_transform.basis = Basis.looking_at(direction, Vector3.UP)

	if bullet.has_method("set_velocity"):
		bullet.set_velocity(direction * bullet_speed)
	else:
		bullet.velocity = direction * bullet_speed

	# Cooldown
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

func shoot_railgun():
	can_shoot = false

	# Apply heavy recoil
	current_recoil += Vector3(
		randf_range(-0.005, 0.005),
		randf_range(0.005, 0.015),
		recoil_amount * 2.0
	)
	current_recoil_rotation += Vector3(
		-recoil_rotation_amount * 2.0,
		randf_range(-0.02, 0.02),
		randf_range(-0.03, 0.03)
	)

	# Play railgun sound
	if railgun_sound:
		railgun_sound.pitch_scale = randf_range(0.95, 1.05)
		railgun_sound.play()

	# Get muzzle position - use camera position with offset (same as carbine approach)
	# Note: Can't use railgun_model.global_position as it's in SubViewport world space
	var spawn_position: Vector3
	var muzzle_offset = Vector3(0.15, -0.1, -0.5)  # Right, down, forward - matches visual gun position
	spawn_position = camera.global_position + camera.global_transform.basis * muzzle_offset

	# Hitscan raycast
	var viewport_center = get_viewport().get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(viewport_center)
	var ray_end = ray_origin + camera.project_ray_normal(viewport_center) * 2000  # Longer range

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true  # Detect enemy hitboxes (Area3D)
	var result = space_state.intersect_ray(query)

	var hit_point: Vector3
	if result:
		hit_point = result.position
		var hit_collider = result.collider
		print("Railgun hit: ", hit_collider.name, " for ", railgun_damage, " damage")

		# Apply damage to hit target if it has take_damage method
		if hit_collider.has_method("take_damage"):
			hit_collider.take_damage(railgun_damage)
		# Also check parent (enemy hitbox's parent is the enemy)
		elif hit_collider.get_parent() and hit_collider.get_parent().has_method("take_damage"):
			hit_collider.get_parent().take_damage(railgun_damage)
		# Check grandparent too (in case of nested structure)
		elif hit_collider.get_parent() and hit_collider.get_parent().get_parent() and hit_collider.get_parent().get_parent().has_method("take_damage"):
			hit_collider.get_parent().get_parent().take_damage(railgun_damage)
	else:
		hit_point = ray_end

	# Create the rail beam effect (Quake 3 style)
	create_rail_beam(spawn_position, hit_point)

	# Longer cooldown for railgun
	await get_tree().create_timer(railgun_cooldown).timeout
	can_shoot = true

func create_rail_beam(start_pos: Vector3, end_pos: Vector3):
	# Create a cylinder mesh for the rail beam
	var beam_mesh = MeshInstance3D.new()

	# Create cylinder geometry
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.03
	cylinder.bottom_radius = 0.03
	cylinder.height = start_pos.distance_to(end_pos)
	beam_mesh.mesh = cylinder

	# Create glowing material (Quake 3 style blue/white spiral)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 1.0, 0.9)  # Blue core
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.7, 1.0)  # Bright blue glow
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mesh.material_override = mat

	# ADD TO SCENE FIRST so global transforms work correctly
	get_parent().add_child(beam_mesh)

	# NOW position at midpoint between start and end
	var midpoint = (start_pos + end_pos) / 2.0
	beam_mesh.global_position = midpoint

	# Rotate to point from start to end
	var direction = (end_pos - start_pos).normalized()
	var up_dot = abs(direction.dot(Vector3.UP))
	if up_dot < 0.99:  # Not pointing straight up or down
		beam_mesh.look_at(end_pos, Vector3.UP)
		beam_mesh.rotate_object_local(Vector3.RIGHT, PI / 2)
	else:
		# Handle vertical shots
		beam_mesh.rotation = Vector3.ZERO
		if direction.y < 0:
			beam_mesh.rotate_object_local(Vector3.RIGHT, PI)

	# Create outer glow beam (spiral effect)
	var glow_mesh = MeshInstance3D.new()
	var glow_cylinder = CylinderMesh.new()
	glow_cylinder.top_radius = 0.08
	glow_cylinder.bottom_radius = 0.08
	glow_cylinder.height = cylinder.height
	glow_mesh.mesh = glow_cylinder

	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.2, 0.3, 0.8, 0.4)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.3, 0.5, 1.0)
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mesh.material_override = glow_mat

	# ADD TO SCENE FIRST, then set transforms
	get_parent().add_child(glow_mesh)
	glow_mesh.global_position = midpoint
	glow_mesh.global_transform.basis = beam_mesh.global_transform.basis

	# Fade out and remove beam after duration
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, rail_beam_duration)
	tween.tween_property(glow_mat, "albedo_color:a", 0.0, rail_beam_duration)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, rail_beam_duration)
	tween.tween_property(glow_mat, "emission_energy_multiplier", 0.0, rail_beam_duration)

	await tween.finished
	beam_mesh.queue_free()
	glow_mesh.queue_free()

# Update nearby props with current offset values (for live adjustment)
func update_nearby_props():
	var terrain_manager = get_node_or_null("/root/World/TerrainManager")
	if not terrain_manager or not "chunks" in terrain_manager:
		print("No terrain manager found")
		return

	# Get player's chunk and nearby chunks
	var chunk_size = terrain_manager.chunk_size
	var player_chunk_x = int(floor(global_position.x / chunk_size))
	var player_chunk_z = int(floor(global_position.z / chunk_size))

	var updated_count = 0
	var tree_count = 0
	# Update props in player's chunk and immediate neighbors
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var chunk_coords = Vector2i(player_chunk_x + dx, player_chunk_z + dz)
			if chunk_coords in terrain_manager.chunks:
				var chunk = terrain_manager.chunks[chunk_coords]
				# Find Props node
				var props_node = chunk.get_node_or_null("Props")
				if props_node:
					for prop in props_node.get_children():
						if prop.has_meta("grass_type"):
							# It's grass - use mesh surface height + per-model pivot offset + user adjustment
							var terrain_height = chunk.get_mesh_surface_height(prop.global_position.x, prop.global_position.z)
							var pivot_offset = prop.get_meta("pivot_offset", -0.15) if prop.has_meta("pivot_offset") else -0.15
							prop.global_position.y = terrain_height + pivot_offset + grass_offset
							updated_count += 1
						elif prop.has_meta("tree_type"):
							# It's a tree - use mesh surface height + per-model pivot offset + user adjustment
							var terrain_height = chunk.get_mesh_surface_height(prop.global_position.x, prop.global_position.z)
							var pivot_offset = prop.get_meta("pivot_offset", 0.0) if prop.has_meta("pivot_offset") else 0.0
							prop.global_position.y = terrain_height + pivot_offset + small_tree_offset
							tree_count += 1
							updated_count += 1

	print("Updated ", updated_count, " props (", tree_count, " trees) in nearby chunks")

# ============== PLAYER HEALTH SYSTEM ==============

func take_damage(amount: float):
	if is_dead:
		return

	health -= amount
	health = max(health, 0)
	print("Player: Took ", amount, " damage! Health: ", health, "/", max_health)

	# Flash screen red
	flash_damage_effect()

	# Update HUD
	update_health_display()

	# Check for death
	if health <= 0:
		die()

func flash_damage_effect():
	# Create red flash overlay
	if hud_instance:
		var damage_overlay = hud_instance.get_node_or_null("DamageOverlay")
		if not damage_overlay:
			# Create damage overlay if it doesn't exist
			damage_overlay = ColorRect.new()
			damage_overlay.name = "DamageOverlay"
			damage_overlay.color = Color(1.0, 0.0, 0.0, 0.3)
			damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud_instance.add_child(damage_overlay)

		# Flash and fade
		damage_overlay.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(damage_overlay, "modulate:a", 0.0, 0.3)

func update_health_display():
	if not hud_instance:
		return

	var health_label = hud_instance.get_node_or_null("HealthLabel")
	if not health_label:
		# Create health label if it doesn't exist
		health_label = Label.new()
		health_label.name = "HealthLabel"
		health_label.add_theme_font_size_override("font_size", 24)
		health_label.position = Vector2(20, 20)
		hud_instance.add_child(health_label)

	# Update health text with color
	var health_percent = health / max_health
	var color = Color.GREEN
	if health_percent < 0.3:
		color = Color.RED
	elif health_percent < 0.6:
		color = Color.YELLOW

	health_label.text = "HP: %d/%d" % [int(health), int(max_health)]
	health_label.add_theme_color_override("font_color", color)

func die():
	is_dead = true
	print("Player: DEAD!")

	# Show death message
	if hud_instance:
		var death_label = Label.new()
		death_label.name = "DeathLabel"
		death_label.text = "YOU DIED\nRespawning..."
		death_label.add_theme_font_size_override("font_size", 48)
		death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		death_label.set_anchors_preset(Control.PRESET_CENTER)
		death_label.add_theme_color_override("font_color", Color.RED)
		hud_instance.add_child(death_label)

	# Respawn after delay
	await get_tree().create_timer(2.0).timeout
	respawn()

func respawn():
	# Reset health
	health = max_health
	is_dead = false

	# Remove death label
	if hud_instance:
		var death_label = hud_instance.get_node_or_null("DeathLabel")
		if death_label:
			death_label.queue_free()

	# Respawn at original position or near current
	var terrain_manager = get_node_or_null("/root/World/TerrainManager")
	if terrain_manager and terrain_manager.has_method("get_height_at_position"):
		var spawn_height = terrain_manager.get_height_at_position(global_position) + 2.0
		global_position.y = spawn_height

	# Reset velocity
	velocity = Vector3.ZERO

	# Update HUD
	update_health_display()

	print("Player: Respawned with ", health, " HP")

# Vehicle entry/exit handling
func set_in_vehicle(entering: bool, vehicle: Node3D):
	in_vehicle = entering
	current_vehicle = vehicle

	if entering:
		# Hide weapon viewport when in vehicle
		if weapon_viewport:
			weapon_viewport.get_parent().get_parent().visible = false
		print("Player: Entered vehicle")
	else:
		# Show weapon viewport when exiting vehicle
		if weapon_viewport:
			weapon_viewport.get_parent().get_parent().visible = true
		print("Player: Exited vehicle")
