extends Node3D
const Ring=preload("res://world/terrain_drive_ring.gd")
const ShaderSource=preload("res://world/sky_billboard.gdshader")
var last_centre := Vector2(INF,INF)
var batches: Array[MultiMeshInstance3D]=[]
var brightness := 1.0
var signed_counts := Vector2i.ZERO

func update_around(camera_position: Vector3) -> void:
	var cp=Ring.coordinates(camera_position)
	var centre=Vector2(cp.x,cp.z)
	if centre.distance_to(last_centre)<1500.0: return
	last_centre=centre;signed_counts=Vector2i.ZERO
	for batch in batches: batch.free()
	batches.clear()
	# Both spinward and antispinward use the same world-anchored grids.
	build_tier(cp,1700.0,5000.0,34000.0,Vector4(5000,7000,27000,34000))
	build_tier(cp,5000.0,25000.0,125000.0,Vector4(25000,33000,105000,125000))

func build_tier(cp: Vector3,step: float,near_range: float,far_range: float,fade: Vector4) -> void:
	var transforms: Array[Transform3D]=[]
	var colors: Array[Color]=[]
	var bounds=AABB();var first=true
	for x in range(floori((cp.x-far_range)/step),ceili((cp.x+far_range)/step)+1):
		for z in range(ceili(-23000.0/step),floori(23000.0/step)+1):
			var rng=RandomNumberGenerator.new();rng.seed=x*73856093 ^ z*19349663 ^ int(step)*9271
			if rng.randf()<0.25: continue
			var arc=(x+rng.randf_range(-0.4,0.4))*step
			var lat=clampf((z+rng.randf_range(-0.4,0.4))*step,-23500.0,23500.0)
			var distance=Vector2(arc-cp.x,lat-cp.z).length()
			if distance<near_range or distance>far_range: continue
			var pos=Ring.point(arc,rng.randf_range(850.0,1550.0),lat)
			var width=rng.randf_range(650.0,1400.0) if step<5000 else rng.randf_range(1100.0,2300.0)
			var height=rng.randf_range(250.0,550.0) if step<5000 else rng.randf_range(350.0,700.0)
			var basis=Ring.tangent_basis(pos,0)
			basis.x*=width;basis.y*=height
			transforms.append(Transform3D(basis,pos));colors.append(Color(rng.randf(),0,0,1))
			var radius=Vector2(width,height).length()*0.5
			var box=AABB(pos-Vector3.ONE*radius,Vector3.ONE*radius*2.0)
			bounds=box if first else bounds.merge(box);first=false
			if arc<cp.x: signed_counts.x+=1
			else: signed_counts.y+=1
	var material=ShaderMaterial.new();material.shader=ShaderSource
	material.set_shader_parameter("instance_seed",true)
	material.set_shader_parameter("distance_fade",fade)
	material.set_shader_parameter("cloud_brightness",brightness)
	var quad=QuadMesh.new();quad.size=Vector2.ONE
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=quad
	mm.instance_count=transforms.size();mm.custom_aabb=bounds
	for i in transforms.size(): mm.set_instance_transform(i,transforms[i]);mm.set_instance_custom_data(i,colors[i])
	var node=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	add_child(node);batches.append(node)

func set_brightness(value: float) -> void:
	brightness=value
	for batch in batches: batch.material_override.set_shader_parameter("cloud_brightness",value)
