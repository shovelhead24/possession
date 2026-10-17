extends "res://cloud_system.gd"
## Reuse the old density, mesher and billboard shaders with bounded generation.
const Ring=preload("res://world/terrain_drive_ring.gd")
const Facing=preload("res://benchmarks/sky_before/sky_billboard_facing.gd")
var mc_enabled := false
var billboard_enabled := false
var layers_enabled := false
var pending: Array=[]
var empty_chunks := {}
var refresh := 0.0
var wind_offset := Vector2.ZERO
var horizon: Node3D

func _ready():
	_setup_noise();_setup_material()
	var shader=Shader.new()
	shader.code=FileAccess.get_file_as_string("res://cloud_shader.gdshader").replace("uniform vec2 wind_speed", "uniform vec2 cloud_offset = vec2(0.0);\nuniform vec2 wind_speed")
	shader.code=shader.code.replace("VERTEX.x += TIME * wind_speed.x;", "VERTEX.x += cloud_offset.x;").replace("VERTEX.z += TIME * wind_speed.y;", "VERTEX.z += cloud_offset.y;")
	shader.code=shader.code.replace("world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;", "world_y = VERTEX.y;\n float radius=477464.8293;\n float theta=VERTEX.x/radius;\n float radial=radius-VERTEX.y;\n VERTEX=vec3(radial*sin(theta),world_y+2.0*radial*pow(sin(theta*0.5),2.0),VERTEX.z);\n NORMAL=vec3(cos(theta)*NORMAL.x-sin(theta)*NORMAL.y,sin(theta)*NORMAL.x+cos(theta)*NORMAL.y,NORMAL.z);")
	_mat.shader=shader
	_mat.shader.code=_mat.shader.code.replace("ALBEDO =", "SPECULAR = 0.0; ROUGHNESS = 1.0;\n ALBEDO =")
	_billboard_shader=load("res://benchmarks/sky_before/sky_billboard.gdshader")
	set_process_unhandled_input(false)

func configure(mc: bool, cards: bool, layers: bool) -> void:
	mc_enabled=mc;billboard_enabled=cards;layers_enabled=layers
	if layers and _layers.is_empty(): _rebuild_layers()
	for layer in _layers: layer.visible=layers
	for coord in _chunks.keys():
		_chunks[coord].mi.free()
	_chunks.clear();empty_chunks.clear();pending.clear();refresh=0.0
	visible=mc or cards or layers
	set_process(visible)
	if cards and horizon==null:
		horizon=preload("res://benchmarks/sky_before/sky_billboard_horizon.gd").new();add_child(horizon)
	if horizon: horizon.visible=cards;horizon.set_brightness(cloud_brightness)

func _process(delta):
	if not _camera: _camera=get_viewport().get_camera_3d()
	if not _camera: return
	wind_offset+=Vector2(3.0,1.2)*delta
	_mat.set_shader_parameter("cloud_offset",wind_offset)
	var cp=Ring.coordinates(_camera.global_position)
	if billboard_enabled: horizon.update_around(_camera.global_position)
	for chunk in _chunks.values():
		if chunk.type!=1: continue
		var mi=chunk.mi
		var front=(_camera.global_position-mi.position).normalized()
		var right=Facing.right_axis(front,mi.basis.y,chunk.get("right",Vector3.ZERO),delta)
		chunk["right"]=right
		mi.material_override.set_shader_parameter("stable_right",right)
	for i in _layers.size():
		_layers[i].position=Ring.point(cp.x,CLOUD_ALTITUDES[i],cp.z)
		_layers[i].basis=Ring.tangent_basis(_layers[i].position,0.0)
	refresh-=delta
	if refresh<=0.0:
		refresh=0.5
		var centre=Vector2i(floori((cp.x-wind_offset.x)/CHUNK_XZ),floori((cp.z-wind_offset.y)/CHUNK_XZ))
		var desired={}
		pending.clear()
		for z in range(-12,13):
			for x in range(-12,13):
				var key=centre+Vector2i(x,z)
				var distance=Vector2((key.x+0.5)*CHUNK_XZ+wind_offset.x-cp.x,(key.y+0.5)*CHUNK_XZ+wind_offset.y-cp.z).length()
				var kind=0 if mc_enabled and distance<2400.0 else 1
				if kind==1 and (not billboard_enabled or distance>6500.0): continue
				if kind==1 and _noise.get_noise_2d(key.x*711.0,key.y*711.0)<-0.05: continue
				if absf((key.y+0.5)*CHUNK_XZ)>24500.0: continue
				desired[key]=kind
				if _chunks.has(key) and _chunks[key].type!=kind:
					_chunks[key].mi.free();_chunks.erase(key)
				if not _chunks.has(key) and not empty_chunks.has(key): pending.append({"key":key,"kind":kind,"distance":distance})
		for key in _chunks.keys():
			if not desired.has(key): _chunks[key].mi.free();_chunks.erase(key)
		for key in empty_chunks.keys():
			if not desired.has(key): empty_chunks.erase(key)
		pending.sort_custom(func(a,b): return a.distance<b.distance)
	# At most one expensive marching-cubes chunk per frame, or 12 cheap cards.
	for i in 12:
		if pending.is_empty(): break
		var item=pending.pop_front();var key=item.key
		if item.kind==0:
			_spawn_chunk(key,0)
			if _chunks.has(key):
				_chunks[key].mi.custom_aabb=AABB(Vector3(-700000,-700000,-700000),Vector3(1400000,1400000,1400000))
			else: empty_chunks[key]=true
			break
		else:
			_spawn_chunk_billboard(key,1)
			var mi=_chunks[key].mi
			var rng=RandomNumberGenerator.new()
			rng.seed=int(key.x)*73856093 ^ int(key.y)*19349663 ^ 9271
			mi.position=Ring.point((key.x+rng.randf_range(0.08,0.92))*CHUNK_XZ,rng.randf_range(850.0,1550.0),(key.y+rng.randf_range(0.08,0.92))*CHUNK_XZ)
			mi.basis=Ring.tangent_basis(mi.position,0.0)
			mi.mesh.size=Vector2(rng.randf_range(520.0,1150.0),rng.randf_range(230.0,520.0))
			mi.material_override.set_shader_parameter("shape_seed",rng.randf_range(0.0,500.0))
			mi.material_override.set_shader_parameter("cloud_brightness",cloud_brightness)
			var right=Facing.right_axis((_camera.global_position-mi.position).normalized(),mi.basis.y,Vector3.ZERO,0.0)
			_chunks[key]["right"]=right
			mi.material_override.set_shader_parameter("use_stable_right",true)
			mi.material_override.set_shader_parameter("stable_right",right)
			mi.material_override.set_shader_parameter("distance_fade",Vector4(0,0,5000,6500))
			# Shader-facing geometry can extend outside the original thin-quad AABB.
			var radius=mi.mesh.size.length()*0.5
			mi.custom_aabb=AABB(-Vector3.ONE*radius,Vector3.ONE*radius*2.0)

var cloud_brightness := 1.0

func set_brightness(value: float) -> void:
	cloud_brightness=value
	if horizon: horizon.set_brightness(value)
	set_cloud_brightness(value)
	_mat.set_shader_parameter("color_top",Color(1,1,1)*value)
	_mat.set_shader_parameter("color_bottom",Color(0.62,0.68,0.74)*value)
	for chunk in _chunks.values():
		if chunk.type==1: chunk.mi.material_override.set_shader_parameter("cloud_brightness",value)

func _marching_cubes(grid: PackedFloat32Array,nx: int,ny: int,nz: int,ox: float,oy: float,oz: float,sx: float,sy: float,sz: float) -> ArrayMesh:
	var mesh=super._marching_cubes(grid,nx,ny,nz,ox,oy,oz,sx,sy,sz)
	if mesh==null: return null
	var arrays=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals=PackedVector3Array();normals.resize(vertices.size())
	var cache={}
	# Density gradients remain continuous across faces and separate chunk meshes.
	var e=4.0
	for i in vertices.size():
		var p=vertices[i]
		if not cache.has(p):
			var gradient=Vector3(_sample(p.x+e,p.y,p.z)-_sample(p.x-e,p.y,p.z),_sample(p.x,p.y+e,p.z)-_sample(p.x,p.y-e,p.z),_sample(p.x,p.y,p.z+e)-_sample(p.x,p.y,p.z-e))
			cache[p]=-gradient.normalized() if gradient.length_squared()>0.00000001 else Vector3.UP
		normals[i]=cache[p]
	arrays[Mesh.ARRAY_NORMAL]=normals
	var smooth=ArrayMesh.new();smooth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return smooth

func status() -> String:
	return "%d cloud chunks, %d pending" % [_chunks.size(),pending.size()]
