extends Node3D
## Bounded Compatibility-renderer precipitation preview; no per-drop collisions.
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var enabled := false
var intensity := 0.0
var wind := 0.0
var sheltered := false
var particles: CPUParticles3D
var material: ShaderMaterial
var sample_clock := 0.0
var shelter_hits := 0
var ground_known := false

func setup(owner_arena: Node3D) -> void:
	set_meta("floating_origin_root",true)
	arena=owner_arena
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	particles=CPUParticles3D.new();particles.emitting=false;particles.amount=650
	particles.lifetime=1.3;particles.local_coords=true;particles.fixed_fps=30
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents=Vector3(8,0.2,8)
	particles.position=Vector3(0,7,0);particles.spread=3.0
	particles.gravity=Vector3.ZERO
	particles.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY,true)
	var mesh := BoxMesh.new();mesh.size=Vector3(0.016,0.22,0.016)
	material=ShaderMaterial.new();material.shader=preload("res://world/performance_rain.gdshader")
	mesh.material=material;particles.mesh=mesh
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	add_child(particles);particles.hide()
	# Seed properties vary by particle backend; set only if this runtime exposes them.
	var properties := {}
	for entry in particles.get_property_list(): properties[entry.name]=true
	if properties.has("use_fixed_seed") and properties.has("seed"):
		particles.set("use_fixed_seed",true);particles.set("seed",1947)
	set_process(false);set_physics_process(false)

func origin_shifted(delta: Vector3):
	var ground=material.get_shader_parameter("ground_origin")
	if ground is Vector3:material.set_shader_parameter("ground_origin",ground-delta)
	sample_clock=0

func configure(amount: float, wind_strength: float) -> void:
	var was_enabled := enabled
	intensity=clampf(amount,0,1);wind=clampf(wind_strength,0,1);enabled=intensity>0.001
	if not particles: return
	# Keep the particle budget stable during animated showers: changing amount
	# restarts CPUParticles3D. Opacity carries continuous rainfall intensity.
	particles.direction=Vector3(wind*0.65,-1,wind*0.2).normalized()
	particles.initial_velocity_min=lerpf(8,15,intensity)
	particles.initial_velocity_max=lerpf(10,18,intensity)
	particles.scale_amount_min=lerpf(0.5,0.85,intensity);particles.scale_amount_max=lerpf(0.75,1.2,intensity)
	material.set_shader_parameter("opacity",lerpf(0.04,0.34,intensity)*smoothstep(0.0,0.08,intensity))
	set_process(enabled);set_physics_process(enabled)
	if enabled and not was_enabled:
		sample_clock=0
		follow_camera()
		# Hold emission until the first physics-space shelter/ground check.
		particles.emitting=false;particles.hide()
	elif not enabled:
		particles.emitting=false;particles.hide();sheltered=false;shelter_hits=0

func follow_camera() -> void:
	if not arena or not arena.camera: return
	global_transform=Transform3D(Ring.tangent_basis(arena.camera.global_position,0),arena.camera.global_position)

func _process(_delta: float) -> void:
	follow_camera()

func _physics_process(delta: float) -> void:
	if not enabled or not arena or not arena.ready_to_play: return
	sample_clock-=delta
	if sample_clock>0: return
	sample_clock=0.25
	var position: Vector3=arena.camera.global_position
	var up: Vector3=Ring.up_at(position)
	var right: Vector3=Ring.spinward_at(position)
	var lateral := Vector3.BACK
	var excluded: Array[RID]=[]
	if arena.get("on_foot") and is_instance_valid(arena.on_foot): excluded.append(arena.on_foot.get_rid())
	if arena.get("vehicle_kit"):
		for vehicle in arena.vehicle_kit.vehicles:
			if is_instance_valid(vehicle): excluded.append(vehicle.get_rid())
	var space := get_world_3d().direct_space_state
	shelter_hits=0
	var centre_blocked := false
	for offset in [Vector3.ZERO,right*0.6,-right*0.6,lateral*0.6,-lateral*0.6]:
		var ray := PhysicsRayQueryParameters3D.create(position+offset+up*0.05,position+offset+up*35,3)
		ray.exclude=excluded;ray.hit_back_faces=true;ray.hit_from_inside=true
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			shelter_hits+=1
			if offset==Vector3.ZERO: centre_blocked=true
	sheltered=centre_blocked or shelter_hits>=3
	# A conservative sampled floor clips drops before they pass through terrain.
	# This is deliberately an approximation, not a rain collision simulation.
	var highest := -INF
	for offset in [Vector3.ZERO,right*7,-right*7,lateral*7,-lateral*7]:
		var ray := PhysicsRayQueryParameters3D.create(position+offset+up*8,position+offset-up*40,1)
		ray.exclude=excluded
		var hit := space.intersect_ray(ray)
		if not hit.is_empty(): highest=maxf(highest,(hit.position-position).dot(up))
	ground_known=is_finite(highest)
	material.set_shader_parameter("ground_known",ground_known)
	material.set_shader_parameter("ground_up",up)
	material.set_shader_parameter("ground_origin",position+up*(highest if ground_known else -40.0))
	particles.visible=not sheltered;particles.emitting=not sheltered

func status() -> String:
	return "Rain off" if not enabled else ("Rain sheltered" if sheltered else "Rain %.0f%% / wind %.0f%%" % [intensity*100,wind*100])
