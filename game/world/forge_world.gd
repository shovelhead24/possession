extends Node3D
const Parts=preload("res://world/forge_parts.gd")
const Store=preload("res://world/forge_store.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
const CELL := 128.0
var store := Store.new()
var arena: Node3D
var cells := {}
var by_id := {}
var batches := {}
var uploaded := {}
var bodies := {}
var materials: Array[StandardMaterial3D]=[]
var revision := -1
var clock := 0.0
var last_camera := Vector3(INF,INF,INF)
var hidden_ids: Array=[]
var last_hidden := []
var active_count := 0
var update_ms := 0.0
var collision_queue: Array=[]

func origin_shifted(delta: Vector3):
	last_camera=Vector3.INF;uploaded.clear()

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	store.base=arena.source.identity
	store.path=OS.get_user_data_dir().get_base_dir().path_join("Rebuild Demo/construction.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forge-file="): store.path=arg.trim_prefix("--forge-file=")
	for color in Parts.COLORS:
		var material := StandardMaterial3D.new();material.albedo_color=color;material.roughness=.85
		materials.append(material)
	store.load_saved(true);reindex()

static func collision_stamp(record: Dictionary) -> String:
	return JSON.stringify([record.kind,record.p,record.b])

func reindex() -> void:
	cells.clear();by_id.clear()
	for record in store.records:
		var key := Vector2i(floori(record.p[0]/CELL),floori(record.p[2]/CELL))
		if not cells.has(key): cells[key]=[]
		cells[key].append(record.id);by_id[record.id]=record
	revision=store.revision
	for id in bodies.keys():
		if not by_id.has(id) or bodies[id].get_meta("forge_stamp","")!=collision_stamp(by_id[id]):
			bodies[id].free();bodies.erase(id)
	last_camera=Vector3(INF,INF,INF)

func nearby(point: Vector3, radius: float) -> Array:
	var coord := Ring.coordinates(point);var result := [];var visited := {}
	var c := Vector2(coord.x,coord.z);var low := Vector2i(((c-Vector2.ONE*radius)/CELL).floor());var high := Vector2i(((c+Vector2.ONE*radius)/CELL).floor())
	for x in range(low.x,high.x+1):
		for z in range(low.y,high.y+1):
			# Search both seam images: ring circumference is not a cell multiple.
			for shift in [0.0,-3000000.0,3000000.0]:
				var key := Vector2i(floori((x*CELL+shift)/CELL),z)
				for offset in [0,1] if shift!=0 else [0]:
					for id in cells.get(key+Vector2i(offset,0),[]):
						if not visited.has(id): result.append(id);visited[id]=true
	return result

func _physics_process(delta: float) -> void:
	if not arena or not arena.ready_to_play: return
	clock-=delta
	if clock<=0:
		clock=.2
		var started := Time.get_ticks_usec()
		if revision!=store.revision: reindex()
		var camera: Vector3=arena.camera.global_position
		if camera.distance_squared_to(last_camera)>4 or hidden_ids!=last_hidden:
			update_visuals(camera);last_camera=camera;last_hidden=hidden_ids.duplicate()
		update_collision(camera)
		update_ms=(Time.get_ticks_usec()-started)/1000.0
	for i in mini(12,collision_queue.size()):
		var id: int=collision_queue.pop_front()
		if not bodies.has(id) and by_id.has(id) and id not in hidden_ids: create_body(by_id[id])

func update_visuals(camera: Vector3) -> void:
	var groups := {};active_count=0
	for id in nearby(camera,700):
		if id in hidden_ids: continue
		var record: Dictionary=by_id[id];var transform := Store.pose(record)
		var distance := transform.origin.distance_to(camera)
		if distance>650: continue
		var cell := Vector2i(floori(record.p[0]/CELL),floori(record.p[2]/CELL))
		var key := "%s/%s/%s/%s" % [cell,record.kind,record.finish,int(distance<140)]
		if not groups.has(key): groups[key]={"record":record,"shadow":distance<140,"poses":[]}
		groups[key].poses.append(transform);active_count+=1
	for key in batches.keys():
		if not groups.has(key): batches[key].free();batches.erase(key);uploaded.erase(key)
	for key in groups:
		var group: Dictionary=groups[key]
		if not batches.has(key):
			var node := MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			node.multimesh.mesh=Parts.get_part(group.record.kind).mesh;node.material_override=materials[group.record.finish]
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node);batches[key]=node
		if uploaded.get(key,[])==group.poses: continue
		batches[key].position=Vector3.ZERO
		uploaded[key]=group.poses
		var mm: MultiMesh=batches[key].multimesh;mm.instance_count=group.poses.size()
		for i in group.poses.size(): mm.set_instance_transform(i,group.poses[i])

func update_collision(camera: Vector3) -> void:
	var anchors: Array=[arena.vehicle_kit.car.global_position]
	if arena.on_foot and arena.on_foot.active: anchors.append(arena.on_foot.global_position)
	var editor_open: bool=arena.editor and arena.editor.opened
	if editor_open: anchors.append(camera)
	var wanted := {}
	for anchor in anchors:
		var radius := 220.0 if editor_open and anchor==camera else 120.0
		for id in nearby(anchor,radius+20):
			if id in hidden_ids: continue
			var record: Dictionary=by_id[id];var p := Store.pose(record).origin
			var tile := Vector2i(floori(record.p[0]/200),floori(record.p[2]/200))
			if p.distance_squared_to(anchor)<radius*radius and arena.tile_entries.has(tile): wanted[id]=true
	for id in bodies.keys():
		if not wanted.has(id): bodies[id].free();bodies.erase(id)
	collision_queue.clear()
	for id in wanted:
		if not bodies.has(id): collision_queue.append(id)

func create_body(record: Dictionary) -> void:
	var body := StaticBody3D.new();body.collision_layer=2;body.collision_mask=3;body.set_meta("forge_id",record.id);body.set_meta("forge_stamp",collision_stamp(record))
	for piece in Parts.get_part(record.kind).pieces:
		var shape := CollisionShape3D.new();shape.shape=piece.shape;shape.transform=piece.pose;body.add_child(shape)
	add_child(body);body.transform=Store.pose(record);bodies[record.id]=body

func ray_pick(excluded: Array=[]) -> Dictionary:
	var mouse := arena.get_viewport().get_mouse_position()
	var origin: Vector3=arena.camera.project_ray_origin(mouse)
	var direction: Vector3=arena.camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*220,3)
	var ignored: Array[RID]=[]
	for id in excluded:
		if bodies.has(id): ignored.append(bodies[id].get_rid())
	query.exclude=ignored
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): hit["id"]=int(hit.collider.get_meta("forge_id",0))
	return hit

func clear_placement(items: Array, excluded: Array) -> bool:
	var ignored: Array[RID]=[]
	for id in excluded:
		if bodies.has(id): ignored.append(bodies[id].get_rid())
	for item in items:
		for piece in Parts.get_part(item.kind).pieces:
			var query := PhysicsShapeQueryParameters3D.new();query.shape=piece.shape
			query.transform=Store.pose(item)*piece.pose
			query.transform.basis=query.transform.basis.scaled(Vector3.ONE*.995)
			query.collision_mask=3;query.exclude=ignored;query.margin=0
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true

func status() -> String:
	return "Construction: %d parts / %d visible / %d batches / %d colliders · F1 → Construction" % [store.records.size(),active_count,batches.size(),bodies.size()]




func refresh_geometry() -> void:
	Parts.cache.clear()
	for node in batches.values(): node.free()
	for body in bodies.values(): body.free()
	batches.clear();uploaded.clear();bodies.clear();collision_queue.clear()
	reindex();update_visuals(arena.camera.global_position);update_collision(arena.camera.global_position)
	# Rebuild the previously resident support before returning to simulation.
	for id in collision_queue:
		if by_id.has(id): create_body(by_id[id])
	collision_queue.clear()

func overlapping_snap_target(pose: Transform3D, size: Vector3, excluded: Array, camera: Vector3) -> Dictionary:
	var best := INF;var result := {}
	for id in nearby(pose.origin,size.length()*.5+30.0):
		if id in excluded or not by_id.has(id): continue
		var record: Dictionary=by_id[id];var target := Store.pose(record);var target_size: Vector3=Parts.get_part(record.kind).size
		if not Parts.boxes_overlap(pose,size,target,target_size): continue
		var local := target.basis.inverse()*(pose.origin-target.origin)
		var normalized := local/(target_size*.5)
		var axis := normalized.abs().max_axis_index()
		var normal := target.basis[axis]*(1 if local[axis]>=0 else -1)
		var face := Parts.face_center(target,target_size,normal)
		var distance := camera.distance_squared_to(face)
		if distance>=best: continue
		best=distance;result={"id":id,"position":pose.origin,"normal":normal}
	return result
