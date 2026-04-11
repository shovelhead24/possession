extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 8.0
const SENSITIVITY = 0.003

# Bullet variables
@export var bullet_scene: PackedScene  # Drag Bullet.tscn here in inspector
@export var bullet_speed = 50.0
@export var shoot_cooldown = 0.2  # Time between shots
@export var hud_scene: PackedScene

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_shoot = true

@onready var camera = $Camera3D

@onready var shoot_sound = $Plasma_rifle_sound

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
# Load HUD scene if not assigned in inspector
	if not hud_scene:
		# Try to load HUD scene from common paths
		if ResourceLoader.exists("res://HUD.tscn"):
			hud_scene = preload("res://HUD.tscn")
		elif ResourceLoader.exists("res://HUD.tscn"):
			hud_scene = preload("res://HUD.tscn")
		else:
			push_error("HUD scene not found! Please assign it in the inspector or create HUD.tscn")
	
	# Only instantiate HUD if we have a valid scene
	if hud_scene:
		var hud_instance = hud_scene.instantiate()
		get_parent().add_child.call_deferred(hud_instance)
		await get_tree().process_frame
		
		# Setup crosshair if it exists
		var reticle = hud_instance.get_node_or_null("Crosshair")
		if reticle:
			var viewport_center = get_viewport().get_visible_rect().size / 2
			reticle.position = viewport_center
	
	
	# Load bullet scene if not assigned in inspector
	if not bullet_scene:
		bullet_scene = preload("res://Bullet.tscn")

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)
	
	# Add shooting
	if event.is_action_pressed("shoot") and can_shoot:
		shoot()
	
	# Release mouse
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# full auto shooting
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()
	
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

func shoot():
	if not can_shoot or not bullet_scene:
		return
		
	can_shoot = false
	#play plasma rifle sound
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()
	# Create bullet
	var bullet = bullet_scene.instantiate()
		# Add bullet to parent
	get_parent().add_child(bullet)
	
	#Now set Spawn position at hand position
	var bullet_offset = Vector3(0.2, -0.2, -0.5) # Right down forward
	var spawn_position = global_position + global_transform.basis * bullet_offset
	
	# Cast ray from camera through center of screen (where crosshair is)
	var viewport_center = get_viewport().get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(viewport_center)
	var ray_end = ray_origin + camera.project_ray_normal(viewport_center) * 1000
	
	# Perform raycast to see what camera is pointing at
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]  # Don't hit yourself
	query.collision_mask = 0xFFFFFFFF # Hit everything
	var result = space_state.intersect_ray(query)
	
	# Determine target point
	var target_point
	if result:
		print("Hit: ", result.collider.name, " at ", result.position)
		target_point = result.position # Hit something aim there
	else:
		print("No hit, aiming far")
		target_point = ray_end # Didn't hit anything, aim far away
	
	# Set position and rotation BEFORE adding to tree
	bullet.global_position = spawn_position
	
	# Calculate direction and set rotation
	var direction = (target_point - spawn_position).normalized()
	bullet.global_transform.basis = Basis.looking_at(direction, Vector3.UP)
	
	
	
	
	# Make bullet look at target
	#bullet.look_at(target_point, Vector3.UP)
	
	# Add bullet to the scene root (better than adding to parent)
	#get_tree().root.add_child(bullet)
	
	
	# Position bullet at camera position, slightly forward
	#bullet.global_position = camera.global_position + (-camera.global_transform.basis.z * 0.5)
	
	# Set bullet velocity in camera's forward direction
	if bullet.has_method("set_velocity"):
		bullet.set_velocity(direction * bullet_speed)
	else:
		# Direct property access if bullet uses velocity variable
		bullet.velocity = direction * bullet_speed
	
	# Cooldown
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
