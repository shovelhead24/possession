extends Node3D

# Enemy AI controller with pathfinding, combat, and health system

# AI States
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

# Health
@export var max_health: float = 100.0
var health: float = 100.0

# Combat
@export var attack_damage: float = 10.0
@export var attack_range: float = 3.0  # Distance to start attacking
@export var attack_cooldown: float = 1.0  # Seconds between attacks
var can_attack: bool = true

# Movement
@export var move_speed: float = 5.0
@export var chase_range: float = 30.0  # Distance to start chasing
@export var lose_range: float = 50.0  # Distance to stop chasing

# References
var animation_player: AnimationPlayer = null
var current_anim: String = ""
var terrain_manager: Node = null
var player: Node3D = null
var is_positioned: bool = false

# Animation settings - times in seconds within "allanims"
# Adjust these in the inspector based on your model's animation layout
@export_group("Animation Timings (seconds)")
@export var anim_idle_start: float = 0.0
@export var anim_idle_end: float = 2.0
@export var anim_walk_start: float = 2.0
@export var anim_walk_end: float = 3.0
@export var anim_run_start: float = 3.0
@export var anim_run_end: float = 4.0
@export var anim_attack_start: float = 4.0
@export var anim_attack_end: float = 5.0
@export var anim_death_start: float = 5.0
@export var anim_death_end: float = 6.0

# Animation state tracking
var current_anim_state: String = ""
var anim_length: float = 0.0

# Visual feedback
var original_materials: Dictionary = {}  # mesh_instance -> material
var damage_flash_timer: float = 0.0

# Collision for hit detection
var hitbox: Area3D = null

func _ready():
	# Hide until properly positioned
	visible = false
	health = max_health

	# Find terrain manager
	terrain_manager = get_node_or_null("/root/World/TerrainManager")

	# Find player
	player = get_node_or_null("/root/World/Player")

	# Find the AnimationPlayer in the scene hierarchy
	animation_player = find_animation_player(self)

	# Store original materials for damage flash
	store_original_materials(self)

	# Create hitbox for bullet collision detection
	setup_hitbox()

	if animation_player:
		print("Enemy: Found AnimationPlayer with animations: ", animation_player.get_animation_list())

		# Get the list of animations
		var anims = animation_player.get_animation_list()
		if anims.size() > 0:
			# Find the main animation (prefer "allanims" or first available)
			current_anim = anims[0]
			for anim in anims:
				if "allanims" in anim.to_lower():
					current_anim = anim
					break

			# Get animation details
			var anim_resource = animation_player.get_animation(current_anim)
			if anim_resource:
				anim_length = anim_resource.length
				print("Enemy: Animation '", current_anim, "' length: ", anim_length, " seconds")
				print("Enemy: Configure animation timings in inspector!")
				print("Enemy: Current settings - idle: ", anim_idle_start, "-", anim_idle_end,
					  ", walk: ", anim_walk_start, "-", anim_walk_end,
					  ", run: ", anim_run_start, "-", anim_run_end,
					  ", attack: ", anim_attack_start, "-", anim_attack_end,
					  ", death: ", anim_death_start, "-", anim_death_end)

			# Start with idle animation
			play_animation("idle")
	else:
		print("Enemy: WARNING - No AnimationPlayer found!")

	# Position on terrain after delay
	position_on_terrain()

func setup_hitbox():
	# Create Area3D hitbox for bullet detection
	hitbox = Area3D.new()
	hitbox.name = "HitBox"
	add_child(hitbox)

	# Create capsule collision shape (sized for enemy's 0.01 scale)
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 50.0  # ~0.5m when scaled by 0.01
	capsule.height = 180.0  # ~1.8m when scaled by 0.01
	collision.shape = capsule
	collision.position.y = 90.0  # Center the capsule
	hitbox.add_child(collision)

	# Set collision layer 2 (enemies), mask 1 (player/bullets)
	hitbox.collision_layer = 2
	hitbox.collision_mask = 1

	# Connect signals
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _on_hitbox_area_entered(area: Area3D):
	# Bullets are Area3D with damage property
	if "damage" in area:
		take_damage(area.damage)

func store_original_materials(node: Node):
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		if mesh_inst.mesh:
			for i in range(mesh_inst.mesh.get_surface_count()):
				var mat = mesh_inst.get_active_material(i)
				if mat:
					original_materials[mesh_inst] = mat.duplicate()
					break  # Store first material found

	for child in node.get_children():
		store_original_materials(child)

func position_on_terrain():
	print("Enemy: Starting terrain positioning at ", global_position)

	if not terrain_manager:
		print("Enemy: ERROR - No terrain manager found!")
		visible = true
		is_positioned = true
		return

	# Get the chunk coords for enemy's position
	var chunk_size = terrain_manager.chunk_size if "chunk_size" in terrain_manager else 25.0
	var enemy_chunk_x = int(floor(global_position.x / chunk_size))
	var enemy_chunk_z = int(floor(global_position.z / chunk_size))
	var enemy_chunk_coords = Vector2i(enemy_chunk_x, enemy_chunk_z)

	print("Enemy: Need chunk ", enemy_chunk_coords, " to be loaded")

	# Wait until our chunk exists with collision
	while true:
		await get_tree().process_frame

		if "chunks" in terrain_manager:
			if enemy_chunk_coords in terrain_manager.chunks:
				var chunk = terrain_manager.chunks[enemy_chunk_coords]
				if chunk.has_collision and chunk.collision_body and chunk.collision_body.is_inside_tree():
					print("Enemy: Chunk ", enemy_chunk_coords, " is ready with collision")
					break

	# Wait for physics to register
	await get_tree().physics_frame

	# Get terrain height and position enemy
	var terrain_height = terrain_manager.get_height_at_position(global_position)
	global_position.y = terrain_height + 0.1  # Small offset above terrain

	print("Enemy: Positioned at height ", terrain_height)
	print("Enemy: Final position = ", global_position)

	visible = true
	is_positioned = true
	print("Enemy: Ready for battle! Health: ", health)

func _process(delta):
	if not is_positioned:
		return

	# Update damage flash effect
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if damage_flash_timer <= 0:
			reset_materials()

	# Handle animation segment looping (for combined "allanims")
	if animation_player and animation_player.is_playing() and current_state != State.DEAD:
		var end_time = get_meta("anim_end_time", anim_length) as float
		var start_time = get_meta("anim_start_time", 0.0) as float
		var current_pos = animation_player.current_animation_position

		# Loop back to start when we reach the end of the segment
		if current_pos >= end_time - 0.05:  # Small buffer
			animation_player.seek(start_time, true)

	if current_state == State.DEAD:
		return

	# Keep enemy on terrain surface
	if terrain_manager and terrain_manager.has_method("get_height_at_position"):
		var terrain_height = terrain_manager.get_height_at_position(global_position)
		global_position.y = terrain_height + 0.1

	# AI State Machine
	update_ai(delta)

func update_ai(delta):
	if not player:
		player = get_node_or_null("/root/World/Player")
		if not player:
			return

	var distance_to_player = global_position.distance_to(player.global_position)
	var prev_state = current_state

	match current_state:
		State.IDLE:
			# Play idle animation
			play_animation("idle")

			# Check if player is in chase range
			if distance_to_player < chase_range:
				current_state = State.CHASE
				print("Enemy: Player spotted! Chasing...")

		State.CHASE:
			# Play run animation while chasing
			play_animation("run")

			# Move toward player
			move_toward_player(delta)

			# Check if close enough to attack
			if distance_to_player < attack_range:
				current_state = State.ATTACK
			# Check if player is too far
			elif distance_to_player > lose_range:
				current_state = State.IDLE
				print("Enemy: Lost sight of player")

		State.ATTACK:
			# Play attack animation
			play_animation("attack")

			# Face player
			look_at_player()

			# Attack if we can
			if can_attack:
				attack_player()

			# If player moved out of attack range, chase again
			if distance_to_player > attack_range * 1.5:
				current_state = State.CHASE

		State.DEAD:
			pass

func move_toward_player(delta):
	if not player:
		return

	# Calculate direction to player (ignore Y for ground movement)
	var direction = player.global_position - global_position
	direction.y = 0
	direction = direction.normalized()

	# Move toward player
	global_position += direction * move_speed * delta

	# Face movement direction
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)

func look_at_player():
	if not player:
		return

	var direction = player.global_position - global_position
	direction.y = 0
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = target_rotation

func attack_player():
	if not can_attack or not player:
		return

	can_attack = false

	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
		print("Enemy: Attacked player for ", attack_damage, " damage!")

	# Attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	if current_state != State.DEAD:
		can_attack = true

func take_damage(amount: float):
	if current_state == State.DEAD:
		return

	health -= amount
	print("Enemy: Took ", amount, " damage! Health: ", health, "/", max_health)

	# Flash red to indicate damage
	flash_damage()

	# Aggro on player if not already
	if current_state == State.IDLE:
		current_state = State.CHASE

	# Check for death
	if health <= 0:
		die()

func flash_damage():
	damage_flash_timer = 0.15  # Flash for 150ms
	apply_flash_material(self)

func apply_flash_material(node: Node):
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		var flash_mat = StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1.0, 0.2, 0.2)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0.0, 0.0)
		flash_mat.emission_energy_multiplier = 2.0
		mesh_inst.material_override = flash_mat

	for child in node.get_children():
		apply_flash_material(child)

func reset_materials():
	reset_materials_recursive(self)

func reset_materials_recursive(node: Node):
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		mesh_inst.material_override = null

	for child in node.get_children():
		reset_materials_recursive(child)

func die():
	current_state = State.DEAD
	print("Enemy: DEFEATED!")

	# Disable hitbox
	if hitbox:
		hitbox.set_deferred("monitoring", false)

	# Play death animation (don't loop it)
	play_animation("death")
	# Clear the loop metadata so death doesn't loop
	set_meta("anim_end_time", anim_length + 10.0)  # Effectively disable looping

	# Wait for death animation to play
	var death_duration = anim_death_end - anim_death_start
	await get_tree().create_timer(death_duration).timeout

	# Death effect - scale down
	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 0.1, 0.5)
	await tween.finished

	# Hide after shrink
	visible = false

	# Respawn after delay
	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn():
	# Reset state
	health = max_health
	current_state = State.IDLE
	can_attack = true
	current_anim_state = ""  # Reset animation state so idle can play

	# Re-enable hitbox
	if hitbox:
		hitbox.monitoring = true

	# Reset scale to original
	scale = Vector3(0.01, 0.01, 0.01)  # Original enemy scale

	# Spawn at random position near player
	if player:
		var angle = randf() * TAU
		var distance = randf_range(15, 25)
		var spawn_offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		global_position = player.global_position + spawn_offset

		# Update height to terrain
		if terrain_manager and terrain_manager.has_method("get_height_at_position"):
			var terrain_height = terrain_manager.get_height_at_position(global_position)
			global_position.y = terrain_height + 0.1

	# Show enemy again
	visible = true

	# Grow back in (reverse of death shrink)
	scale = Vector3(0.001, 0.001, 0.001)  # Start tiny
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.5)

	# Start idle animation
	play_animation("idle")

	print("Enemy: Respawned at ", global_position, " with ", health, " HP")

# Play a specific animation segment from the combined "allanims"
func play_animation(anim_name: String):
	if not animation_player or current_anim == "":
		return

	# Don't restart if already playing this animation
	if current_anim_state == anim_name:
		return

	current_anim_state = anim_name

	var start_time: float = 0.0
	var end_time: float = 1.0

	match anim_name:
		"idle":
			start_time = anim_idle_start
			end_time = anim_idle_end
		"walk":
			start_time = anim_walk_start
			end_time = anim_walk_end
		"run":
			start_time = anim_run_start
			end_time = anim_run_end
		"attack":
			start_time = anim_attack_start
			end_time = anim_attack_end
		"death":
			start_time = anim_death_start
			end_time = anim_death_end

	# Play the animation from the start position
	animation_player.play(current_anim)
	animation_player.seek(start_time, true)

	# Store the end time for looping
	set_meta("anim_end_time", end_time)
	set_meta("anim_start_time", start_time)

func _on_animation_finished(anim_name: String):
	# This won't trigger for combined anims - we handle looping in _process
	pass

func find_animation_player(root_node: Node) -> AnimationPlayer:
	# Iteratively search for AnimationPlayer (avoid deep recursion)
	var queue: Array = [root_node]

	while queue.size() > 0:
		var node = queue.pop_back()
		if not node or not is_instance_valid(node):
			continue

		if node is AnimationPlayer:
			return node

		for child in node.get_children():
			queue.push_back(child)

	return null
