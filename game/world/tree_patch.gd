extends Node3D
## Shared tree assets, terrain grounding and spatial batches for painted placements.
const Ring = preload("res://world/terrain_drive_ring.gd")
const Assets = preload("res://world/tree_patch_assets.gd")
var arena: Node3D
var variants := {}
var names := []
var candidates: Array[Dictionary]=[]
var batches := {}
var uploaded := {}
var count_limit := 0
var enabled := true
var cursor := 0
var refresh_clock := 0.0
var counts := [0,0,0,0]
var forced_lod := -1
var update_ms := 0.0
var pending_ground := 0
var dirty := true
var last_camera := Vector3(INF,INF,INF)
var checks_per_tick := 8
var retire_empty_batches := false
var shadow_revision := 0

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	# Static instance slots change ownership when LOD buckets change. Interpolating
	# those slots would blend unrelated trees and produces streaks during swaps.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	variants=Assets.new().load_meshes();names=variants.keys()
	assert(not names.is_empty(),"Tree assets unavailable")
	print("TREE_ASSET_AUDIT ",JSON.stringify(Assets.audit(variants)))
	# Automatic demonstration placement was removed; authored trees load separately.
	count_limit=0;pending_ground=0

func _physics_process(delta: float) -> void:
	if not arena or not arena.ready_to_play or not enabled: return
	# Refresh only eight candidates/tick. Terrain body identity detects eviction,
	# reload and published edits; no world-wide re-ground on each brush sample.
	for step in mini(checks_per_tick,count_limit):
		var item: Dictionary=candidates[cursor%count_limit];cursor+=1
		var key := Vector2i((item.point/200.0).floor())
		var resident: Dictionary=arena.tile_entries.get(key,{})
		var body_id: int=resident.body.get_instance_id() if not resident.is_empty() else 0
		if body_id!=item.body_id or item.revision<0:
			dirty=true
			item.body_id=body_id;item.revision=0;item.valid=false
			if body_id!=0: ground(item)
		update_collision(item)
	refresh_clock-=delta
	if refresh_clock<=0:
		refresh_clock=.2
		if dirty or arena.camera.position.distance_squared_to(last_camera)>1.0: update_batches()

func ground(item: Dictionary) -> void:
	var point: Vector2=item.point
	var h: float=arena.source.surface_height(point)
	var estimated := Ring.point(point.x,h,point.y);var up := Ring.up_at(estimated)
	var query := PhysicsRayQueryParameters3D.create(estimated+up*250,estimated-up*250,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		# A newly published physics body may not be queryable until next tick.
		item.revision=-1;return
	if hit.normal.dot(up)<cos(deg_to_rad(38)): return
	item.transform=Transform3D(Ring.tangent_basis(hit.position,item.yaw).scaled(Vector3.ONE*item.height),hit.position-up*.08)
	item.valid=true

func update_collision(item: Dictionary) -> void:
	var near: bool=enabled and item.valid and item.transform.origin.distance_squared_to(arena.vehicle_kit.car.position)<80.0*80.0
	if not near:
		if is_instance_valid(item.body): item.body.queue_free();item.body=null
		return
	if not is_instance_valid(item.body):
		var body := StaticBody3D.new();body.collision_layer=2;body.collision_mask=2
		var shape := CollisionShape3D.new();var cylinder := CylinderShape3D.new()
		cylinder.radius=maxf(.12,item.height*.022);cylinder.height=item.height*.45
		shape.shape=cylinder;shape.position.y=cylinder.height*.5;body.add_child(shape);add_child(body);item.body=body
	var transform := Transform3D(item.transform.basis.orthonormalized(),item.transform.origin)
	if item.body.transform!=transform: item.body.transform=transform

static func choose_lod(distance: float, previous: int) -> int:
	var boundaries := [22.0,55.0,110.0]
	var desired := 0 if distance<22 else (1 if distance<55 else (2 if distance<110 else 3))
	if previous>=0 and absi(previous-desired)==1:
		var boundary: float=boundaries[mini(previous,desired)]
		if absf(distance-boundary)<4: return previous
	return desired

func update_batches() -> void:
	shadow_revision+=1
	var started := Time.get_ticks_usec();var buckets := {};counts=[0,0,0,0];pending_ground=0
	dirty=false;last_camera=arena.camera.position
	for index in count_limit:
		var item: Dictionary=candidates[index]
		if item.revision<0: pending_ground+=1
		if not item.valid or not enabled: continue
		if arena.get("edited_render_lods") and arena.edited_render_lods.is_edit_hidden(Vector2i((item.point/200.0).floor())): continue
		var distance: float=item.transform.origin.distance_to(arena.camera.position)
		if distance>650: continue
		# Approximate projected size: saplings switch earlier than tall firs.
		item.lod=forced_lod if forced_lod>=0 else choose_lod(distance*10.0/item.height,item.lod)
		var cell := Vector2i((item.point/(192.0 if item.lod==3 else 96.0)).floor())
		var key := Vector4i(cell.x,cell.y,item.variant,item.lod)
		if not buckets.has(key): buckets[key]=[]
		buckets[key].append(item.transform);counts[item.lod]+=1
	for key in buckets:
		if not batches.has(key):
			var batch := MultiMeshInstance3D.new();batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh=variants[names[key.z]][key.w];add_child(batch);batches[key]=batch
	for key in batches.keys():
		var transforms: Array=buckets.get(key,[])
		if retire_empty_batches and transforms.is_empty():
			batches[key].queue_free();batches.erase(key);uploaded.erase(key);continue
		if uploaded.get(key,[])==transforms: continue
		uploaded[key]=transforms
		var mm: MultiMesh=batches[key].multimesh;mm.instance_count=transforms.size()
		for i in transforms.size(): mm.set_instance_transform(i,transforms[i])
	update_ms=(Time.get_ticks_usec()-started)/1000.0

func set_enabled(value: bool) -> void:
	enabled=value;visible=value
	for item in candidates:
		if is_instance_valid(item.body): item.body.queue_free();item.body=null
	update_batches()

func set_density(value: int) -> void:
	count_limit=clampi(value,0,candidates.size());cursor=0
	for i in range(count_limit,candidates.size()):
		if is_instance_valid(candidates[i].body): candidates[i].body.queue_free();candidates[i].body=null
	update_batches()

func status() -> String:
	return "F6 trees %s | %d placed | LOD %s | update %.2f ms\nF9 tree view | F10 auto/LOD0/1/2/billboard | F11 120 FPS/uncapped | 8.33 ms target" % ["ON" if enabled else "OFF",count_limit,str(counts),update_ms]
