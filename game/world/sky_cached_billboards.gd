extends Node3D
const Ring=preload("res://world/terrain_drive_ring.gd")
const Facing=preload("res://world/sky_billboard_facing.gd")
const Textures=preload("res://world/sky_cached_textures.gd")
const STEPS=[512.0,1700.0,5000.0]
const RANGES=[6500.0,34000.0,125000.0]
const FADES=[Vector4(0,0,5000,6500),Vector4(5000,7000,27000,34000),Vector4(25000,33000,105000,125000)]
const CELLS=16
const CACHE="user://sky-cloud-chunks-v1/"
var chunks={}
var wanted={}
var queue: Array=[]
var materials: Array[ShaderMaterial]=[]
var noise=FastNoiseLite.new()
var brightness=1.0
var clock=0.0
var last_camera=Vector3(INF,INF,INF)
var settle=0.0
var generated=0
var disk_hits=0
var memory_hits=0
var max_build_ms=0.0
var exclude_near=0.0

func _ready():
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.fractal_type=FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves=5;noise.frequency=0.0006;noise.seed=42
	DirAccess.make_dir_recursive_absolute(CACHE)
	for tier in 3:
		var mat=ShaderMaterial.new();mat.shader=preload("res://world/sky_cached_billboard.gdshader")
		mat.set_shader_parameter("cloud_atlas",Textures.get_atlas());mat.set_shader_parameter("geometry_oriented",tier==0)
		mat.set_shader_parameter("distance_fade",FADES[tier]);mat.set_shader_parameter("cloud_brightness",brightness)
		materials.append(mat)

func set_brightness(value: float):
	brightness=value
	for mat in materials: mat.set_shader_parameter("cloud_brightness",value)

func set_exclude_near(value: float):
	exclude_near=value
	if not materials.is_empty(): materials[0].set_shader_parameter("exclude_near",value)

func update_around(camera: Vector3,delta: float):
	clock-=delta
	if clock<=0.0:
		clock=0.5;select_chunks(camera)
	if not queue.is_empty():
		var key=queue.pop_front()
		if wanted.has(key) and not chunks.has(key): create_chunk(key,camera)
	if camera.distance_squared_to(last_camera)>0.0001: settle=2.0
	if settle>0.0:
		settle-=delta
		for key in chunks:
			if key.x==0 and wanted.has(key): orient(chunks[key],camera,delta)
	last_camera=camera

func select_chunks(camera: Vector3):
	var p=Ring.coordinates(camera);var next={};queue.clear()
	for tier in 3:
		var block=STEPS[tier]*CELLS;var radius=RANGES[tier]
		for x in range(floori((p.x-radius)/block),floori((p.x+radius)/block)+1):
			for z in range(maxi(floori((p.z-radius)/block),floori(-24500.0/block)),mini(floori((p.z+radius)/block),floori(24500.0/block))+1):
				var nearest=Vector2(clampf(p.x,x*block,(x+1)*block),clampf(p.z,z*block,(z+1)*block))
				if nearest.distance_to(Vector2(p.x,p.z))>radius+1500: continue
				var key=Vector3i(tier,x,z);next[key]=true
				if not chunks.has(key): queue.append(key)
				elif not wanted.has(key): memory_hits+=1;chunks[key].node.show();chunks[key].used=Time.get_ticks_msec();settle=2.0
	for key in chunks:
		chunks[key].node.visible=next.has(key)
	wanted=next
	queue.sort_custom(func(a,b): return a.x<b.x if a.x!=b.x else Vector2((a.y+0.5)*STEPS[a.x]*CELLS-p.x,(a.z+0.5)*STEPS[a.x]*CELLS-p.z).length_squared()<Vector2((b.y+0.5)*STEPS[b.x]*CELLS-p.x,(b.z+0.5)*STEPS[b.x]*CELLS-p.z).length_squared())
	if chunks.size()>64:
		var unused=[]
		for key in chunks:
			if not wanted.has(key): unused.append(key)
		unused.sort_custom(func(a,b): return chunks[a].used<chunks[b].used)
		while chunks.size()>64 and not unused.is_empty():
			var key=unused.pop_front();chunks[key].node.free();chunks.erase(key)

func create_chunk(key: Vector3i,camera: Vector3):
	var started=Time.get_ticks_usec()
	var path=CACHE+"%d_%d_%d.res" % [key.x,key.y,key.z]
	var mm: MultiMesh
	if FileAccess.file_exists(path): mm=ResourceLoader.load(path,"MultiMesh",ResourceLoader.CACHE_MODE_IGNORE) as MultiMesh
	if mm: disk_hits+=1
	else:
		mm=build_chunk(key);ResourceSaver.save(mm,path);generated+=1
	var node=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=materials[key.x]
	node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	var record={"node":node,"used":Time.get_ticks_msec(),"base":[],"right":[]}
	if key.x==0:
		for i in mm.instance_count: record.base.append(mm.get_instance_transform(i));record.right.append(Vector3.ZERO)
		orient(record,camera,0.0)
	chunks[key]=record
	max_build_ms=maxf(max_build_ms,(Time.get_ticks_usec()-started)/1000.0)

func build_chunk(key: Vector3i) -> MultiMesh:
	var tier=key.x;var step=STEPS[tier];var transforms=[];var seeds=[]
	var bounds=AABB();var first=true
	for x in range(key.y*CELLS,(key.y+1)*CELLS):
		for z in range(key.z*CELLS,(key.z+1)*CELLS):
			if absf((z+0.5)*step)>24500: continue
			var rng=RandomNumberGenerator.new()
			var arc: float;var lat: float;var altitude: float;var width: float;var height: float
			if tier==0:
				if noise.get_noise_2d(x*711.0,z*711.0)<-0.05: continue
				rng.seed=x*73856093 ^ z*19349663 ^ 9271
				arc=(x+rng.randf_range(0.08,0.92))*step;altitude=rng.randf_range(850,1550);lat=(z+rng.randf_range(0.08,0.92))*step
				width=rng.randf_range(520,1150);height=rng.randf_range(230,520)
			else:
				rng.seed=x*73856093 ^ z*19349663 ^ int(step)*9271
				if rng.randf()<0.25: continue
				arc=(x+rng.randf_range(-0.4,0.4))*step;lat=clampf((z+rng.randf_range(-0.4,0.4))*step,-23500,23500)
				altitude=rng.randf_range(850,1550)
				width=rng.randf_range(650,1400) if tier==1 else rng.randf_range(1100,2300)
				height=rng.randf_range(250,550) if tier==1 else rng.randf_range(350,700)
			var p=Ring.point(arc,altitude,lat);var b=Ring.tangent_basis(p,0)
			b.x*=width;b.y*=height;transforms.append(Transform3D(b,p));seeds.append(Color(0,0,0,rng.randf()))
			var r=Vector2(width,height).length()*0.5;var box=AABB(p-Vector3.ONE*r,Vector3.ONE*r*2)
			bounds=box if first else bounds.merge(box);first=false
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
	var quad=QuadMesh.new();quad.size=Vector2.ONE;mm.mesh=quad;mm.instance_count=transforms.size();mm.custom_aabb=bounds
	for i in transforms.size(): mm.set_instance_transform(i,transforms[i]);mm.set_instance_custom_data(i,seeds[i])
	return mm

func orient(record: Dictionary,camera: Vector3,delta: float):
	var mm=record.node.multimesh
	for i in record.base.size():
		var base: Transform3D=record.base[i]
		if base.origin.distance_squared_to(camera)>7500.0*7500.0: continue
		var front=(camera-base.origin).normalized()
		var right=Facing.right_axis(front,base.basis.y.normalized(),record.right[i],delta);record.right[i]=right
		mm.set_instance_transform(i,Transform3D(Basis(right*base.basis.x.length(),front.cross(right)*base.basis.y.length(),front),base.origin))

func status() -> String:
	return "%d batches / %d queued / cache %d disk + %d memory" % [wanted.size(),queue.size(),disk_hits,memory_hits]
