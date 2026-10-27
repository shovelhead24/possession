extends Node3D
const Ring=preload("res://world/terrain_drive_ring.gd")
const Store=preload("res://world/grass_paint_store.gd")
const CELL=32.0
const LIMIT=50000
var store=Store.new()
var arena: Node3D
var names=["clump-a","clump-b","wheat"]
var meshes=[]
var cells={}
var batches={}
var occupied={}
var dirty={}
var queue=[]
var visited={}
var settings={}
var last_point=Vector2(INF,INF)
var released=false
var save_requested=false
var clock=0.0
func setup(owner_arena):
	arena=owner_arena
	store.path=arena.painted_trees.store.path+".grass.json";store.base=arena.source.base_hash
	for i in 3:
		var mesh=load("res://assets/showcases/grass-card-"+str(i)+".res").duplicate()
		var mat=mesh.surface_get_material(0).duplicate();mesh.surface_set_material(0,mat)
		arena.showcases.register_wind(mat);meshes.append(mesh)
	arena.showcases.set_wind_preset(arena.showcases.wind_preset);arena.showcases.set_wind_direction(30)
	store.load_saved(names,true);reindex()
static func height_spread(density: float) -> float:
	return lerpf(.10,.55,clampf((density-10.0)/390.0,0.0,1.0))
func busy():return store.active
func cell_at(record):return Vector2i(floori(record.x/CELL),floori(record.z/CELL))
func occupancy(point: Vector2):return Vector2i((point/.35).floor())
func reindex():
	cells.clear();occupied.clear()
	for record in store.records:
		var cell=cell_at(record)
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(record);occupied[occupancy(Vector2(record.x,record.z))]=true
	for cell in batches:dirty[cell]=true
	for cell in cells:dirty[cell]=true
	clock=0
func begin_paint(world_point: Vector3, options: Dictionary) -> bool:
	if busy() or arena.destruction.busy():store.notice="Wait for the current stroke / terrain update.";return false
	store.begin();settings=options.duplicate();visited.clear();queue.clear();released=false;last_point=Vector2(INF,INF)
	store.notice="Drag to paint grass. Release to finish one undoable stroke.";enqueue(world_point);return true
func enqueue(world_point: Vector3):
	if not store.active or released:return
	var c=Ring.coordinates(world_point);var point=Vector2(c.x,c.z)
	var step=maxf(.5,settings.radius*.4)
	if last_point.is_finite():
		var distance=last_point.distance_to(point)
		if distance<step:return
		for i in range(1,ceili(distance/step)+1):enqueue_dab(last_point.lerp(point,minf(1,float(i)*step/distance)),c.y)
	else:enqueue_dab(point,c.y)
	last_point=point
func enqueue_dab(point: Vector2, height: float):
	var spacing=sqrt(100.0/settings.density)
	var low=Vector2i(((point-Vector2.ONE*settings.radius)/spacing).floor())
	var high=Vector2i(((point+Vector2.ONE*settings.radius)/spacing).ceil())
	queue.append({"point":point,"height":height,"spacing":spacing,"low":low,"high":high,"x":low.x,"z":low.y})
func release():released=true
func erase_dab(point: Vector2):
	var keep=[]
	for record in store.records:
		if Vector2(record.x,record.z).distance_to(point)>settings.radius:keep.append(record)
	store.records=keep;reindex()
func _physics_process(_delta):
	if not store.active or arena.destruction.busy():return
	for attempt in 64:
		if queue.is_empty():break
		var dab=queue[0]
		if settings.erase:erase_dab(dab.point);queue.pop_front();break
		var grid=Vector2i(dab.x,dab.z);dab.x+=1
		if dab.x>dab.high.x:dab.x=dab.low.x;dab.z+=1
		if dab.z>dab.high.y:queue.pop_front()
		if visited.has(grid):continue
		visited[grid]=true
		var rng=RandomNumberGenerator.new();rng.seed=hash(grid)
		var point=(Vector2(grid)+Vector2(rng.randf_range(.15,.85),rng.randf_range(.15,.85)))*dab.spacing
		if point.distance_to(dab.point)>settings.radius or occupied.has(occupancy(point)):continue
		if store.records.size()>=LIMIT:queue.clear();released=true;store.notice="Grass limit reached (50,000 clumps).";break
		var estimate=Ring.point(point.x,dab.height,point.y);var up=Ring.up_at(estimate)
		var hit=arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(estimate+up*40,estimate-up*80,1))
		if hit.is_empty() or hit.normal.dot(up)<.55:continue
		var c=Ring.coordinates(hit.position)
		var variation=height_spread(settings.density)
		var height=clampf(settings.height*rng.randf_range(1.0-variation,1.0+variation),.05,5.0)
		var species=rng.randi_range(0,2) if settings.species<0 else settings.species
		var record={"id":store.next_id,"x":c.x,"y":c.y,"z":c.z,"height":height,"yaw":rng.randf_range(-PI,PI),"species":names[species]}
		store.next_id+=1;store.records.append(record);occupied[occupancy(point)]=true
		var cell=cell_at(record)
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(record);dirty[cell]=true
	if released and queue.is_empty():
		store.finish();store.notice="%d grass clumps. Stroke complete." % store.records.size()
		if save_requested:save_requested=false;store.save()
func _process(delta):
	if not arena:return
	clock-=delta
	if clock>0:return
	clock=.2
	var c=Ring.coordinates(arena.camera.global_position);var centre=Vector2(c.x,c.z)
	var wanted={}
	var low=Vector2i(((centre-Vector2.ONE*220)/CELL).floor());var high=Vector2i(((centre+Vector2.ONE*220)/CELL).floor())
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			var cell=Vector2i(x,y)
			if cells.has(cell):wanted[cell]=true
	for cell in batches.keys():
		if not wanted.has(cell) or dirty.has(cell):
			for batch in batches[cell]:batch.queue_free()
			batches.erase(cell)
	var built=0
	for cell in wanted:
		if batches.has(cell):continue
		build_cell(cell);dirty.erase(cell);built+=1
		if built>=4:break
func build_cell(cell):
	var anchor=Ring.point((cell.x+.5)*CELL,cells[cell][0].y,(cell.y+.5)*CELL);batches[cell]=[]
	for species in 3:
		var records=cells[cell].filter(func(r):return r.species==names[species])
		if records.is_empty():continue
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=meshes[species];mm.instance_count=records.size()
		for i in records.size():
			var r=records[i];var point=Ring.point(r.x,r.y,r.z)
			var basis=Ring.tangent_basis(point,r.yaw).scaled(Vector3.ONE*r.height/1.2)
			mm.set_instance_transform(i,Transform3D(basis,point-anchor))
			mm.set_instance_custom_data(i,Color(fposmod(r.id*.6180339,1),0,0,1))
		var batch=MultiMeshInstance3D.new();batch.multimesh=mm;add_child(batch);batch.global_position=anchor
		batch.visibility_range_end=200;batch.extra_cull_margin=2;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batches[cell].append(batch)
func request_save():
	if busy():save_requested=true;release()
	else:store.save()
func undo_paint():store.undo();reindex()
func redo_paint():store.redo();reindex()
func load_paint():store.load_saved(names);reindex()
