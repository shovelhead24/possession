extends Node
## Pick the displayed ring triangles, then provide a bounded collision neighborhood.
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var faces=PackedVector3Array()
var pickers: Array=[]
var support: StaticBody3D
var centre=Vector3(INF,INF,INF)
var initialized=false
var regions: Array=[]
var test_pads: Dictionary={}

func origin_shifted(delta: Vector3):
	centre-=delta
	for region in regions:region.centre-=delta
	for key in test_pads:test_pads[key]-=delta

func test_pad(near_origin: bool=false) -> Vector3:
	if test_pads.has(near_origin):return test_pads[near_origin]
	var arc=0.0 if near_origin else -809197.144
	var lateral=0.0 if near_origin else -8685.961
	var height=300.0
	if not near_origin:
		for x in [-300.0,0.0,300.0]:
			for z in [-300.0,0.0,300.0]:height=maxf(height,arena.backdrop._far_terrain_h(arc+x,lateral+z)+100.0)
	var point=Ring.point(arc,height,lateral)
	var basis=Ring.tangent_basis(point,0)
	var vertices=PackedVector3Array()
	for v in [Vector3(-300,0,-300),Vector3(-300,0,300),Vector3(300,0,-300),Vector3(300,0,-300),Vector3(-300,0,300),Vector3(300,0,300)]:vertices.append(basis*v)
	var body=StaticBody3D.new();body.position=point;body.collision_layer=1;body.collision_mask=0
	var shape=CollisionShape3D.new();var collision=BoxShape3D.new();collision.size=Vector3(600,2,600)
	shape.shape=collision;shape.transform=Transform3D(basis,-basis.y);body.add_child(shape)
	var mesh=ArrayMesh.new();var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([basis.y,basis.y,basis.y,basis.y,basis.y,basis.y])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual=MeshInstance3D.new();visual.mesh=mesh
	var material=ShaderMaterial.new();var shader=Shader.new()
	shader.code="shader_type spatial; render_mode cull_disabled; void fragment(){ vec2 p=fract(UV*60.0); float line=step(0.96,max(p.x,p.y)); ALBEDO=mix(vec3(0.22,0.25,0.28),vec3(0.7,0.75,0.8),line); ROUGHNESS=1.0; }"
	material.shader=shader;visual.material_override=material;body.add_child(visual);arena.add_child(body)
	regions.append({"body":body,"centre":point,"test_pad":true});test_pads[near_origin]=point
	return point

func setup(owner_arena: Node3D):arena=owner_arena

func initialize():
	if initialized:return
	initialized=true
	for visual in [arena.backdrop._band,arena.backdrop.near_band]:
		var geometry: PackedVector3Array=visual.mesh.get_faces()
		for i in geometry.size():geometry[i]=Ring.absolute_point(visual.global_transform*geometry[i])
		faces.append_array(geometry)
		var body=StaticBody3D.new();body.collision_layer=128;body.collision_mask=0
		var shape=CollisionShape3D.new();var mesh=ConcavePolygonShape3D.new();mesh.backface_collision=true;mesh.set_faces(geometry)
		shape.shape=mesh;body.position=-Ring.offset();body.add_child(shape);arena.add_child(body);pickers.append(body)
	await get_tree().physics_frame

func pick(origin: Vector3, direction: Vector3) -> Dictionary:
	await initialize()
	var ray=PhysicsRayQueryParameters3D.create(origin,origin+direction*1200000.0,131)
	ray.exclude=[arena.on_foot.get_rid()]
	return arena.get_world_3d().direct_space_state.intersect_ray(ray)

func ready_at(point: Vector3) -> bool:
	if arena.showcases and arena.showcases.contains(point):return true
	for region in regions:
		if region.get("test_pad",false):
			var local=Ring.tangent_basis(region.centre,0).inverse()*(point-region.centre)
			if absf(local.x)<290 and absf(local.z)<290 and absf(local.y)<30:return true
			continue
		if point.distance_to(region.centre)<350.0:return true
	return false

func prepare(point: Vector3):
	if arena.showcases and arena.showcases.contains(point):return
	await initialize()
	for region in regions:
		if point.distance_to(region.centre)<150.0:return
	var local_faces=PackedVector3Array()
	# Keep entire triangles intersecting the neighborhood, matching visible geometry.
	var absolute=Ring.absolute_point(point)
	var area=AABB(absolute-Vector3.ONE*600.0,Vector3.ONE*1200.0)
	for i in range(0,faces.size(),3):
		var box=AABB(faces[i],Vector3.ZERO).expand(faces[i+1]).expand(faces[i+2])
		if not area.intersects(box.grow(.1)):continue
		# Do not put the coarse backdrop on top of authored, streamed terrain.
		var mid=(faces[i]+faces[i+1]+faces[i+2])/3.0
		if arena.tile_entries.has(arena.streamer.key_at(Ring.local_point(mid))):continue
		for j in 3:local_faces.append(faces[i+j]-absolute)
	if local_faces.is_empty():return
	var body=StaticBody3D.new();body.position=point;body.collision_layer=1;body.collision_mask=0
	var shape=CollisionShape3D.new();var mesh=ConcavePolygonShape3D.new();mesh.backface_collision=true;mesh.set_faces(local_faces)
	shape.shape=mesh;body.add_child(shape);arena.add_child(body)
	await get_tree().physics_frame
	support=body;centre=point
	regions.append({"body":body,"centre":point})
	if regions.size()>4:
		for region in regions.duplicate():
			if regions.size()<=4:break
			if region.get("test_pad",false):continue
			if region.centre.distance_to(arena.on_foot.global_position)<350 or region.centre.distance_to(arena.vehicle_kit.car.global_position)<350:continue
			region.body.queue_free();regions.erase(region)
	print("RING_LANDING_COLLISION triangles=",local_faces.size()/3," position=",Ring.coordinates(point))

var updating=false
func _process(_delta: float):
	if updating or not is_instance_valid(support) or arena.cloud_review.viewpoints.active:return
	var focus: Vector3=arena.vehicle_kit.car.global_position if arena.vehicle_kit.driving else arena.on_foot.global_position
	if not arena.vehicle_kit.driving and not arena.on_foot.active:return
	var distance=INF
	for region in regions:distance=minf(distance,focus.distance_to(region.centre))
	if distance>180.0:
		updating=true;await prepare(focus);updating=false
