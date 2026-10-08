extends Node
## One primitive-array worker, paced upload/collision phases, bounded residency.
const Ring = preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var worker: Thread
var job_key := Vector2i.ZERO
var pending: Array=[]
var wanted := {}
var stage := {}
var publish := {}
var builds := 0
var hits := 0
var max_phase_ms := 0.0
var max_resident := 0
var plan_clock := 0.0
var world_bounds: Rect2
var force_starvation := false
var pause_generation := false
var cold_source: RefCounted
var last_phase := "idle"
var last_phase_ms := 0.0
var last_phase_at := 0

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;process_physics_priority=-100
	var meta: Dictionary=arena.source.metadata
	var spacing: float=meta.m_per_px
	world_bounds=Rect2(Vector2(-float(meta.camera_px[0])*spacing,-(float(meta.h)-2-float(meta.camera_px[1]))*spacing),Vector2(float(meta.w)-2,float(meta.h)-2)*spacing)
	plan()

func valid_key(key: Vector2i) -> bool:
	var rect := Rect2(Vector2(key)*200,Vector2.ONE*200)
	return world_bounds.encloses(rect.grow(1))

func key_at(point: Vector3) -> Vector2i:
	var ring_position := Ring.coordinates(point)
	return Vector2i(floori(ring_position.x/200),floori(ring_position.z/200))

func ready_at(point: Vector3) -> bool:
	if force_starvation: return false
	for offset in [Vector3(-12,0,-12),Vector3(12,0,-12),Vector3(-12,0,12),Vector3(12,0,12)]:
		if not arena.tile_entries.has(key_at(point+offset)): return false
	return true

func plan() -> void:
	if arena.destruction and arena.destruction.busy(): return
	var focus: Vector3=arena.vehicle_kit.car.position if arena.vehicle_kit.driving else arena.camera.position
	var centre := key_at(focus)
	var ring_focus := Ring.coordinates(focus)
	wanted.clear()
	for z in range(centre.y-8,centre.y+8):
		for x in range(centre.x-8,centre.x+8):
			var key := Vector2i(x,z)
			if valid_key(key): wanted[key]=true
	var car_key := key_at(arena.vehicle_kit.car.position)
	for z in range(car_key.y-1,car_key.y+2):
		for x in range(car_key.x-1,car_key.x+2):
			var key := Vector2i(x,z)
			if valid_key(key): wanted[key]=true
	pending.clear()
	for key in wanted:
		if arena.tile_entries.has(key) or (worker and key==job_key) or (not stage.is_empty() and stage.key==key) or (not publish.is_empty() and publish.key==key): continue
		pending.append(key)
	pending.sort_custom(func(a,b): return (Vector2(a)*200+Vector2.ONE*100-Vector2(ring_focus.x,ring_focus.z)).length_squared()<(Vector2(b)*200+Vector2.ONE*100-Vector2(ring_focus.x,ring_focus.z)).length_squared())
	# Remove a bounded number per planning tick; never remove the parked car's support.
	var removed := 0
	for key in arena.tile_entries.keys():
		if wanted.has(key): continue
		if arena.tile_entries.size()<400 and abs(key.x-centre.x)<=9 and abs(key.y-centre.y)<=9: continue
		var entry: Dictionary=arena.tile_entries[key]
		arena.tiles.erase(entry.visual);entry.visual.queue_free();entry.body.queue_free();arena.tile_entries.erase(key)
		removed+=1
		if removed==4: break
	max_resident=maxi(max_resident,arena.tile_entries.size())

func build(key: Vector2i) -> Dictionary:
	# Initial square retains its original cache identity even in a cold exterior test.
	var source: RefCounted=cold_source if cold_source and (key.x< -8 or key.x>=8 or key.y< -8 or key.y>=8) else arena.source
	var result: Dictionary=source.build_tile(key)
	if arena.destruction: result=arena.destruction.apply(result,key)
	# Partition complete triangles, without moving/removing any vertex. Each native
	# collision BVH can then be installed in a separate short main-thread phase.
	var groups: Array=[[],[],[],[]]
	var centre := Vector2(key)*200+Vector2.ONE*100
	for i in range(0,result.indices.size(),3):
		var a: Vector3=result.vertices[result.indices[i]]
		var b: Vector3=result.vertices[result.indices[i+1]]
		var c: Vector3=result.vertices[result.indices[i+2]]
		var mid := Ring.coordinates((a+b+c)/3)
		var group := int(mid.x>=centre.x)+2*int(mid.z>=centre.y)
		groups[group].append(a);groups[group].append(b);groups[group].append(c)
	result.face_groups=[]
	for group in groups: result.face_groups.append(PackedVector3Array(group))
	result.key=key
	return result

func _process(delta: float) -> void:
	if not arena or not arena.ready_to_play: return
	plan_clock-=delta
	if plan_clock<=0: plan_clock=.2;plan()
	if not publish.is_empty(): return
	if arena.tile_entries.size()>=400:
		plan();return # Retire expendable tiles before publishing any additional geometry.
	var started := Time.get_ticks_usec()
	if not stage.is_empty():
		if not stage.has("visual"):
			last_phase="mesh_upload"
			var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=stage.vertices;arrays[Mesh.ARRAY_NORMAL]=stage.normals;arrays[Mesh.ARRAY_INDEX]=stage.indices
			var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],stage.render_lods)
			var visual := MeshInstance3D.new();visual.mesh=mesh;visual.material_override=arena.material
			visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;visual.hide();arena.add_child(visual);stage.visual=visual
		else:
			last_phase="collision"
			if not stage.has("body"): stage.body=StaticBody3D.new();stage.next_collision=0
			var faces: PackedVector3Array=stage.face_groups[stage.next_collision]
			if not faces.is_empty():
				var shape := CollisionShape3D.new();var geometry := ConcavePolygonShape3D.new()
				geometry.set_faces(faces);shape.shape=geometry;stage.body.add_child(shape)
			stage.next_collision+=1
			if stage.next_collision==4:
				arena.add_child(stage.body)
				publish={"key":stage.key,"visual":stage.visual,"body":stage.body,"cached":stage.cached}
				stage={}
		last_phase_ms=(Time.get_ticks_usec()-started)/1000.0;last_phase_at=Time.get_ticks_usec()
		max_phase_ms=maxf(max_phase_ms,last_phase_ms)
		return
	if worker:
		if worker.is_alive(): return
		stage=worker.wait_to_finish();worker=null;return
	if not pending.is_empty() and not pause_generation and (not arena.destruction or not arena.destruction.busy()):
		job_key=pending.pop_front();worker=Thread.new()
		var error := worker.start(build.bind(job_key))
		if error!=OK: worker=null;push_error("Terrain streaming worker failed")

func _physics_process(_delta: float) -> void:
	if publish.is_empty(): return
	# Body was attached in an earlier process callback; publish readiness on a physics tick.
	arena.tile_entries[publish.key]={"visual":publish.visual,"body":publish.body}
	arena.tiles.append(publish.visual);publish.visual.show()
	max_resident=maxi(max_resident,arena.tile_entries.size())
	hits+=int(publish.cached);builds+=int(not publish.cached);publish={}

func _exit_tree() -> void:
	if worker: worker.wait_to_finish()
	if stage.has("body") and not stage.body.is_inside_tree(): stage.body.free()
