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

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	variants=arena.trees.variants;names=variants.keys();count_limit=0;checks_per_tick=32;retire_empty_batches=true
	store.base=arena.source.base_hash
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-paint-file="): store.path=arg.trim_prefix("--tree-paint-file=")
	store.load_saved(names,true);sync_records()

func sync_records() -> void:
	var next := {};candidates.clear();occupied.clear()
	for record in store.records:
		var item: Dictionary=by_id[record.id] if by_id.has(record.id) else make_item(record)
		# Reloaded records may reuse IDs with different transforms/species.
		if item.point!=Vector2(record.x,record.z) or item.variant!=names.find(record.species) or not is_equal_approx(item.height,record.height) or not is_equal_approx(item.yaw,record.yaw):
			if is_instance_valid(item.body): item.body.queue_free()
			item=make_item(record)
		next[record.id]=item;candidates.append(item)
		var cell := Vector2i((item.point/3.0).floor())
		if not occupied.has(cell): occupied[cell]=[]
		occupied[cell].append(item.point)
	for id in by_id:
		if not next.has(id) and is_instance_valid(by_id[id].body): by_id[id].body.queue_free()
	by_id=next;count_limit=candidates.size();cursor=0;dirty=true
	update_batches()

func make_item(record: Dictionary) -> Dictionary:
	return {"point":Vector2(record.x,record.z),"variant":names.find(record.species),"height":record.height,"yaw":record.yaw,"transform":Transform3D.IDENTITY,"lod":-1,"valid":false,"body_id":0,"revision":-1,"body":null}

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

func _physics_process(delta: float) -> void:
	if store.active and not arena.destruction.busy():
		var changed := false
		for attempt in 32:
			if queue.is_empty(): break
			var dab: Dictionary=queue[0]
			if settings.erase:
				var kept := []
				for record in store.records:
					if Vector2(record.x,record.z).distance_squared_to(dab.point)>settings.radius*settings.radius: kept.append(record)
				changed=changed or kept.size()!=store.records.size();store.records=kept;queue.pop_front();break
			var cell := Vector2i(dab.x,dab.z)
			dab.x+=1
			if dab.x>dab.high.x: dab.x=dab.low.x;dab.z+=1
			if dab.z>dab.high.y: queue.pop_front()
			if visited.has(cell): continue
			var rng := RandomNumberGenerator.new();rng.seed=hash(cell)^8102026
			var point: Vector2=(Vector2(cell)+Vector2(.5+rng.randf_range(-.3,.3),.5+rng.randf_range(-.3,.3)))*dab.spacing
			if point.distance_squared_to(dab.point)>settings.radius*settings.radius: continue
			visited[cell]=true
			if store.records.size()>=Store.LIMIT: store.notice="4096 painted-tree limit reached.";queue.clear();released=true;break
			if crowded(point): continue
			var terrain_key := Vector2i((point/200.0).floor())
			if not arena.tile_entries.has(terrain_key): continue
			var variant: int=settings.species if settings.species>=0 else rng.randi_range(0,names.size()-1)
			var record := {"id":store.next_id,"x":float(point.x),"z":float(point.y),"height":float(settings.height*rng.randf_range(.8,1.2)),"yaw":float(rng.randf()*TAU),"species":names[variant]}
			var item := make_item(record);ground(item)
			if not item.valid: continue
			item.body_id=arena.tile_entries[terrain_key].body.get_instance_id();item.revision=0
			store.records.append(record);store.next_id+=1;by_id[record.id]=item;candidates.append(item);count_limit=candidates.size()
			var space_cell := Vector2i((point/3.0).floor())
			if not occupied.has(space_cell): occupied[space_cell]=[]
			occupied[space_cell].append(point);changed=true
		if changed:
			if settings.erase: sync_records()
			else: dirty=true
		if queue.is_empty() and released:
			store.finish();store.notice="%d painted trees. Stroke complete." % store.records.size()
	if save_requested and not busy(): save_requested=false;store.save()
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
