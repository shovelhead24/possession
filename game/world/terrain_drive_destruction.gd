extends Node
const Cuts = preload("res://world/terrain_drive_cuts.gd")
const Ring = preload("res://world/terrain_drive_ring.gd")
const Recipe = preload("res://world/sdf_recipe.gd")
const Compact = preload("res://world/terrain_drive_recipe.gd")
const SAVE_PATH := "user://terrain-drive-edits.json"
var arena: Node3D
var cuts: Array=[]
var pending: Array=[]
var worker: Thread
var prepared: Array=[]
var results: Array=[]
var activate := false
var completed := 0
var revision := 0
var applied_revision := 0
var undo_stack: Array=[]
var redo_stack: Array=[]
var replacement: Array=[]
var replacing := false
var remember_replacement := true
var notice := "Ready"
var saved_signature := "[]"
var current_signature := "[]"
var save_path := SAVE_PATH
var edit_cache := preload("res://world/terrain_drive_edit_cache.gd").new()
var stroke_serial := 0
var last_history_group := -1
var last_worker_ms := 0.0
var job_started := 0
var last_update_ms := 0.0
var publications := 0

func begin_stroke() -> int:
	stroke_serial+=1;return stroke_serial

func busy() -> bool:
	return replacing or not pending.is_empty() or worker!=null or not results.is_empty() or not prepared.is_empty()

func unsaved() -> bool:
	return busy() or current_signature!=saved_signature

func signature(features: Array) -> String:
	# JSON reloads numbers as floats. Canonicalise that representation once per
	# revision, retaining full precision rather than treating 1 and 1.0 as edits.
	return JSON.stringify(JSON.parse_string(JSON.stringify(features,"",true,true)),"",true,true)

func keys_for(features: Array) -> Array:
	var found := {}
	for feature in features:
		var bounds := Cuts.edit_bounds(feature)
		var lo := Vector2i((bounds.position/200).floor());var hi := Vector2i((bounds.end/200).floor())
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1): found[Vector2i(x,z)]=true
	return found.keys()

func valid_features(features: Array) -> bool:
	if not Recipe.validate(Recipe.document(features)): return false
	for f in features:
		if f.kind not in ["hill","lower","tunnel","mountain","carve"] or f.radius>120 or f.height>128: return false
		if f.kind in ["hill","lower"] and (not f.has("amount") or f.amount>100000): return false
		if f.kind=="tunnel":
			if not f.has("end_x") or Vector3(f.x,f.y,f.z).distance_to(Vector3(f.end_x,f.end_y,f.end_z))>512: return false
	return true

func request(point: Vector3, radius: float) -> bool:
	if not point.is_finite() or radius<1 or radius>4: return false
	var feature := Recipe.feature("carve",Ring.coordinates(point));feature.radius=radius
	return request_feature(feature)

func request_feature(feature: Dictionary, stroke_id := 0) -> bool:
	if replacing:
		notice="Edit queue is full; wait for the current update.";return false
	if not valid_features([feature]): notice="Unsupported tool settings.";return false
	for key in keys_for([feature]):
		if not arena.tile_entries.has(key): notice="Move closer and wait for terrain to load.";return false
	# Pending doses of the same stroke/footprint are one request, not an
	# ever-growing FIFO of identical SDF shapes while the worker catches up.
	var incoming := feature.duplicate(true);incoming._stroke_id=stroke_id
	if feature.kind in ["hill","lower"] and feature.has("amount"):
		for i in range(pending.size()-1,-1,-1):
			var old: Dictionary=pending[i]
			if old.get("_stroke_id",0)!=stroke_id or old.kind not in ["hill","lower"]: break
			var merged := Compact.compact([old,incoming])
			if merged.size()==1:
				merged[0]._stroke_id=stroke_id;pending[i]=merged[0];return true
	if pending.size()>=32 or Compact.compact(cuts+pending+[incoming]).size()>2048:
		notice="Edit queue is full; stroke samples are waiting.";return false
	pending.append(incoming);notice="Updating terrain…"
	return true

func replace_features(next: Array, remember := true) -> bool:
	if busy(): notice="Wait for the terrain update to finish.";return false
	if not valid_features(next): notice="Invalid terrain recipe; current terrain retained.";return false
	replacement=next.duplicate(true);replacing=true;remember_replacement=remember
	notice="Updating terrain…";return true

func undo() -> void:
	if busy(): notice="Wait for the terrain update to finish.";return
	if undo_stack.is_empty(): notice="Nothing to undo.";return
	redo_stack.append(cuts.duplicate(true));replace_features(undo_stack.pop_back(),false)

func redo() -> void:
	if busy(): notice="Wait for the terrain update to finish.";return
	if redo_stack.is_empty(): notice="Nothing to redo.";return
	undo_stack.append(cuts.duplicate(true));replace_features(redo_stack.pop_back(),false)

func save_edits() -> bool:
	if busy(): notice="Wait for the terrain update before saving.";return false
	var document := {"schema":1,"frame":"terrain-drive-ring-metres","base":arena.source.base_hash,"features":cuts}
	var file := FileAccess.open(save_path+".pending",FileAccess.WRITE)
	if not file: notice="Save failed: could not write the pending file.";return false
	file.store_string(JSON.stringify(document,"\t",true,true));file.flush()
	var error := file.get_error();file.close()
	if error!=OK: notice="Save failed while writing; previous save retained.";return false
	if FileAccess.file_exists(save_path):
		if DirAccess.copy_absolute(save_path,save_path+".bak")!=OK:
			notice="Save failed: could not back up the previous save.";return false
	if DirAccess.rename_absolute(save_path+".pending",save_path)!=OK:
		notice="Save failed: could not install the new save.";return false
	saved_signature=current_signature;notice="Saved %d terrain edits." % cuts.size();return true

func load_edits(initial := false) -> bool:
	if busy(): notice="Wait for the terrain update before loading.";return false
	if not FileAccess.file_exists(save_path): notice="No saved terrain yet.";return false
	var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not document is Dictionary or document.get("schema")!=1 or document.get("frame")!="terrain-drive-ring-metres" or document.get("base")!=arena.source.base_hash or not document.get("features") is Array:
		notice="Save is invalid or belongs to another terrain; current terrain retained.";return false
	if not valid_features(document.features): notice="Save contains invalid tools; current terrain retained.";return false
	var loaded := Compact.compact(document.features)
	if initial:
		cuts=loaded;completed=cuts.size();current_signature=signature(cuts)
	else:
		replace_features(loaded)
	saved_signature=signature(loaded)
	notice="Loaded %d terrain edits." % loaded.size();return true

func apply(data: Dictionary, key: Vector2i) -> Dictionary:
	if cuts.is_empty(): return data
	return edit_cache.build(arena.source,key,cuts,data)

func build(keys: Array) -> Array:
	var started := Time.get_ticks_usec()
	var output := []
	for key in keys:
		var data: Dictionary=edit_cache.build(arena.source,key,cuts)
		data.key=key;output.append(data)
	last_worker_ms=(Time.get_ticks_usec()-started)/1000.0
	return output

func _process(_delta: float) -> void:
	if not arena or not arena.ready_to_play or activate: return
	if not results.is_empty():
		var data: Dictionary=results.pop_front()
		var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_INDEX]=data.indices
		var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],data.render_lods)
		var visual := MeshInstance3D.new();visual.mesh=mesh;visual.material_override=arena.material
		visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;visual.hide();arena.add_child(visual)
		var body := StaticBody3D.new();body.collision_layer=0;body.collision_mask=0
		var shape := CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);arena.add_child(body)
		prepared.append({"key":data.key,"visual":visual,"body":body})
		if results.is_empty(): activate=true
		return
	if worker:
		if worker.is_alive(): return
		results=worker.wait_to_finish();worker=null;return
	var stream: Node=arena.streamer
	if (pending.is_empty() and not replacing) or (stream and (stream.worker or not stream.stage.is_empty() or not stream.publish.is_empty())): return
	var batch := []
	var group := int(pending[0].get("_stroke_id",0)) if not pending.is_empty() else 0
	if not replacing:
		while not pending.is_empty() and int(pending[0].get("_stroke_id",0))==group: batch.append(pending.pop_front())
	var affected := cuts.duplicate() if replacing else batch.duplicate()
	var next := replacement if replacing else Compact.compact(cuts+batch)
	if (replacing and remember_replacement) or (not replacing and (group==0 or group!=last_history_group)):
		undo_stack.append(cuts.duplicate(true));redo_stack.clear()
		if undo_stack.size()>64: undo_stack.pop_front()
	last_history_group=group if not replacing else -1
	if replacing: affected.append_array(next)
	cuts=next.duplicate(true);current_signature=signature(cuts);replacement=[];replacing=false;revision+=1
	var keys := []
	for key in keys_for(affected):
		if arena.tile_entries.has(key): keys.append(key)
	if keys.is_empty(): completed=cuts.size();applied_revision=revision;notice="Terrain ready.";return
	job_started=Time.get_ticks_usec();worker=Thread.new()
	if worker.start(build.bind(keys))!=OK:
		worker=null;push_error("Terrain edit worker could not start")
		notice="Terrain worker failed; reload the last save."

func _physics_process(_delta: float) -> void:
	if not activate: return
	# All seam neighbours are registered before changing visible/physical ownership.
	for entry in prepared:
		var old: Dictionary=arena.tile_entries[entry.key]
		old.body.collision_layer=0;old.body.collision_mask=0
		old.visual.hide();arena.tiles.erase(old.visual)
		old.visual.queue_free();old.body.queue_free()
		entry.body.collision_layer=1;entry.body.collision_mask=1;entry.visual.show()
		arena.tile_entries[entry.key]={"visual":entry.visual,"body":entry.body}
		arena.tiles.append(entry.visual)
	prepared.clear();activate=false;completed=cuts.size();applied_revision=revision;notice="Terrain ready."
	last_update_ms=(Time.get_ticks_usec()-job_started)/1000.0;publications+=1

func _exit_tree() -> void:
	if worker: worker.wait_to_finish()
