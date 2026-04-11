extends Area3D

@export var impact_sound: AudioStream
var velocity = Vector3.ZERO
var speed = 50.0
var damage = 25

func _ready():
	# Connect collision signals
	#if self is Area3D:
	body_entered.connect(_on_body_entered)
		#area_entered.connect(_on_area_entered) 
		#optional if we want area3d entered collisions
	#elif self is RigidBody3D:
		# For RigidBody3D, you need to use different signals
		#contact_monitor = true
		#max_contacts_reported = 10
		#body_entered.connect(_on_body_entered)
		
	# Auto-destroy after 5 seconds if no collision
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta):
	# Move the bullet
	position += velocity * delta

func _on_body_entered(body):
	#dont collide with player
	if body.name == "Player":
		return
	# Deal damage if the body has a take_damage method
	if body.has_method("take_damage"):
		body.take_damage(damage)
	print("Bullet hit: ", body.name)
	create_impact_effect()
	# Delete the bullet
	queue_free()
func create_impact_effect():
# Play impact sound at bullet's position
	if impact_sound:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = impact_sound
		audio_player.position = global_position
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.volume_db = -5
		
		# Add to scene at root level so it persists after bullet is freed
		get_tree().root.add_child(audio_player)
		audio_player.play()
		
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
		
