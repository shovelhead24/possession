extends Node3D
## Six depth-tested translucent cards, not volumetric scattering.
var arena: Node3D
var enabled := false
var occluded := false
var clock := 0.0
var strength := 0.0
var shafts: MultiMeshInstance3D
var material: ShaderMaterial
func setup(owner_arena: Node3D):
	arena=owner_arena;process_priority=105
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	shafts=MultiMeshInstance3D.new();add_child(shafts)
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=QuadMesh.new();mm.instance_count=6
	shafts.multimesh=mm;shafts.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://world/performance_light_shafts.gdshader");shafts.material_override=material
	shafts.hide()
func _process(delta: float):
	shafts.position=Vector3.ZERO
	if not enabled:
		shafts.hide();strength=0.0;return
	var camera: Camera3D=arena.camera
	var sun: Vector3=arena.daylight.sun.global_basis.z.normalized()
	var up: Vector3=preload("res://world/terrain_drive_ring.gd").up_at(camera.global_position)
	clock-=delta
	if clock<=0:
		clock=.1
		var query=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+sun*1500.0,7)
		occluded=not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var target=clampf((-camera.global_basis.z).dot(sun),0.0,1.0)
	target=smoothstep(.65,.95,target)*clampf(sun.dot(up)*8.0,0.0,1.0)*minf(1.0,arena.daylight.sun.light_energy)
	if occluded:target=0.0
	strength=move_toward(strength,target,delta*3.0)
	shafts.visible=strength>.001
	material.set_shader_parameter("strength",strength)
	var color: Color=arena.daylight.sun.light_color
	material.set_shader_parameter("shaft_color",Vector3(color.r,color.g,color.b))
	var front=-sun;var right=up.cross(front).normalized()
	if right.length_squared()<.01:right=camera.global_basis.x
	var vertical=front.cross(right).normalized()
	var centre=camera.global_position+sun*85.0
	for i in 6:
		var x=(float(i)-2.5)*12.0
		var start=centre+right*(float(i)-2.5)*1.5
		var end=centre+right*x-vertical*(55.0+float(i%3)*7.0)
		var along=(start-end).normalized()
		var across=along.cross(front).normalized()
		shafts.multimesh.set_instance_transform(i,Transform3D(Basis(across*(10.0+float(i%2)*4.0),along*start.distance_to(end),front),(start+end)*.5))
