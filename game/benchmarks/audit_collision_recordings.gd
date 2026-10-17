extends SceneTree
const Source=preload("res://world/terrain_baseline_source.gd")
const Cache=preload("res://world/terrain_drive_edit_cache.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
const Store=preload("res://world/forge_store.gd")
const Parts=preload("res://world/forge_parts.gd")
const SAVES="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/work/collision-saves/"
const OUTPUT="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs/collision-investigation.json"
func _initialize() -> void: run.call_deferred()
func vec(values: Array) -> Vector3: return Vector3(values[0],values[1],values[2])
func run() -> void:
	var world := Node3D.new();root.add_child(world)
	var construction: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SAVES+"construction.json"))
	for record in construction.parts:
		var body := StaticBody3D.new();body.collision_layer=2;world.add_child(body);body.transform=Store.pose(record)
		for piece in Parts.get_part(record.kind).pieces:
			var shape := CollisionShape3D.new();shape.shape=piece.shape;shape.transform=piece.pose;body.add_child(shape)
	await physics_frame;await physics_frame
	var recordings := []
	for filename in ["jitter-2026-10-10T11-51-21-319505882.jsonl","jitter-2026-10-10T11-51-58-356694795.jsonl"]:
		var rays := 0;var new_hits := 0;var old_hits := 0;var grounded := 0;var samples := 0
		var file := FileAccess.open(OS.get_user_data_dir().path_join("terrain-drive-traces/"+filename),FileAccess.READ)
		while not file.eof_reached():
			var line := file.get_line();if line.is_empty(): continue
			var row: Dictionary=JSON.parse_string(line)
			if row.event!="vehicle_samples": continue
			for sample in row.samples:
				for car in sample.vehicles:
					samples+=1
					for wheel in car.wheels:
						grounded+=int(wheel.grounded)
						if not wheel.has("ray_from"): continue
						var ray := PhysicsRayQueryParameters3D.create(vec(wheel.ray_from),vec(wheel.ray_to),1|4)
						old_hits+=int(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
						ray.collision_mask=1|2|4;new_hits+=int(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty());rays+=1
		file.close();recordings.append({"file":filename,"vehicle_samples":samples,"recorded_grounded_wheels":grounded,"replayed_rays":rays,"legacy_hits_on_saved_construction":old_hits,"new_hits_on_saved_construction":new_hits})
	var source := Source.new();source.curve_to_ring=true;assert(source.initialize())
	var cache := Cache.new();var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SAVES+"terrain-drive-edits.json"))
	var mountain := {}
	for feature in recipe.features:
		if feature.kind=="mountain": mountain=feature;break
	assert(not mountain.is_empty())
	var tiles := [];var deviations := [];var slopes := []
	for key in [Vector2i(1,1),Vector2i(2,1),Vector2i(1,2),Vector2i(2,2)]:
		var data := cache.build(source,key,recipe.features)
		var arrays := [];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_INDEX]=data.indices
		var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var collision := mesh.create_trimesh_shape();var faces := mesh.get_faces()
		tiles.append({"key":str(key),"triangles":faces.size()/3,"render_collision_faces_identical":collision.get_faces()==faces})
		for i in range(0,data.indices.size(),3):
			var a: Vector3=data.vertices[data.indices[i]];var b: Vector3=data.vertices[data.indices[i+1]];var c: Vector3=data.vertices[data.indices[i+2]]
			var centre := (a+b+c)/3;var coord := Ring.coordinates(centre);var distance := Vector2(coord.x-mountain.x,coord.z-mountain.z).length()
			if distance<mountain.radius*.8 or distance>mountain.radius*1.05: continue
			var normal := (c-a).cross(b-a).normalized();if normal.length_squared()<.5: continue
			var shade: Vector3=(data.normals[data.indices[i]]+data.normals[data.indices[i+1]]+data.normals[data.indices[i+2]]).normalized()
			deviations.append(rad_to_deg(acos(clampf(absf(normal.dot(shade)),0,1))))
			slopes.append(rad_to_deg(acos(clampf(absf(normal.dot(Ring.up_at(centre))),0,1))))
		await process_frame
	deviations.sort();slopes.sort()
	var report := {"recordings":recordings,"mountain":{"x":mountain.x,"z":mountain.z,"radius":mountain.radius,"height":mountain.height},"tiles":tiles,"outer_band_triangles":deviations.size(),"shading_vs_collision_normal_deg":{"max":deviations.back(),"p95":deviations[int(deviations.size()*.95)]},"outer_band_face_slope_deg":{"max":slopes.back(),"p95":slopes[int(slopes.size()*.95)]},"scope":"Saved snapshot only; original F8 clips are at construction near arc 0 / lateral 200, not this mountain near arc 409 / lateral 468. Near full-detail collision uses exact render triangles; smooth shading does not round physical triangle edges. Suspension uses single rays, not swept wheel volumes."}
	var output := FileAccess.open(OUTPUT,FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	print("COLLISION_AUDIT ",JSON.stringify(report));world.free();quit()
