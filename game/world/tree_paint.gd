extends "res://world/tree_patch.gd"
const Store = preload("res://world/tree_paint_store.gd")
var store := Store.new()
var by_id := {}
var occupied := {}
var queue: Array=[]
var visited := {}
var released := false
var last_point := Vector2(INF,INF)
var settings := {}
var save_requested := false
const CELL_SIZE := 96.0
const VIEW_RADIUS := 650.0
const RETAIN_MARGIN := 96.0
const ACTIVATE_PER_TICK := 64
var cells := {} # Persistent placement metadata; no geometry or physics bodies.
var records_by_id := {}
var record_indices := {}
var active_cells := {}
var activation_queue: Array=[]
var activation_head := 0
var stream_clock := 0.0
var last_stream_checks := 0
var stream_retirement_scan_required := true
var stream_retirement_scan_count := 0
var weapon_max_height := 0.0
var density_field: RefCounted

func prepare_density() -> void:
	density_field=preload("res://world/tree_density_field.gd").new()
	density_field.configure(names,foliage_budget.radii)
	density_field.sync(store.records,false)
	if not density_field.load_cache(store.path+".density.json"): density_field.flush()
	foliage_budget.authored_field=density_field
	dirty=true

func bake_density() -> bool:
	if busy(): store.notice="Finish the tree stroke before baking.";return false
	density_field.sync(store.records)
	var ok=density_field.save_cache(store.path+".density.json")
	store.notice="Density cache baked for %d authored trees." % store.records.size() if ok else "Density cache write failed."
	return ok


func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	variants=arena.trees.variants;names=variants.keys();count_limit=0;checks_per_tick=32;retire_empty_batches=true
	store.base=arena.source.base_hash
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-paint-file="): store.path=arg.trim_prefix("--tree-paint-file=")
	store.load_saved(names,true);sync_records()

func sync_records() -> void:
	if density_field: density_field.sync(store.records)
	cells.clear();records_by_id.clear();record_indices.clear();occupied.clear()
	for index in store.records.size(): index_record(store.records[index],index)
	for id in by_id.keys():
		if not records_by_id.has(id): retire_item(id);continue
		var record: Dictionary=records_by_id[id]
		var item: Dictionary=by_id[id]
		if item.point!=Vector2(record.x,record.z) or item.variant!=names.find(record.species) or not is_equal_approx(item.height,record.height) or not is_equal_approx(item.yaw,record.yaw): retire_item(id)
	active_cells.clear();activation_queue.clear();activation_head=0
	# The previous stream set is being discarded; surviving instances need a
	# retirement pass even if the newly computed wanted set is also empty.
	stream_retirement_scan_required=true
	refresh_stream();activate_pending();rebuild_candidates();update_batches()

func index_record(record: Dictionary, index: int) -> void:
	if density_field: density_field.upsert(record)
	weapon_max_height=maxf(weapon_max_height,record.height)
	var point := Vector2(record.x,record.z)
	var cell := Vector2i((point/CELL_SIZE).floor())
	if not cells.has(cell): cells[cell]={}
	cells[cell][record.id]=record;records_by_id[record.id]=record;record_indices[record.id]=index
	var space := Vector2i((point/3.0).floor())
	if not occupied.has(space): occupied[space]=[]
	occupied[space].append(point)

func retire_item(id: int) -> void:
	var item: Dictionary=by_id[id]
	if is_instance_valid(item.body): item.body.queue_free()
	by_id.erase(id);dirty=true

func rebuild_candidates() -> void:
	candidates.assign(by_id.values());count_limit=candidates.size();cursor=cursor%maxi(1,count_limit)

func weapon_candidates(start: Vector3, end: Vector3, margin: float=0.0) -> Array:
	# Ring coordinates stay fixed when terrain regrounds a tree. Reuse the existing
	# placement cells and return live items, so edits/stream retirement stay current.
	var centre := (start+end)*.5
	var coord := Ring.coordinates(centre)
	var radius := start.distance_to(end)+weapon_max_height*.044+1.0+margin
	var ring_radius: float=Ring.Frame.CIRCUMFERENCE/TAU
	# Radial trunks do not lean along the arc. Inflate by twice their radius
	# plus 1 m for float error. The 2x arc bound holds outside half-radius.
	if absf(coord.y)+radius+weapon_max_height>ring_radius*.5: return candidates
	var result := [];var seen := {}
	for shift in [-Ring.Frame.CIRCUMFERENCE,0.0,Ring.Frame.CIRCUMFERENCE]:
		var point := Vector2(coord.x+shift,coord.z)
		var low := Vector2i(((point-Vector2.ONE*radius)/CELL_SIZE).floor())
		var high := Vector2i(((point+Vector2.ONE*radius)/CELL_SIZE).floor())
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				for id in cells.get(Vector2i(x,y),{}):
					var record: Dictionary=cells[Vector2i(x,y)][id]
					if absf(record.x-point.x)>radius or absf(record.z-point.y)>radius: continue
					if by_id.has(id) and not seen.has(id): result.append(by_id[id]);seen[id]=true
	return result

func stream_centres() -> Array:
	var result := []
	for pair in [[arena.camera.global_position,VIEW_RADIUS],[arena.vehicle_kit.car.global_position,100.0]]:
		var coord := Ring.coordinates(pair[0]);result.append([Vector2(coord.x,coord.z),pair[1]])
	var foot: Node=arena.get("on_foot")
	if foot and foot.active:
		var coord := Ring.coordinates(foot.global_position);result.append([Vector2(coord.x,coord.z),100.0])
	# The ring coordinate seam joins +half circumference to -half circumference.
	var circumference: float=Ring.Frame.CIRCUMFERENCE
	for centre in result.duplicate():
		if absf(centre[0].x)>circumference*.5-VIEW_RADIUS-RETAIN_MARGIN-CELL_SIZE:
			result.append([centre[0]-Vector2(signf(centre[0].x)*circumference,0),centre[1]])
	return result

func cell_distance(cell: Vector2i, point: Vector2) -> float:
	var low := Vector2(cell)*CELL_SIZE
	return point.distance_to(point.clamp(low,low+Vector2.ONE*CELL_SIZE))

func refresh_stream() -> void:
	var wanted := {};var retired := false;last_stream_checks=0
	var centres := stream_centres()
	if enabled:
		for centre in centres:
			var radius: float=centre[1]
			var low := Vector2i(((centre[0]-Vector2.ONE*radius)/CELL_SIZE).floor())
			var high := Vector2i(((centre[0]+Vector2.ONE*radius)/CELL_SIZE).floor())
			for z in range(low.y,high.y+1):
				for x in range(low.x,high.x+1):
					var cell := Vector2i(x,z);last_stream_checks+=1
					if cells.has(cell) and cell_distance(cell,centre[0])<=radius: wanted[cell]=true
		# Retain already loaded cells slightly farther out to avoid boundary churn.
		for cell in active_cells:
			for centre in centres:
				if cell_distance(cell,centre[0])<=centre[1]+RETAIN_MARGIN: wanted[cell]=true;break
	if wanted!=active_cells or stream_retirement_scan_required:
		stream_retirement_scan_count+=1
		for id in by_id.keys():
			var cell := Vector2i((by_id[id].point/CELL_SIZE).floor())
			if not wanted.has(cell): retire_item(id);retired=true
		# Every remaining live instance is now in a wanted cell. Activation below
		# only adds items after checking active_cells, so this remains true until
		# a paint insertion outside the active set or a stream reset.
		stream_retirement_scan_required=false
	if wanted!=active_cells:
		# Replace obsolete work on teleports; nearby cells are activated first.
		activation_queue.clear();activation_head=0
		var ordered := wanted.keys()
		ordered.sort_custom(func(a,b): return priority_distance(a,centres)<priority_distance(b,centres))
		for cell in ordered:
			for id in cells[cell]:
				if not by_id.has(id): activation_queue.append(id)
	active_cells=wanted
	if retired: rebuild_candidates()

func priority_distance(cell: Vector2i, centres: Array) -> float:
	var distance := INF
	for centre in centres: distance=minf(distance,cell_distance(cell,centre[0]))
	return distance

func activate_pending() -> void:
	var changed := false
	for attempt in ACTIVATE_PER_TICK:
		if activation_head>=activation_queue.size(): break
		var id: int=activation_queue[activation_head];activation_head+=1
		if by_id.has(id) or not records_by_id.has(id): continue
		var record: Dictionary=records_by_id[id]
		var cell := Vector2i((Vector2(record.x,record.z)/CELL_SIZE).floor())
		if not active_cells.has(cell): continue
		by_id[id]=make_item(record);changed=true
	if activation_head>=activation_queue.size(): activation_queue.clear();activation_head=0
	if changed: rebuild_candidates();dirty=true

func remove_record(id: int) -> void:
	if density_field: density_field.remove(id)
	var record: Dictionary=records_by_id[id];var point := Vector2(record.x,record.z)
	var cell := Vector2i((point/CELL_SIZE).floor());cells[cell].erase(id)
	if cells[cell].is_empty(): cells.erase(cell);active_cells.erase(cell)
	var space := Vector2i((point/3.0).floor());occupied[space].erase(point)
	if occupied[space].is_empty(): occupied.erase(space)
	var index: int=record_indices[id];var last: Dictionary=store.records.back()
	store.records[index]=last;record_indices[last.id]=index;store.records.pop_back()
	record_indices.erase(id);records_by_id.erase(id)
	if by_id.has(id): retire_item(id)

func erase_dab(point: Vector2, radius: float) -> bool:
	var removed := []
	var low := Vector2i(((point-Vector2.ONE*radius)/CELL_SIZE).floor())
	var high := Vector2i(((point+Vector2.ONE*radius)/CELL_SIZE).floor())
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for record in cells.get(Vector2i(x,z),{}).values():
				if Vector2(record.x,record.z).distance_squared_to(point)<=radius*radius: removed.append(record.id)
	for id in removed: remove_record(id)
	return not removed.is_empty()

func set_enabled(value: bool) -> void:
	super.set_enabled(value)
	activation_queue.clear();activation_head=0
	if value:
		active_cells.clear();stream_retirement_scan_required=true
	refresh_stream();activate_pending();rebuild_candidates();update_batches()

func status() -> String:
	return super.status()+" | saved %d / active cells %d / queued %d" % [store.records.size(),active_cells.size(),activation_queue.size()-activation_head]

func make_item(record: Dictionary) -> Dictionary:
	return {"id":record.id,"point":Vector2(record.x,record.z),"variant":names.find(record.species),"height":record.height,"yaw":record.yaw,"transform":Transform3D.IDENTITY,"lod":-1,"valid":false,"body_id":0,"revision":-1,"body":null}

func busy() -> bool:
	return store.active

func begin_paint(world_point: Vector3, options: Dictionary) -> bool:
	if busy(): store.notice="Finishing the previous tree stroke…";return false
	if arena.destruction.busy(): store.notice="Wait for the terrain update.";return false
	if not enabled: set_enabled(true);arena.trees.set_enabled(true)
	store.begin();settings=options.duplicate();visited.clear();queue.clear();released=false
	store.notice="Drag on terrain. Release to finish one undoable stroke."
	last_point=Vector2(INF,INF);enqueue(world_point);return true

func enqueue(world_point: Vector3) -> void:
	if not store.active or released: return
	var coordinate := Ring.coordinates(world_point);var point := Vector2(coordinate.x,coordinate.z)
	var step: float=maxf(1,settings.radius*.4)
	if last_point.is_finite():
		var distance := last_point.distance_to(point)
		if distance<step: return
		var start := last_point
		for i in range(1,ceili(distance/step)+1): enqueue_dab(start.lerp(point,minf(1,float(i)*step/distance)))
	else: enqueue_dab(point)
	last_point=point

func enqueue_dab(point: Vector2) -> void:
	var spacing: float=sqrt(100.0/settings.density)
	var low := Vector2i(((point-Vector2.ONE*settings.radius)/spacing).floor())
	var high := Vector2i(((point+Vector2.ONE*settings.radius)/spacing).ceil())
	queue.append({"point":point,"spacing":spacing,"low":low,"high":high,"x":low.x,"z":low.y})

func release() -> void:
	released=true

func register_painted_item(record: Dictionary, item: Dictionary) -> void:
	index_record(record,store.records.size());store.records.append(record);store.next_id+=1
	by_id[record.id]=item
	# Paint hits can be up to 800 m from the camera, beyond VIEW_RADIUS.
	# Preserve the next refresh's retirement behavior for such placements.
	if not active_cells.has(Vector2i((item.point/CELL_SIZE).floor())): stream_retirement_scan_required=true

func _physics_process(delta: float) -> void:
	stream_clock-=delta
	if stream_clock<=0: stream_clock=.2;refresh_stream()
	activate_pending()
	if store.active and not arena.destruction.busy():
		var changed := false
		for attempt in 32:
			if queue.is_empty(): break
			var dab: Dictionary=queue[0]
			if settings.erase:
				changed=erase_dab(dab.point,settings.radius) or changed;queue.pop_front();break
			var cell := Vector2i(dab.x,dab.z)
			dab.x+=1
			if dab.x>dab.high.x: dab.x=dab.low.x;dab.z+=1
			if dab.z>dab.high.y: queue.pop_front()
			if visited.has(cell): continue
			var rng := RandomNumberGenerator.new();rng.seed=hash(cell)^8102026
			var point: Vector2=(Vector2(cell)+Vector2(.5+rng.randf_range(-.3,.3),.5+rng.randf_range(-.3,.3)))*dab.spacing
			if point.distance_squared_to(dab.point)>settings.radius*settings.radius: continue
			visited[cell]=true
			if crowded(point): continue
			var terrain_key := Vector2i((point/200.0).floor())
			if not arena.tile_entries.has(terrain_key): continue
			var variant: int=settings.species if settings.species>=0 else rng.randi_range(0,names.size()-1)
			var record := {"id":store.next_id,"x":float(point.x),"z":float(point.y),"height":float(settings.height*rng.randf_range(.8,1.2)),"yaw":float(rng.randf()*TAU),"species":names[variant]}
			var item := make_item(record);ground(item)
			if not item.valid: continue
			item.body_id=arena.tile_entries[terrain_key].body.get_instance_id();item.revision=0
			register_painted_item(record,item);changed=true

		if changed:
			rebuild_candidates();dirty=true
		if queue.is_empty() and released:
			store.finish();store.notice="%d painted trees. Stroke complete." % store.records.size()
	if density_field and not density_field.pending.is_empty(): density_field.flush();dirty=true
	if save_requested and not busy():
		save_requested=false
		if store.save() and density_field:
			if not density_field.save_cache(store.path+".density.json"): store.notice+=" Density cache write failed; rebuilt next load."
	super._physics_process(delta)

func crowded(point: Vector2) -> bool:
	var cell := Vector2i((point/3.0).floor())
	for z in range(cell.y-1,cell.y+2):
		for x in range(cell.x-1,cell.x+2):
			for other: Vector2 in occupied.get(Vector2i(x,z),[]):
				if point.distance_squared_to(other)<9: return true
	return false

func request_save() -> void:
	release();save_requested=true

func undo_paint() -> void:
	if busy(): release();store.notice="Finishing stroke; undo when ready.";return
	store.undo();sync_records()

func redo_paint() -> void:
	if busy(): return
	store.redo();sync_records()

func load_paint() -> void:
	if busy(): release();store.notice="Finishing stroke; load when ready.";return
	if store.load_saved(names): sync_records()
