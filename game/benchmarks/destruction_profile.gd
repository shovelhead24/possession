extends "res://world/sdf_arena.gd"
## Isolated live-physics experiment. Never reads/writes the workshop's recipe.
const Recipe=preload("res://world/sdf_recipe.gd")
const FieldCache=preload("res://world/sdf_field_cache.gd")
var field_cache := FieldCache.new()
var features: Array=[]
var mode := "blocks"
var label := "trial"
var duration := 20.0
var interval := 1.0
var blast_radius := 2.0
var phase := 0
var settled := 0.0
var start_usec := 0
var previous_usec := 0
var next_blast := 2.0
var frames: Array[float]=[]
var events: Array=[]
var queue: Array=[]
var transaction := {}
var edit_thread: Thread
var kit: Node
var car: RigidBody3D
var distance_m := 0.0
var previous_position := Vector3.ZERO
var suspended_seconds := 0.0
var maximum_upward_speed := 0.0
var below_surface_ticks := 0
var missing_floor_ticks := 0
var backlog_max := 0
var waypoint := 0
var route: Array[Vector3]=[Vector3(-28,0,-160),Vector3(-64,0,-176),Vector3(-64,0,-45),Vector3(-28,0,-34)]
var cache_folder := "user://sdf-destruction-meshes/"
var version := ""
var failed := false
@export var interactive := false
var grenade_cooldown := 0.0
var journal_path := ""
var retired_bodies: Array=[]
var rejected_edits := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--destruction-play": interactive=true
		if arg.begins_with("--destruction-mode="): mode=arg.get_slice("=",1)
		if arg.begins_with("--destruction-label="): label=arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--destruction-seconds="): duration=maxf(5,float(arg.get_slice("=",1)))
		if arg.begins_with("--destruction-hz="): interval=1/maxf(.1,float(arg.get_slice("=",1)))
		if arg.begins_with("--destruction-radius="): blast_radius=clampf(float(arg.get_slice("=",1)),2,16)
	version=(FileAccess.get_file_as_string("res://world/sdf_field_cache.gd")+Recipe.cache_key([],Vector3.ZERO,Vector3i.ZERO,2,3.2,.35)).sha256_text()
	DirAccess.make_dir_recursive_absolute(cache_folder)
	journal_path=cache_folder+"recipe-"+str(Time.get_unix_time_from_system()).replace(".","-")+".json"
	super._ready()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_title("Live destruction / "+mode+" / "+label)
	Engine.max_fps=0

func make_arena_content() -> Node:
	return preload("res://world/arena_live_content.gd").new()

func chunk_layout() -> Dictionary:
	return {"bottom":-24.0,"cells":Vector3i(16,44,16),"spacing":2.0}

func movement_limit() -> float:
	return 85.0 if interactive else 230.0

func desired() -> Array[Vector2i]:
	var keys: Array[Vector2i]=[]
	for z in range(-8,3):
		for x in range(-4,3): keys.append(Vector2i(x,z))
	return keys

func neighborhood_ready(p: Vector3) -> bool:
	var center := key_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			if not chunks.has(center+Vector2i(x,z)): return false
	return true # Old collision remains authoritative until the complete transaction swaps.

func generate(radius: float, rough: float, origin := ORIGIN, cells := CELLS, spacing := 1.0, _sampler := Callable()) -> Dictionary:
	var path := cache_folder+(version+str(origin)).sha256_text()+".bin"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		var data: Variant=file.get_var(false)
		if data is Dictionary and data.get("_field_state") is Dictionary and FieldCache.valid_state(data._field_state,cells):
			field_cache.restore(origin,cells,spacing,radius,rough,data._field_state)
			return data
	var result := field_cache.build(origin,cells,spacing,[],radius,rough)
	persist(path,result)
	return result

static func persist(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_var(data,false);file.close()
		if DirAccess.rename_absolute(path+".tmp",path)!=OK: push_error("Destruction cache rename failed: "+path)
	else: push_error("Destruction cache write failed: "+path)

static func shape_for(data: Dictionary) -> Shape3D:
	if data.indices.is_empty(): return null
	var faces := PackedVector3Array();faces.resize(data.indices.size())
	for i in data.indices.size(): faces[i]=data.vertices[data.indices[i]]
	var shape := ConcavePolygonShape3D.new();shape.set_faces(faces)
	return shape

func install(key: Vector2i, result: Dictionary) -> void:
	var node := Node3D.new();add_child(node)
	var visual := MeshInstance3D.new();node.add_child(visual)
	visual.mesh=visual_mesh(result);visual.material_override=terrain.material_override
	var shapes := {}
	var parts: Dictionary=result._field_state.parts if mode!="whole" else {Vector2i.ZERO:result}
	for part_key in parts:
		var body := StaticBody3D.new();node.add_child(body)
		var collider := CollisionShape3D.new();collider.shape=shape_for(parts[part_key]);body.add_child(collider);shapes[part_key]=body
	chunks[key]={"node":node,"visual":visual,"shapes":shapes,"triangles":triangle_count(result),"revision":revision}

func visual_mesh(result: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not result.indices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_arrays(result))
	return mesh

func _input(event: InputEvent) -> void:
	if not interactive: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_B:
		if phase==2 and grenade_cooldown<=0:
			var grenade := preload("res://world/terrain_grenade.gd").new()
			grenade.arena=self;add_child(grenade)
			grenade.position=camera.position-camera.basis.z*.8
			grenade.velocity=-camera.basis.z*16+Vector3.UP*3
			grenade_cooldown=.3
		return
	if is_instance_valid(kit) and kit.handle_input(event): return
	if event is InputEventKey and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_R]: return
	super._input(event)

func _physics_process(delta: float) -> void:
	grenade_cooldown=maxf(0,grenade_cooldown-delta)
	if interactive:
		if not is_instance_valid(kit) or not kit.own_movement(): super._physics_process(delta)
		observe_collision()
		return
	if phase==1:
		kit.vehicle_system.tick(delta,false);settled+=delta
		if settled>=2:
			kit.enter_vehicle(car);previous_position=car.position
			start_usec=Time.get_ticks_usec();previous_usec=start_usec;phase=2
			print("DESTRUCTION_START ",mode," ",label)
	elif phase==2 or phase==3:
		kit.vehicle_system.tick(delta,true)
		var goal := route[waypoint];goal.y=car.position.y
		if car.position.distance_to(goal)<10: waypoint=(waypoint+1)%route.size()
		var direction := (goal-car.position).normalized()
		var angle: float=(-car.basis.z).signed_angle_to(direction,Vector3.UP)
		car.set_controls(.65,clampf(angle*1.5,-1,1),absf(angle)>1 and car.linear_velocity.length()>6)
		distance_m+=car.position.distance_to(previous_position);previous_position=car.position
		if car.streaming_suspended: suspended_seconds+=delta
		maximum_upward_speed=maxf(maximum_upward_speed,car.linear_velocity.y)
		var ground := floor_at(car.position)
		if ground.is_empty(): missing_floor_ticks+=1
		elif car.position.y < ground.position.y-1.5: below_surface_ticks+=1
		observe_collision()

func observe_collision() -> void:
	# Physical queries run after the engine has synchronised the shape swap.
	if transaction.get("published",false) and not transaction.has("physics_ms"):
		var hit := floor_at(transaction.point)
		var p: Vector3=transaction.point
		var expected := field_cache.pick_surface(Vector3(p.x,64,p.z),Vector3.DOWN,64-p.y)
		transaction.physics_ms=(Time.get_ticks_usec()-transaction.started)/1000.0
		transaction.floor_drop=transaction.old_height-hit.position.y if not hit.is_empty() else -999.0
		transaction.physics_floor_found=not hit.is_empty()
		transaction.collision_error=absf(hit.position.y-expected.position.y) if not hit.is_empty() and not expected.is_empty() else 999.0
		if transaction.collision_error>.02: failed=true;push_error("Destruction mesh/collision mismatch")

func floor_at(point: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,64,point.z),Vector3(point.x,-23,point.z),1))

func enqueue_blast() -> void:
	var p: Vector3=car.position-car.basis.z*3
	if not neighborhood_ready(p): p=car.position
	var hit := floor_at(p)
	if hit.is_empty(): failed=true;return
	p=hit.position+Vector3.UP
	request_crater(p,blast_radius)

func request_crater(p: Vector3, radius: float) -> bool:
	# Bounded admission, never silently discard an already accepted edit.
	if not crater_within_volume(p,radius) or queue.size()>=32 or features.size()+queue.size()>=2048 or not neighborhood_ready(p): rejected_edits+=1;return false
	var hit := floor_at(p)
	var feature := Recipe.feature("carve",p);feature.radius=radius;feature.localized=true
	queue.append({"feature":feature,"point":p,"old_height":hit.position.y if not hit.is_empty() else p.y,"started":Time.get_ticks_usec()})
	backlog_max=maxi(backlog_max,queue.size())
	return true

static func crater_within_volume(p: Vector3, radius: float) -> bool:
	# Repeated blasts must not cut out the bottom of this bounded test volume.
	return radius>=1 and radius<=16 and p.y-radius>=-22 and p.y+radius<=62

func build_edit(snapshot: Array, keys: Array) -> Array:
	var results := []
	if Recipe.save_recipe(journal_path,snapshot)!=OK: push_error("Cannot persist destruction recipe")
	for key in keys:
		var origin := Vector3(key.x*32,-24,key.y*32)
		var local := Recipe.relevant(snapshot,Rect2(Vector2(key)*32,Vector2.ONE*32).grow(2.1))
		var result := field_cache.build(origin,Vector3i(16,44,16),2,local,tunnel_radius,roughness)
		var path := cache_folder+(version+str(origin)+JSON.stringify(local)).sha256_text()+".bin"
		persist(path,result)
		results.append({"key":key,"result":result})
	return results

func pump_edits() -> void:
	if not retired_bodies.is_empty() and Engine.get_physics_frames()>retired_bodies[0].tick+4:
		var retired: Dictionary=retired_bodies.pop_front();retired.body.queue_free()
	if transaction.is_empty() and not queue.is_empty():
		transaction=queue.pop_front();features.append(transaction.feature)
		var area := FieldCache.influence(transaction.feature).grow(2.1)
		var keys := []
		for key in chunks:
			if area.intersects(Rect2(Vector2(key)*32,Vector2.ONE*32)): keys.append(key)
		transaction.keys=keys;transaction.prepare=[];transaction.staged=[];transaction.prepare_ms=0.0;transaction.max_prepare_slice_ms=0.0
		edit_thread=Thread.new()
		var error := edit_thread.start(build_edit.bind(features.duplicate(true),keys))
		if error!=OK: failed=true;push_error("Destruction worker failed");get_tree().quit(1)
	if transaction.is_empty(): return
	if edit_thread and not edit_thread.is_alive():
		transaction.results=edit_thread.wait_to_finish();edit_thread=null
		transaction.worker_done_ms=(Time.get_ticks_usec()-transaction.started)/1000.0
		transaction.base_evaluations=0;transaction.rebuilt_blocks=0;transaction.mesh_ms=0.0
		for entry in transaction.results:
			transaction.base_evaluations+=entry.result.profile.base_evaluations
			transaction.rebuilt_blocks+=entry.result.profile.rebuilt_blocks
			transaction.mesh_ms+=entry.result.ms
			transaction.prepare.append({"kind":"visual","entry":entry})
			var ids: Array=entry.result.dirty_blocks if mode!="whole" else [Vector2i.ZERO]
			for id in ids: transaction.prepare.append({"kind":"shape","entry":entry,"id":id})
	if transaction.has("results") and not transaction.get("published",false):
		var start := Time.get_ticks_usec()
		while not transaction.prepare.is_empty():
			var task: Dictionary=transaction.prepare.pop_front()
			if task.kind=="visual": task.resource=visual_mesh(task.entry.result)
			else:
				task.resource=shape_for(task.entry.result._field_state.parts[task.id] if mode!="whole" else task.entry.result)
				var body := StaticBody3D.new();body.collision_layer=0;body.collision_mask=0
				chunks[task.entry.key].node.add_child(body)
				var shape := CollisionShape3D.new();shape.shape=task.resource;body.add_child(shape)
				task.body=body
			transaction.staged.append(task)
			if Time.get_ticks_usec()-start>4000: break
		var ms := (Time.get_ticks_usec()-start)/1000.0
		transaction.prepare_ms+=ms;transaction.max_prepare_slice_ms=maxf(transaction.max_prepare_slice_ms,ms)
		if transaction.prepare.is_empty():
			if not transaction.has("prepared_tick"): transaction.prepared_tick=Engine.get_physics_frames();return
			# Let broadphase register staged bodies before changing their filters.
			if Engine.get_physics_frames()<=transaction.prepared_tick: return
			start=Time.get_ticks_usec()
			transaction.visual_swap_ms=0.0;transaction.shape_swap_ms=0.0
			# Main-thread process boundary: no physics step observes half a transaction.
			for task in transaction.staged:
				var chunk: Dictionary=chunks[task.entry.key]
				var before := Time.get_ticks_usec()
				if task.kind=="visual":
					chunk.visual.mesh=task.resource
					transaction.visual_swap_ms+=(Time.get_ticks_usec()-before)/1000.0
				else:
					var old: StaticBody3D=chunk.shapes[task.id]
					task.body.collision_layer=1;task.body.collision_mask=1
					old.collision_layer=0;old.collision_mask=0
					chunk.shapes[task.id]=task.body
					retired_bodies.append({"body":old,"tick":Engine.get_physics_frames()})
					transaction.shape_swap_ms+=(Time.get_ticks_usec()-before)/1000.0
			transaction.activation_ms=(Time.get_ticks_usec()-start)/1000.0
			transaction.published=true
			record_draw.call_deferred(transaction)
	if transaction.has("visual_ms") and transaction.has("physics_ms"):
		var report := transaction.duplicate()
		for key in ["results","prepare","staged","keys","feature"]: report.erase(key)
		report.point=str(report.point)
		events.append(report);transaction={}

func record_draw(event: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	event.visual_ms=(Time.get_ticks_usec()-event.started)/1000.0

func _process(delta: float) -> void:
	super._process(delta)
	if interactive:
		if phase==0 and ready_frames>3 and is_instance_valid(arena_content) and arena_content.get("kit") and arena_content.kit.initialized:
			kit=arena_content.kit;car=kit.vehicle;phase=2
			camera.position=Vector3(-28,5,-45);camera.look_at(Vector3(-28,0,-57));look=Vector2(camera.rotation.y,camera.rotation.x)
			if OS.get_cmdline_user_args().has("--grenade-check"): check_grenades.call_deferred()
		if phase==2: pump_edits()
		hud.text="GRENADE TERRAIN LAB / separate from your saved workshop\nB throw grenade | F walk/fly | WASD + mouse | Esc release mouse\nH Warthog / K tank / E enter | 2m terrain grid | craters persist in session\n%.0f FPS | craters %d | queued %d"%[Engine.get_frames_per_second(),features.size(),queue.size()]
		return
	if phase==0 and ready_frames>3 and is_instance_valid(arena_content) and arena_content.get("kit") and arena_content.kit.initialized and ring_background.previews_loaded==ring_background.preview_total:
		kit=arena_content.kit;car=kit.vehicle;kit.reset_all();kit.test_capture=true
		for actor in kit.actors: actor.process_mode=Node.PROCESS_MODE_DISABLED
		phase=1
	if phase in [2,3]:
		var now := Time.get_ticks_usec();frames.append((now-previous_usec)/1000.0);previous_usec=now
		var elapsed := (now-start_usec)/1000000.0
		if phase==2 and elapsed>=next_blast and mode!="baseline": enqueue_blast();next_blast+=interval
		pump_edits()
		if elapsed>=duration: phase=3
		if phase==3 and transaction.is_empty() and queue.is_empty(): phase=4;finish.call_deferred()
		if elapsed>duration+30: failed=true;phase=4;finish.call_deferred()
		hud.text="LIVE DESTRUCTION / %s / radius %.0fm / %.1fHz\n%.0f FPS | edits %d | queued %d | moving %.1fm | suspended %.2fs"%[mode,blast_radius,1/interval,Engine.get_frames_per_second(),events.size(),queue.size(),distance_m,suspended_seconds]

func finish() -> void:
	set_process(false);set_physics_process(false)
	if edit_thread: edit_thread.wait_to_finish();edit_thread=null
	var ordered := frames.duplicate();ordered.sort()
	var total := 0.0;var stalls := 0
	for ms in frames: total+=ms;stalls+=int(ms>50)
	var report := {"mode":mode,"label":label,"radius":blast_radius,"hz":1/interval,"fps":frames.size()*1000/total,"p50_ms":ordered[int(ordered.size()*.5)],"p95_ms":ordered[int(ordered.size()*.95)],"max_ms":ordered[-1],"frames_over_50ms":stalls,"distance_m":distance_m,"suspended_seconds":suspended_seconds,"max_upward_speed":maximum_upward_speed,"below_surface_ticks":below_surface_ticks,"missing_floor_ticks":missing_floor_ticks,"backlog_max":backlog_max,"failed":failed,"wall_seconds":total/1000,"events":events,"frames":frames,"gpu":RenderingServer.get_video_adapter_name(),"resolution":str(get_viewport().get_visible_rect().size)}
	report.rejected_edits=rejected_edits
	var file := FileAccess.open("user://destruction-"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	var summary := report.duplicate();summary.erase("events");summary.erase("frames")
	print("DESTRUCTION_RESULT ",JSON.stringify(summary))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://destruction-"+label+".png")
	get_tree().quit(1 if failed else 0)

func _exit_tree() -> void:
	if edit_thread: edit_thread.wait_to_finish();edit_thread=null
	super._exit_tree()

func check_grenades() -> void:
	for coord in [Vector2(-32.1,-48),Vector2(-31.9,-48),Vector2(-48,-48)]:
		var floor_hit := floor_at(Vector3(coord.x,0,coord.y))
		var grenade := preload("res://world/terrain_grenade.gd").new();grenade.arena=self
		add_child(grenade);grenade.position=floor_hit.position+Vector3.UP*.5;grenade.velocity=Vector3(0,1,2)
	for frame in 1800:
		await get_tree().physics_frame
		if events.size()==3: break
	if events.size()!=3 or failed:
		push_error("Grenade integration failed or timed out");get_tree().quit(1);return
	if events[0].floor_drop<.1 or events[2].floor_drop<.1:
		push_error("Grenade did not produce a measurable hole");get_tree().quit(1);return
	var file := FileAccess.open("user://grenade-integration.json",FileAccess.WRITE);file.store_string(JSON.stringify(events,"\t"));file.close()
	camera.position=Vector3(-37,5,-56);camera.look_at(Vector3(-32,-.3,-48))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://grenade-integration.png")
	print("PASS: three fused grenades, queued overlapping seam craters, matching live collision, measurable holes, isolated recipe persistence")
	get_tree().quit()
