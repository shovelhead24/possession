extends "res://world/sdf_arena.gd"
## Separate workshop: same terrain evaluator for preview, persisted chunks and collision.
const Recipe = preload("res://world/sdf_recipe.gd")
const SAVE_PATH := "user://sdf-authoring.json"
const CACHE_PATH := "user://sdf-authoring-meshes/"
var features: Array = []
var undo_stack: Array = []
var redo_stack: Array = []
var selected := -1
var panel: PanelContainer
var feature_list: ItemList
var fields := {}
var notice: Label
var updating := false
var editing := true
var placing := false
var cache_reads := 0
var cache_builds := 0
var marker := MeshInstance3D.new()
var edited_bounds: Array = []
var dragging := false
var drag_position := Vector3.ZERO
var brush_mode := true
var brush_template: Dictionary=Recipe.feature("lower",Vector3.ZERO)
var brush := preload("res://world/sdf_brush.gd").new()
var brushing := false
var brush_dirty := false
var brush_rate := 4.0
var fly_speed := 25.0
var brush_time := 0.0
var looking := false
var brush_cursor := MeshInstance3D.new()
var chunk_overlay := MeshInstance3D.new()
var show_chunks := false
var overlay_signature := ""
var endpoint_guide := MeshInstance3D.new()
var endpoint_handle := MeshInstance3D.new()
var picking_endpoint := false
var endpoint_dragging := false
var endpoint_preview := Vector3.ZERO
var endpoint_plane := Plane()
var field_cache := preload("res://world/sdf_field_cache.gd").new()
var collision_pending := {}
var latest_input_usec := 0
var edit_started_usec := 0
var preview_latency_ms := 0.0
var last_field_profile := {}
var preview_expected := {}
var preview_meshes := {}
var aim_point := Vector3.ZERO
var aim_valid := false
var brush_outline_signature := ""
var preview_publications := 0
var trace_file: FileAccess
var trace_path := ""
var trace_flush_usec := 0
var last_process_usec := 0
var physics_ms := 0.0
var collision_supports := {}
var operation_marker_id := 0
var operation_marker_started := 0
var operation_marker_status := "F8: mark BEGIN before a slow operation, END afterwards"
var operation_marker_button: Button
var simple_radius: SpinBox
var simple_strength: SpinBox
var brush_mode_toggle: CheckButton
var simple_brush_label: Label
var shape_choice: OptionButton
var aspect_control: SpinBox
var tunnel_new_armed := false
var picking_entry := false
var tunnel_choice: OptionButton
var tunnel_radius_control: SpinBox
var tunnel_actions: HFlowContainer
var loading_screen: CanvasLayer
var loading_test_started := false
var dragging_entry := false
var surface_cursor := MeshInstance3D.new()
var play_requested := false
var play_status: Label
var grenade_cooldown := 0.0
var crater_queue: Array=[]

func trace_edit(event: String, extra := {}) -> void:
	if trace_file==null: return
	var data := {"event":event,"usec":Time.get_ticks_usec(),"revision":revision,"features":features.size(),"jobs":stream_jobs.size(),"pending_preview":preview_expected.size(),"pending_collision":collision_pending.size(),"brushing":brushing,"brush_dirty":brush_dirty}
	data.merge(extra);trace_file.store_line(JSON.stringify(data))

func mark_operation() -> void:
	var now := Time.get_ticks_usec()
	var wall := Time.get_unix_time_from_system()
	var phase := "END" if operation_marker_started>0 else "BEGIN"
	var elapsed := 0.0
	if phase=="BEGIN":
		operation_marker_id+=1;operation_marker_started=now
	else:
		elapsed=(now-operation_marker_started)/1000.0;operation_marker_started=0
	var data := {"marker_id":operation_marker_id,"phase":phase,"unix_seconds":wall,"utc":Time.get_datetime_string_from_unix_time(int(wall))+"Z","elapsed_ms":elapsed,"tool":brush_template.kind,"radius_m":brush_template.radius,"strength_per_second":brush_rate,"editing":editing,"camera":str(camera.position),"aim":str(aim_point),"aim_valid":aim_valid}
	trace_edit("operation_marker",data)
	if trace_file: trace_file.flush();trace_flush_usec=now
	operation_marker_status="MARK %d %s / %s" % [operation_marker_id,phase,data.utc]
	if phase=="END": operation_marker_status+=" / %.2f seconds" % (elapsed/1000.0)
	else: operation_marker_status+=" / F8 to mark END"
	if operation_marker_button: operation_marker_button.text="F8: mark END" if operation_marker_started else "F8: mark BEGIN"
	print("EDITOR_MARK ",JSON.stringify(data)," / ",ProjectSettings.globalize_path(trace_path))

func recovery_floor() -> float:
	return -30.0 # Below the editable volume, not through its legitimate holes.

func _exit_tree() -> void:
	trace_edit("exit")
	if trace_file: trace_file.close();trace_file=null
	super._exit_tree()

func stream_worker_limit() -> int:
	return 2

func make_arena_content() -> Node:
	return preload("res://world/arena_live_content.gd").new()

func live_kit() -> Node:
	return arena_content.kit if is_instance_valid(arena_content) and arena_content.get("kit") and arena_content.kit.initialized else null

func _ready() -> void:
	var automated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--authoring-") and arg!="--authoring-loading-check": automated=true
	if not automated:
		set_process(false);set_physics_process(false);set_process_input(false)
		loading_screen=preload("res://world/workshop_loading.gd").new();add_child(loading_screen)
		loading_screen.enter.pressed.connect(func(): Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if editing else Input.MOUSE_MODE_CAPTURED)
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		await RenderingServer.frame_post_draw
	trace_path="user://sdf-editor-trace-"+str(Time.get_unix_time_from_system()).replace(".","-")+".jsonl"
	trace_file=FileAccess.open(trace_path,FileAccess.WRITE)
	print("EDITOR_TRACE ",ProjectSettings.globalize_path(trace_path))
	DirAccess.make_dir_recursive_absolute(CACHE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if Recipe.validate(saved): features=saved.features
	super._ready()
	make_panel()
	var sphere := SphereMesh.new();sphere.radius=.7;sphere.height=1.4
	marker.mesh=sphere
	var mat := StandardMaterial3D.new();mat.albedo_color=Color.ORANGE;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test=true
	marker.material_override=mat;add_child(marker)
	var cursor_mesh := SphereMesh.new();cursor_mesh.radius=1;cursor_mesh.height=2
	brush_cursor.mesh=cursor_mesh
	var cursor_mat := StandardMaterial3D.new();cursor_mat.albedo_color=Color(1,.65,.1,.22);cursor_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;cursor_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	brush_cursor.material_override=cursor_mat;add_child(brush_cursor)
	add_child(chunk_overlay)
	var line_material := StandardMaterial3D.new();line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_material.vertex_color_use_as_albedo=true;line_material.no_depth_test=true
	chunk_overlay.material_override=line_material
	add_child(endpoint_guide);endpoint_guide.material_override=line_material
	endpoint_handle.mesh=cursor_mesh;endpoint_handle.material_override=line_material;add_child(endpoint_handle)
	var ring_mesh := ImmediateMesh.new();ring_mesh.surface_begin(Mesh.PRIMITIVE_LINES);ring_mesh.surface_set_color(Color(0.3,1,.45))
	for i in 64:
		ring_mesh.surface_add_vertex(Vector3(cos(i*TAU/64),0,sin(i*TAU/64)))
		ring_mesh.surface_add_vertex(Vector3(cos((i+1)*TAU/64),0,sin((i+1)*TAU/64)))
	ring_mesh.surface_end();surface_cursor.mesh=ring_mesh;surface_cursor.material_override=line_material;surface_cursor.hide();add_child(surface_cursor)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	refresh()
	DisplayServer.window_set_title("SDF workshop / Raise-Lower + editable tunnels")
	if OS.get_cmdline_user_args().has("--authoring-check"): check_workshop.call_deferred()
	if OS.get_cmdline_user_args().has("--authoring-repro"): check_repeated_clicks.call_deferred()
	if OS.get_cmdline_user_args().has("--authoring-ui-check"): check_simple_ui.call_deferred()
	if OS.get_cmdline_user_args().has("--authoring-tunnel-check"): check_tunnel_editing.call_deferred()
	if OS.get_cmdline_user_args().has("--authoring-recovery-check"): check_brush_recovery.call_deferred()
	trace_edit("ready",{"path":trace_path})
	set_process(true);set_physics_process(true);set_process_input(true)

func loading_event(message: String) -> void:
	if loading_screen: loading_screen.log_event(message)

func update_loading_screen() -> void:
	if not loading_screen or loading_screen.ready_to_enter: return
	var wanted := desired();var done := 0
	for key in wanted:
		if chunks.has(key) and chunks[key].revision==revision: done+=1
	var sources := int(arena_content.loading_sources_done) if is_instance_valid(arena_content) else 0
	var total := int(arena_content.loading_sources_total) if is_instance_valid(arena_content) else 4
	var ring_done: bool=ring_background.background_ready and not ring_background.home_pending and ring_background._preview_thread==null and ring_background._preview_queue.is_empty()
	var imagery_total := maxi(1,ring_background.preview_total)
	var processed: int=imagery_total-ring_background._preview_queue.size()-int(ring_background._preview_thread!=null)-int(ring_background.home_pending) if ring_background.background_ready else 0
	var complete: bool=live_kit()!=null and ready_frames>=3 and collision_pending.is_empty() and ring_done
	loading_screen.update_progress(done,wanted.size(),maxi(0,processed),imagery_total,sources,maxi(4,total),live_kit()!=null,complete)

func briefing_open() -> bool:
	return loading_screen!=null and not loading_screen.dismissed

func rebuild() -> void:
	revision+=1
	ready_frames=0

func chunk_layout() -> Dictionary:
	return {"bottom":-24.0,"cells":Vector3i(16,44,16),"spacing":2.0}

func movement_limit() -> float:
	return 740.0

func desired() -> Array[Vector2i]:
	var keys := super.desired()
	if editing and (brushing or brush_dirty):
		# Retain resident terrain but do not flood the brush queue with fly/vehicle
		# look-ahead while the user is actively drawing.
		keys.assign(chunks.keys())
		var target := key_at(brush.previous)
		for z in range(-1,2):
			for x in range(-1,2):
				var key := target+Vector2i(x,z)
				if absi(key.x)<24 and absi(key.y)<24 and key not in keys: keys.append(key)
		keys.sort_custom(func(a: Vector2i,b: Vector2i): return (a-target).length_squared()<(b-target).length_squared())
		return keys
	var centre := key_at(camera.position)
	for z in range(-2,3):
		for x in range(-2,3):
			var key := centre+Vector2i(x,z)
			if absi(key.x)<24 and absi(key.y)<24 and key not in keys: keys.append(key)
	if editing and aim_valid:
		var target := key_at(aim_point)
		for z in range(-1,2):
			for x in range(-1,2):
				var key := target+Vector2i(x,z)
				if absi(key.x)<24 and absi(key.y)<24 and key not in keys: keys.append(key)
	var kit := live_kit()
	if kit:
		for body in kit.vehicle_system.vehicles:
			var speed: float=body.linear_velocity.length()
			var direction: Vector3=body.linear_velocity.normalized() if speed>2 else -body.basis.z
			var reach: float=minf(320,maxf(80,maxf(speed*6,speed*speed/7+64)))
			for step in range(0,ceili(reach/32)+1):
				var point: Vector3=body.position+direction*step*32
				var centre_key := key_at(point)
				for z in range(-2,3):
					for x in range(-2,3):
						var key := centre_key+Vector2i(x,z)
						if absi(key.x)<24 and absi(key.y)<24 and key not in keys: keys.append(key)
	if editing and aim_valid:
		var target := key_at(aim_point)
		keys.sort_custom(func(a: Vector2i,b: Vector2i): return (a-target).length_squared()<(b-target).length_squared())
	return keys

func neighborhood_ready(p: Vector3) -> bool:
	var centre := key_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			var key := centre+Vector2i(x,z)
			if absi(key.x)>=24 or absi(key.y)>=24: continue
			if not chunks.has(key) or (editing and chunks[key].revision!=revision): return false
	return true

func switch_editor_mode(value: bool) -> void:
	var kit := live_kit()
	if kit: kit.release_control()
	editing=value;play_requested=false;panel.visible=editing;placing=false;dragging=false;endpoint_dragging=false;walking=false
	surface_cursor.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if editing else Input.MOUSE_MODE_CAPTURED
	refresh();trace_edit("mode_changed",{"editing":editing})

func update_play_status() -> void:
	var wanted := desired();var ready := 0
	for key in wanted:
		if chunks.has(key) and chunks[key].revision==revision: ready+=1
	var sections := 0
	for pending in collision_pending.values(): sections+=pending.dirty.size()+1
	var remaining := maxi(0,preview_expected.size()-preview_meshes.size())
	var safe: bool=ready==wanted.size() and preview_expected.is_empty() and collision_pending.is_empty() and not brush_dirty and crater_queue.is_empty() and live_kit()!=null
	if play_requested and safe:
		switch_editor_mode(false);notice.text="Play ready. B throws a grenade; F1 returns to editing."
	play_status.text="PLAY READY — F1 to enter" if safe else "Terrain %d/%d | mesh results %d | collision steps %d | workers %d%s" % [ready,wanted.size(),remaining,sections,stream_jobs.size()," | brush queued" if brush_dirty else ""]
	if play_requested: play_status.text="PLAY QUEUED — automatic when ready (F1 cancels)\n"+play_status.text
	if editing: hud.text+="\n"+play_status.text

func throw_grenade() -> void:
	if editing or grenade_cooldown>0 or not live_kit(): return
	var grenade := preload("res://world/terrain_grenade.gd").new();grenade.arena=self;add_child(grenade)
	grenade.position=camera.position-camera.basis.z*.8;grenade.velocity=-camera.basis.z*16+Vector3.UP*3
	grenade_cooldown=.3;trace_edit("grenade_thrown")

func request_crater(p: Vector3, radius: float) -> bool:
	if radius<=0 or p.y-radius< -22 or p.y+radius>62 or absf(p.x)+radius+2>movement_limit() or absf(p.z)+radius+2>movement_limit(): return false
	if crater_queue.size()>=32 or features.size()+crater_queue.size()>=2048 or not neighborhood_ready(p): return false
	var crater := Recipe.feature("carve",p);crater.radius=radius;crater.localized=true
	crater_queue.append(crater);trace_edit("grenade_crater_queued",{"point":str(p),"radius":radius})
	return true

func chunk_sampler() -> Callable:
	# Snapshot on the main thread, never read mutable editor data from a worker.
	return Recipe.field.bind(features.duplicate(true))

static func cached_path(local: Array, origin: Vector3, cells: Vector3i, spacing: float, radius: float, detail: float) -> String:
	var version := FileAccess.get_file_as_string("res://world/sdf_field_cache.gd").sha256_text()
	return CACHE_PATH+(version+Recipe.cache_key(local,origin,cells,spacing,radius,detail)).sha256_text()+".bin"

func generate(radius: float, detail: float, origin := ORIGIN, cells := CELLS, spacing := 1.0, sampler := Callable()) -> Dictionary:
	var started := Time.get_ticks_usec()
	var snapshot: Array=sampler.get_bound_arguments()[0]
	var local := Recipe.relevant(snapshot,Rect2(Vector2(origin.x,origin.z),Vector2(cells.x,cells.z)*spacing).grow(spacing+.1))
	var path := cached_path(local,origin,cells,spacing,radius,detail)
	if FileAccess.file_exists(path):
		var reader := FileAccess.open(path,FileAccess.READ)
		if reader:
			var data: Variant=reader.get_var(false)
			if data is Dictionary and data.get("vertices") is PackedVector3Array and data.get("normals") is PackedVector3Array and data.get("indices") is PackedInt32Array:
				var valid: bool=data.vertices.size()==data.normals.size() and data.indices.size()%3==0
				for index in data.indices:
					if index<0 or index>=data.vertices.size(): valid=false;break
				if valid and data.get("_field_state") is Dictionary and field_cache.valid_state(data._field_state,cells):
					field_cache.restore(origin,cells,spacing,radius,detail,data._field_state)
					data.ms=0;data.cached=true;data.profile={"warm_field":true,"base_evaluations":0,"rebuilt_blocks":0,"disk_restore":true,"worker_total_ms":(Time.get_ticks_usec()-started)/1000.0};return data
	var result := field_cache.build(origin,cells,spacing,local,radius,detail)
	var built := Time.get_ticks_usec()
	var writer := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if writer:
		writer.store_var(result,false);writer.close()
		DirAccess.rename_absolute(path+".tmp",path)
	result.profile.disk_write_ms=(Time.get_ticks_usec()-built)/1000.0
	result.profile.worker_total_ms=(Time.get_ticks_usec()-started)/1000.0
	return result

func chunk_generated(result: Dictionary) -> void:
	last_field_profile=result.get("profile",{})
	trace_edit("worker_done",{"generation_ms":result.ms,"field":last_field_profile,"cached":result.get("cached",false)})
	if result.get("cached",false): cache_reads+=1
	else: cache_builds+=1

func install(key: Vector2i, result: Dictionary) -> void:
	if chunks.has(key):
		var started := Time.get_ticks_usec()
		# Visual feedback is independent of expensive physics construction.
		var mesh := ArrayMesh.new()
		if not result.vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_arrays(result))
		chunks[key].revision=active_revision;chunks[key].triangles=triangle_count(result)
		preview_meshes[key]={"mesh":mesh,"parts":result._field_state.parts}
		trace_edit("mesh_upload",{"key":str(key),"upload_ms":(Time.get_ticks_usec()-started)/1000.0})
		publish_preview()
		return
	super.install(key,result)

func publish_preview() -> void:
	for key in preview_expected:
		if chunks.has(key) and not preview_meshes.has(key): return
	for key in preview_meshes:
		if not chunks.has(key): continue
		var mesh: ArrayMesh=preview_meshes[key].mesh
		var found := false
		for child in chunks[key].node.get_children():
			if child is MeshInstance3D: child.mesh=mesh;found=true
		if not found:
			var instance := MeshInstance3D.new();instance.mesh=mesh;instance.material_override=terrain.material_override;chunks[key].node.add_child(instance)
		queue_editor_collision(key,preview_meshes[key].parts)
	if not preview_meshes.is_empty() and edit_started_usec>0:
		preview_publications+=1
		preview_latency_ms=(Time.get_ticks_usec()-edit_started_usec)/1000.0;edit_started_usec=0
		trace_edit("preview",{"latency_ms":preview_latency_ms,"chunks":preview_meshes.size(),"field":last_field_profile})
	preview_meshes.clear();preview_expected.clear()

func queue_editor_collision(key: Vector2i, parts: Dictionary) -> void:
	# Compare with LIVE collision, not the last generated revision: several visual
	# updates may have accumulated while a stroke held physics work back.
	if collision_pending.has(key):
		# Finish bounded work already started; keep only the latest next snapshot.
		# Rapid clicks must not continually destroy half-built physics resources.
		collision_pending[key].next_parts=parts
		return
	var old_parts: Dictionary=chunks[key].get("collision_parts",{})
	var dirty := []
	for id in parts:
		if not old_parts.has(id) or old_parts[id].vertices!=parts[id].vertices or old_parts[id].indices!=parts[id].indices: dirty.append(id)
	collision_pending[key]={"parts":parts,"dirty":dirty,"staged":{},"tick":-1}

func pump_editor_collision() -> void:
	if collision_pending.is_empty(): return
	var started := Time.get_ticks_usec()
	for key in collision_pending.keys():
		var pending: Dictionary=collision_pending[key]
		if not chunks.has(key):
			collision_pending.erase(key);continue
		while not pending.dirty.is_empty():
			var id: Vector2i=pending.dirty.pop_front()
			var part: Dictionary=pending.parts[id]
			var body := StaticBody3D.new();body.collision_layer=0;body.collision_mask=0
			chunks[key].node.add_child(body)
			if not part.indices.is_empty():
				var faces := PackedVector3Array();faces.resize(part.indices.size())
				for i in part.indices.size(): faces[i]=part.vertices[part.indices[i]]
				var shape := ConcavePolygonShape3D.new();shape.set_faces(faces)
				var collider := CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
			pending.staged[id]=body
			if Time.get_ticks_usec()-started>=4000: return
		if pending.tick<0: pending.tick=Engine.get_physics_frames();continue
		if Engine.get_physics_frames()<=pending.tick: continue
		remember_collision_support(key)
		if not chunks[key].has("collision_blocks"):
			# First edit converts the original whole-chunk collider to sections.
			for child in chunks[key].node.get_children():
				if child is StaticBody3D and child not in pending.staged.values():
					child.collision_layer=0;child.collision_mask=0;child.queue_free()
			chunks[key].collision_blocks={}
		for id in pending.staged:
			if chunks[key].collision_blocks.has(id):
				var old: StaticBody3D=chunks[key].collision_blocks[id]
				old.collision_layer=0;old.collision_mask=0;old.queue_free()
			var body: StaticBody3D=pending.staged[id]
			body.collision_layer=1;body.collision_mask=1;chunks[key].collision_blocks[id]=body
		chunks[key].collision_parts=pending.parts
		collision_pending.erase(key)
		if pending.has("next_parts"): queue_editor_collision(key,pending.next_parts)
		trace_edit("collision_swap",{"key":str(key),"sections":pending.staged.size()})
		if Time.get_ticks_usec()-started>=4000: return

func update_chunk_overlay() -> void:
	chunk_overlay.visible=show_chunks
	if not show_chunks: return
	var signature := str(chunks.keys())+str(revision)+str(preview_expected.keys())+str(ready_frames>0)
	if signature==overlay_signature: return
	overlay_signature=signature
	var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for key in chunks:
		var colour := Color.ORANGE if chunks[key].revision!=revision or preview_expected.has(key) else Color(0,.9,1)
		mesh.surface_set_color(colour)
		var p := Vector3(key.x*CHUNK,-24,key.y*CHUNK)
		for y in [-24.0,0.0,64.0]:
			var corners := [Vector3(p.x,y,p.z),Vector3(p.x+32,y,p.z),Vector3(p.x+32,y,p.z+32),Vector3(p.x,y,p.z+32)]
			for i in 4: mesh.surface_add_vertex(corners[i]);mesh.surface_add_vertex(corners[(i+1)%4])
		for offset in [Vector3.ZERO,Vector3(32,0,0),Vector3(32,0,32),Vector3(0,0,32)]:
			mesh.surface_add_vertex(p+offset);mesh.surface_add_vertex(p+offset+Vector3(0,88,0))
	mesh.surface_end();chunk_overlay.mesh=mesh

func change(next: Array, remember := true, update_ui := true, input_stamp := 0) -> void:
	if remember:
		undo_stack.append(features.duplicate(true));redo_stack.clear()
	var changed := []
	# Pending chunks are exact keys, NOT fresh edit footprints. Growing them
	# repeatedly spreads invalidation by another chunk every resubmission.
	var unfinished := preview_expected.duplicate()
	preview_expected.clear();preview_meshes.clear()
	# Conservatively invalidate both old and new footprints, but retain unrelated chunks.
	for i in maxi(features.size(),next.size()):
		if i<features.size() and i<next.size() and features[i]==next[i]: continue
		if i<features.size(): changed.append(field_cache.influence(features[i]).grow(2.1))
		if i<next.size(): changed.append(field_cache.influence(next[i]).grow(2.1))
	if edit_started_usec==0: edit_started_usec=input_stamp if input_stamp>0 else Time.get_ticks_usec()
	features=next.duplicate(true);revision+=1;ready_frames=0
	# Unrelated background jobs still have valid snapshots; don't discard them
	# merely because a nearby stroke advanced the global editor revision.
	for job in stream_jobs:
		var dirty := unfinished.has(job.key)
		for area in changed:
			if area.intersects(Rect2(Vector2(job.key)*CHUNK,Vector2.ONE*CHUNK)): dirty=true;break
		if not dirty: job.revision=revision
	edited_bounds.append_array(changed)
	for key in chunks:
		var dirty := unfinished.has(key)
		for area in changed:
			if area.intersects(Rect2(Vector2(key)*CHUNK,Vector2.ONE*CHUNK)): dirty=true;break
		if not dirty: chunks[key].revision=revision
		else: preview_expected[key]=true
	selected=mini(selected,features.size()-1)
	if update_ui: refresh()
	trace_edit("edit_submitted",{"dirty_chunks":preview_expected.size()})
	notice.text="Edited — Save to keep recipe. Old meshes retained on disk."

func make_panel() -> void:
	panel=PanelContainer.new();panel.position=Vector2(550,100);panel.size=Vector2(400,480)
	var canvas := CanvasLayer.new();add_child(canvas);canvas.add_child(panel)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size=Vector2(400,470);panel.add_child(scroll)
	var column := VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	var title := Label.new();title.text="SDF RECIPE / F1 edit-play";column.add_child(title)
	play_status=Label.new();play_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(play_status)
	var simple_tools := HBoxContainer.new();column.add_child(simple_tools)
	for kind in ["hill","lower"]:
		var button := Button.new();button.text="Raise terrain" if kind=="hill" else "Lower terrain"
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;simple_tools.add_child(button)
		button.pressed.connect(select_simple_brush.bind(kind))
	simple_brush_label=Label.new();column.add_child(simple_brush_label)
	var simple_controls := GridContainer.new();simple_controls.columns=2;column.add_child(simple_controls)
	var radius_label := Label.new();radius_label.text="Brush radius (metres)";simple_controls.add_child(radius_label)
	simple_radius=SpinBox.new();simple_radius.min_value=1;simple_radius.max_value=120;simple_radius.step=1;simple_radius.value=brush_template.radius;simple_controls.add_child(simple_radius)
	simple_radius.value_changed.connect(func(value: float): brush_template.radius=value;refresh())
	var strength_label := Label.new();strength_label.text="Strength / second";simple_controls.add_child(strength_label)
	simple_strength=SpinBox.new();simple_strength.min_value=.25;simple_strength.max_value=100;simple_strength.step=.25;simple_strength.value=brush_rate;simple_controls.add_child(simple_strength)
	simple_strength.value_changed.connect(func(value: float): brush_rate=value)
	var help := Label.new();help.text="Hold LMB on ground to sculpt. RMB + WASD to fly.\nWheel: zoom. Shift-wheel: brush size.";column.add_child(help)
	operation_marker_button=Button.new();operation_marker_button.text="F8: mark BEGIN";column.add_child(operation_marker_button)
	operation_marker_button.tooltip_text="Press before and after a slow operation. Timestamped markers flush immediately to the editor trace."
	operation_marker_button.pressed.connect(mark_operation)
	var simple_actions := HBoxContainer.new();column.add_child(simple_actions)
	for spec in [["Undo",undo],["Redo",redo],["Save",save],["Load",load_saved]]:
		var button := Button.new();button.text=spec[0];simple_actions.add_child(button);button.pressed.connect(spec[1])
	var top_column := column
	var tunnel_toggle := CheckButton.new();tunnel_toggle.text="Tunnel tools / create or edit";column.add_child(tunnel_toggle)
	var tunnel_panel := VBoxContainer.new();column.add_child(tunnel_panel);tunnel_panel.hide()
	tunnel_toggle.toggled.connect(func(value: bool): tunnel_panel.visible=value)
	var new_tunnel := Button.new();new_tunnel.text="Create ONE new tunnel: click its entrance";tunnel_panel.add_child(new_tunnel)
	new_tunnel.pressed.connect(arm_new_tunnel)
	tunnel_choice=OptionButton.new();tunnel_panel.add_child(tunnel_choice)
	tunnel_choice.item_selected.connect(func(index: int): select_tunnel(tunnel_choice.get_item_id(index)))
	tunnel_actions=HFlowContainer.new();tunnel_panel.add_child(tunnel_actions)
	for spec in [["Move whole tunnel",place_selected],["Set entrance",pick_tunnel_entry],["Set exit",pick_tunnel_exit],["Focus tunnel",focus_selected]]:
		var button := Button.new();button.text=spec[0];tunnel_actions.add_child(button);button.pressed.connect(spec[1])
	var tunnel_size := HBoxContainer.new();tunnel_panel.add_child(tunnel_size)
	var tunnel_label := Label.new();tunnel_label.text="Tunnel radius (metres)";tunnel_size.add_child(tunnel_label)
	tunnel_radius_control=SpinBox.new();tunnel_radius_control.min_value=1;tunnel_radius_control.max_value=120;tunnel_radius_control.value=4;tunnel_size.add_child(tunnel_radius_control)
	tunnel_radius_control.value_changed.connect(func(value: float):
		if tunnel_new_armed: brush_template.radius=value
		elif selected>=0 and features[selected].kind=="tunnel":
			var next := features.duplicate(true);next[selected].radius=value;change(next))
	var tunnel_help := Label.new();tunnel_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;tunnel_help.custom_minimum_size.x=270
	tunnel_help.text="Grab either centre point to drag/select that end; click elsewhere on terrain to place the active end. Orange = entrance, cyan = exit. Green circle shows the target opening on the wall. Focus tunnel finds its handles. Ctrl snaps heading; Alt-click targets the far exit surface. Moving replaces the old cut."
	tunnel_panel.add_child(tunnel_help)
	var advanced_toggle := CheckButton.new();advanced_toggle.text="Advanced tools and feature settings";column.add_child(advanced_toggle)
	var advanced := VBoxContainer.new();column.add_child(advanced);advanced.hide()
	advanced_toggle.toggled.connect(func(value: bool): advanced.visible=value)
	column=advanced
	var toggle := CheckButton.new();toggle.text="Brush (off = edit/move features)";toggle.button_pressed=true;column.add_child(toggle)
	brush_mode_toggle=toggle
	toggle.toggled.connect(func(value: bool): finish_brush();flush_brush();brush_mode=value;refresh())
	var debug_button := Button.new();debug_button.text="F3 chunk outlines / cyan ready, orange pending";column.add_child(debug_button)
	debug_button.pressed.connect(func(): show_chunks=not show_chunks)
	var shape_row := HBoxContainer.new();column.add_child(shape_row)
	var shapes := OptionButton.new()
	shape_choice=shapes
	for label in ["circle","square","ellipse"]: shapes.add_item(label)
	shape_row.add_child(shapes)
	shapes.item_selected.connect(func(index: int): brush_template.shape=["circle","square","ellipse"][index])
	var aspect_label := Label.new();aspect_label.text="Ellipse ratio";shape_row.add_child(aspect_label)
	var aspect := SpinBox.new();aspect.min_value=.25;aspect.max_value=4;aspect.step=.25;aspect.value=1;shape_row.add_child(aspect)
	aspect_control=aspect
	aspect.value_changed.connect(func(value: float): brush_template.aspect=value)
	var end_button := Button.new();end_button.text="Set tunnel exit (Alt-click = far surface)";column.add_child(end_button)
	end_button.pressed.connect(pick_tunnel_exit)
	var rates := HBoxContainer.new();column.add_child(rates)
	for spec in [["Fly m/s",25.0]]:
		var label := Label.new();label.text=spec[0];rates.add_child(label)
		var speed := SpinBox.new();speed.min_value=.25;speed.max_value=100;speed.step=.25;speed.value=spec[1];rates.add_child(speed)
		speed.value_changed.connect(func(value: float): fly_speed=value)
	var tools := HFlowContainer.new();column.add_child(tools)
	for kind in Recipe.TYPES:
		var button := Button.new();button.text="ravine" if kind=="lower" else kind;tools.add_child(button);button.pressed.connect(add_feature.bind(kind))
	feature_list=ItemList.new();feature_list.custom_minimum_size=Vector2(270,85);column.add_child(feature_list)
	feature_list.item_selected.connect(func(index: int):
		if features[index].kind=="tunnel": select_tunnel(index)
		else: selected=index;brush_template=features[index].duplicate(true);brush_template.erase("amount");refresh())
	var grid := GridContainer.new();grid.columns=4;column.add_child(grid)
	for key in ["x","y","z","radius","height","length","width","thickness","yaw","bend"]:
		var label := Label.new();label.text=key;grid.add_child(label)
		var value := SpinBox.new();value.min_value=-740;value.max_value=740;value.step=1;value.custom_minimum_size.x=78
		if key in ["radius","height","length","width","thickness"]: value.min_value=1;value.max_value=120
		if key=="y": value.min_value=-20;value.max_value=55
		grid.add_child(value);fields[key]=value;value.value_changed.connect(edit_value.bind(key))
	var actions := HFlowContainer.new();column.add_child(actions)
	for spec in [["Move feature",place_selected],["Focus",focus_selected],["Delete",delete_selected],["Earlier",reorder.bind(-1)],["Later",reorder.bind(1)]]:
		var button := Button.new();button.text=spec[0];actions.add_child(button);button.pressed.connect(spec[1])
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.x=270
	notice.text="WASD fly, RMB look, LMB sculpt. Wheel zoom; Shift-wheel size. Strokes accumulate. Save explicitly."
	top_column.add_child(notice)

func select_simple_brush(kind: String) -> void:
	finish_brush();flush_brush()
	tunnel_new_armed=false;picking_entry=false
	var radius: float=brush_template.radius
	brush_template=Recipe.feature(kind,Vector3.ZERO);brush_template.radius=radius
	brush_template.shape="circle";brush_template.aspect=1.0
	brush_mode=true;placing=false;dragging=false;picking_endpoint=false;endpoint_dragging=false
	brush_mode_toggle.set_pressed_no_signal(true)
	refresh()
	notice.text=("Raise" if kind=="hill" else "Lower")+" terrain: hold left mouse on ground. Size and strength above are all you need."

func arm_new_tunnel() -> void:
	finish_brush();flush_brush()
	brush_template=Recipe.feature("tunnel",Vector3.ZERO);brush_template.radius=tunnel_radius_control.value
	brush_mode=true;tunnel_new_armed=true;placing=false;dragging=false;picking_entry=false;picking_endpoint=false;endpoint_dragging=false
	brush_mode_toggle.set_pressed_no_signal(true);refresh()
	notice.text="NEW TUNNEL: click its entrance once. Then edit that tunnel. Esc cancels."

func select_tunnel(index: int) -> void:
	if index<0 or index>=features.size() or features[index].kind!="tunnel": return
	finish_brush();flush_brush();selected=index
	brush_template=features[index].duplicate(true);brush_template.erase("amount")
	brush_mode=false;tunnel_new_armed=false;placing=false;dragging=false;picking_entry=false;picking_endpoint=features[index].has("end_x");endpoint_dragging=false
	brush_mode_toggle.set_pressed_no_signal(false);refresh()
	notice.text="EDITING tunnel %d. Grab either centre handle to drag/select that end; click a surface to place the active end. Exit active initially. Move whole tunnel preserves both ends." % (index+1)

func pick_tunnel_entry() -> void:
	if selected<0 or not features[selected].has("end_x"): return
	picking_entry=true;picking_endpoint=false;placing=false
	notice.text="Click a surface for this tunnel's entrance. The exit stays fixed. Esc cancels."

func pick_tunnel_exit() -> void:
	if selected<0 or not features[selected].has("end_x"): return
	picking_endpoint=true;picking_entry=false;placing=false
	notice.text="Click exit surface; Alt-click targets the far side. Ctrl snaps heading to 45 degrees. Esc cancels."

func reposition_selected(point: Vector3) -> void:
	if selected<0: return
	var next := features.duplicate(true);var f: Dictionary=next[selected]
	var offset := point-Vector3(f.x,f.y,f.z)
	f.x=point.x;f.y=point.y;f.z=point.z
	if f.has("end_x"):
		f.end_x+=offset.x;f.end_y+=offset.y;f.end_z+=offset.z
	change(next)

func refresh() -> void:
	if feature_list==null: return
	if selected<0 and not features.is_empty(): selected=0
	updating=true;feature_list.clear()
	for i in features.size(): feature_list.add_item("%d  %s" % [i+1,features[i].kind])
	tunnel_choice.clear();tunnel_choice.add_item("Select an existing tunnel…",2147483647)
	for i in features.size():
		if features[i].kind=="tunnel":
			tunnel_choice.add_item("Tunnel %d" % (i+1),i)
			if i==selected and not tunnel_new_armed: tunnel_choice.select(tunnel_choice.item_count-1)
	var editing_tunnel: bool=not brush_mode and selected>=0 and features[selected].kind=="tunnel"
	for button in tunnel_actions.get_children(): button.disabled=not editing_tunnel
	for index in [1,2]:
		tunnel_actions.get_child(index).disabled=not editing_tunnel or not features[selected].has("end_x")
		tunnel_actions.get_child(index).tooltip_text="Endpoint controls apply to straight entrance/exit tunnels; legacy curved tunnels can still be moved as a whole."
	tunnel_radius_control.editable=editing_tunnel or tunnel_new_armed
	if editing_tunnel: tunnel_radius_control.set_value_no_signal(features[selected].radius)
	if selected>=0:
		feature_list.select(selected)
	var values: Dictionary=brush_template if brush_mode else (features[selected] if selected>=0 else brush_template)
	simple_radius.set_value_no_signal(brush_template.radius)
	simple_strength.set_value_no_signal(brush_rate)
	shape_choice.select(["circle","square","ellipse"].find(brush_template.get("shape","circle")))
	aspect_control.set_value_no_signal(float(brush_template.get("aspect",1)))
	simple_brush_label.text="Selected: "+({"hill":"Raise terrain","lower":"Lower terrain"}.get(brush_template.kind,brush_template.kind) if brush_mode else "Advanced feature editing")
	if editing_tunnel: simple_brush_label.text="Editing existing tunnel %d (not creating)" % (selected+1)
	elif tunnel_new_armed: simple_brush_label.text="New tunnel armed: click entrance once"
	for key in fields: fields[key].value=values[key]
	marker.visible=selected>=0 and editing and not brush_mode
	if selected>=0: marker.position=Vector3(features[selected].x,features[selected].y,features[selected].z)
	updating=false

func add_feature(kind: String) -> void:
	if kind=="tunnel": arm_new_tunnel();return
	tunnel_new_armed=false;picking_entry=false
	finish_brush();flush_brush()
	if brush_mode:
		brush_template.kind=kind;brush_template.erase("amount")
		if kind=="carve": brush_template.localized=true
		else: brush_template.erase("localized")
		for key in ["end_x","end_y","end_z"]: brush_template.erase(key)
		refresh()
		if kind=="tunnel": brush_template.radius=4;refresh()
		notice.text="Brush: "+kind+" — hold left mouse on terrain; earlier strokes stay."
		if kind=="flatten": notice.text="FLATTEN: press at the desired height, then hold and drag. That level stays fixed for this stroke; strength controls how quickly it flattens."
		return
	var p := camera.position-camera.basis.z*25;p.y=0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,64,p.z),Vector3(p.x,-24,p.z),1))
	if not hit.is_empty(): p.y=hit.position.y
	if kind=="bridge": p.y+=8
	if kind=="tunnel": p.y+=5
	var added := Recipe.feature(kind,p)
	if kind in ["tunnel","carve"]: added.radius=4
	if kind=="ridge": added.radius=6
	var next := features.duplicate(true);next.append(added)
	selected=next.size()-1;change(next)
	selected=features.size()-1;refresh()

func edit_value(value: float, key: String) -> void:
	if updating: return
	if brush_mode: brush_template[key]=value;simple_radius.set_value_no_signal(brush_template.radius);return
	if selected<0: return
	var next := features.duplicate(true);next[selected][key]=value;change(next)

func delete_selected() -> void:
	finish_brush();flush_brush()
	if selected<0: return
	var next := features.duplicate(true);next.remove_at(selected);change(next)

func reorder(direction: int) -> void:
	finish_brush();flush_brush()
	if selected<0 or selected+direction<0 or selected+direction>=features.size(): return
	var next := features.duplicate(true);var temp: Dictionary=next[selected]
	next[selected]=next[selected+direction];next[selected+direction]=temp;selected+=direction;change(next)

func undo() -> void:
	finish_brush();flush_brush()
	if undo_stack.is_empty(): return
	redo_stack.append(features.duplicate(true));change(undo_stack.pop_back(),false)

func redo() -> void:
	finish_brush();flush_brush()
	if redo_stack.is_empty(): return
	undo_stack.append(features.duplicate(true));change(redo_stack.pop_back(),false)

func save() -> void:
	finish_brush();flush_brush()
	notice.text="Saved sdf-authoring.json in Godot user data." if Recipe.save_recipe(SAVE_PATH,features)==OK else "Save failed; recipe still in memory."

func load_saved() -> void:
	finish_brush();flush_brush()
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not Recipe.validate(data): notice.text="Invalid/missing recipe; current edits retained.";return
	change(data.features);notice.text="Loaded recipe. Undo restores previous edits."

func place_selected() -> void:
	if selected>=0:
		finish_brush();flush_brush();placing=true;picking_entry=false;picking_endpoint=false
		notice.text="MOVE existing feature (not a new stroke). Click terrain. Esc cancels."

func cursor_hit() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	if panel.visible and panel.get_global_rect().has_point(mouse): return {}
	var start := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(start,start+camera.project_ray_normal(mouse)*1500,1)
	query.exclude=[player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if editing and not collision_pending.is_empty() and not hit.is_empty():
		var current := field_cache.pick_surface(start,camera.project_ray_normal(mouse),start.distance_to(hit.position))
		if not current.is_empty(): return current
	return hit

func start_brush(hit_override := {}) -> void:
	var started := Time.get_ticks_usec()
	trace_edit("brush_pick_start")
	var hit: Dictionary=cursor_hit() if hit_override.is_empty() else hit_override
	if hit.is_empty(): return
	trace_edit("brush_down",{"pick_ms":(Time.get_ticks_usec()-started)/1000.0,"radius":brush_template.radius,"tool":brush_template.kind,"point":str(hit.position)})
	latest_input_usec=Time.get_ticks_usec()
	if brush_template.kind=="tunnel":
		if not tunnel_new_armed: return
		flush_brush()
		var f := brush_template.duplicate(true);f.erase("amount")
		var p: Vector3=hit.position
		f.x=p.x;f.y=p.y;f.z=p.z
		var end := suggested_exit(p,hit.normal)
		f.end_x=end.x;f.end_y=end.y;f.end_z=end.z
		var next := features.duplicate(true);next.append(f);selected=next.size()-1;change(next)
		select_tunnel(selected)
		return
	var source: Array=brush.draft if brush_dirty else features
	undo_stack.append(source.duplicate(true));redo_stack.clear()
	brush.begin(source,brush_template);brushing=true;brush_time=0
	brush.dab(hit.position,brush_rate/60.0);brush_dirty=true
	trace_edit("brush_input_done",{"input_ms":(Time.get_ticks_usec()-started)/1000.0})

func finish_brush() -> void:
	var started := Time.get_ticks_usec()
	brushing=false
	refresh()
	trace_edit("brush_up",{"ui_ms":(Time.get_ticks_usec()-started)/1000.0})

func suggested_exit(start: Vector3, normal: Vector3) -> Vector3:
	var best: Vector3 = start+(-camera.basis.z*Vector3(1,0,1)).normalized()*brush_template.length
	var best_distance := INF
	# Fixed-distance field probes, not unsafe sphere tracing of an approximate SDF.
	for i in 8:
		var direction := Vector3(cos(i*PI/4),0,sin(i*PI/4))
		if direction.dot(normal)>.1: continue
		var entered := false
		for step in range(2,257,2):
			var p := start+direction*step
			var value := Recipe.field(p,tunnel_radius,roughness,features)
			if value<-.1: entered=true
			elif entered and value>.1:
				if step<best_distance: best_distance=step;best=p+direction*2
				break
	return best

func endpoint_position() -> Vector3:
	var f: Dictionary=features[selected]
	return Vector3(f.end_x,f.end_y,f.end_z)

func snap_endpoint(p: Vector3) -> Vector3:
	if not Input.is_key_pressed(KEY_CTRL): return p
	var f: Dictionary=features[selected];var start := Vector3(f.x,f.y,f.z)
	if dragging_entry: start=Vector3(f.end_x,f.end_y,f.end_z)
	var offset := p-start;var length := Vector2(offset.x,offset.z).length()
	var angle := snappedf(atan2(offset.z,offset.x),PI/4)
	return Vector3(start.x+cos(angle)*length,p.y,start.z+sin(angle)*length)

func set_endpoint(p: Vector3) -> void:
	var next := features.duplicate(true);p=snap_endpoint(p)
	next[selected].end_x=p.x;next[selected].end_y=p.y;next[selected].end_z=p.z;change(next)

func set_tunnel_entry(p: Vector3) -> void:
	var next := features.duplicate(true)
	next[selected].x=p.x;next[selected].y=p.y;next[selected].z=p.z;change(next)

func tunnel_target_hit(mouse: Vector2, far_side: bool) -> Dictionary:
	if panel.visible and panel.get_global_rect().has_point(mouse): return {}
	if not far_side: return cursor_hit()
	var p: Variant=far_surface(mouse)
	if p==null: return {}
	var source := features.duplicate(true);source.remove_at(selected)
	var n := Vector3.ZERO
	for axis in 3:
		var e := Vector3.ZERO;e[axis]=.05
		n[axis]=Recipe.field(p+e,tunnel_radius,roughness,source)-Recipe.field(p-e,tunnel_radius,roughness,source)
	return {"position":p,"normal":n.normalized()}

func update_surface_cursor(hit: Dictionary) -> void:
	surface_cursor.visible=not hit.is_empty()
	if hit.is_empty(): return
	var n: Vector3=hit.normal.normalized()
	if n.length_squared()<.1: n=Vector3.UP
	var tangent := n.cross(Vector3.FORWARD if absf(n.z)<.9 else Vector3.UP).normalized()
	var radius: float=brush_template.radius if tunnel_new_armed else features[selected].radius
	surface_cursor.transform=Transform3D(Basis(tangent,n,tangent.cross(n)).scaled(Vector3.ONE*radius),hit.position+n*.06)

func update_endpoint_guide() -> void:
	var active: bool = editing and not brush_mode and selected>=0 and features[selected].has("end_x")
	endpoint_guide.visible=active;endpoint_handle.visible=active
	if not active: return
	var f: Dictionary=features[selected];var start := Vector3(f.x,f.y,f.z)
	if endpoint_dragging and dragging_entry: start=endpoint_preview
	var end := endpoint_preview if endpoint_dragging and not dragging_entry else endpoint_position()
	marker.position=start
	endpoint_handle.position=end
	var direction := (end-start).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared()<.01: side=Vector3.RIGHT
	var up := direction.cross(side).normalized()
	var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES);mesh.surface_set_color(Color.CYAN)
	mesh.surface_add_vertex(start);mesh.surface_add_vertex(end)
	for i in 32:
		var a: Vector3 = (side*cos(i*TAU/32)+up*sin(i*TAU/32))*f.radius
		var b: Vector3 = (side*cos((i+1)*TAU/32)+up*sin((i+1)*TAU/32))*f.radius
		for centre in [start,end]: mesh.surface_add_vertex(centre+a);mesh.surface_add_vertex(centre+b)
		if i%8==0: mesh.surface_add_vertex(start+a);mesh.surface_add_vertex(end+a)
	mesh.surface_end();endpoint_guide.mesh=mesh

func far_surface(mouse: Vector2) -> Variant:
	var start := camera.project_ray_origin(mouse);var direction := camera.project_ray_normal(mouse)
	var source := features.duplicate(true)
	if selected>=0: source.remove_at(selected)
	var entered := false
	for step in range(0,1500,2):
		var p := start+direction*step
		if Recipe.field(p,tunnel_radius,roughness,source)<0: entered=true
		elif entered: return p
	return null

func update_brush_outline(p: Vector3) -> void:
	brush_cursor.position=p+Vector3.UP*.15
	var signature := str([brush_template.radius,brush_template.get("shape","circle"),brush_template.get("aspect",1),brush_template.yaw])
	if signature==brush_outline_signature: return
	brush_outline_signature=signature
	var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var square: bool=brush_template.get("shape","circle")=="square"
	var segments := 4 if square else 48
	for i in segments:
		var a := Vector3(cos(i*TAU/segments),0,sin(i*TAU/segments))
		var b := Vector3(cos((i+1)*TAU/segments),0,sin((i+1)*TAU/segments))
		if square:
			var corners := [Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)]
			a=corners[i];b=corners[(i+1)%4]
		a.z*=brush_template.get("aspect",1);b.z*=brush_template.get("aspect",1)
		a=a.rotated(Vector3.UP,deg_to_rad(brush_template.yaw))*brush_template.radius
		b=b.rotated(Vector3.UP,deg_to_rad(brush_template.yaw))*brush_template.radius
		mesh.surface_add_vertex(a);mesh.surface_add_vertex(b)
	mesh.surface_end();brush_cursor.mesh=mesh;brush_cursor.material_override=chunk_overlay.material_override
	brush_cursor.position=p+Vector3.UP*.15;brush_cursor.scale=Vector3.ONE

func flush_brush() -> void:
	if not brush_dirty: return
	brush_dirty=false;change(brush.draft,false,not brushing,latest_input_usec)

func editor_fly(delta: float) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction-=camera.basis.z
	if Input.is_physical_key_pressed(KEY_S): direction+=camera.basis.z
	if Input.is_physical_key_pressed(KEY_A): direction-=camera.basis.x
	if Input.is_physical_key_pressed(KEY_D): direction+=camera.basis.x
	if Input.is_physical_key_pressed(KEY_SPACE): direction.y+=1
	if Input.is_physical_key_pressed(KEY_CTRL): direction.y-=1
	camera.position+=direction.normalized()*delta*fly_speed*(3 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)
	camera.position.x=clampf(camera.position.x,-740,740);camera.position.z=clampf(camera.position.z,-740,740)

func focus_selected() -> void:
	if selected<0: return
	var target := Vector3(features[selected].x,features[selected].y,features[selected].z)
	camera.position=target+Vector3(-28,25,-35);camera.look_at(target);look=Vector2(camera.rotation.y,camera.rotation.x)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F2 and loading_screen and loading_screen.ready_to_enter:
		if loading_screen.dismissed:
			finish_brush();flush_brush();looking=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;loading_screen.reopen()
		else:
			loading_screen.close();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if editing else Input.MOUSE_MODE_CAPTURED
		return
	if briefing_open(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		mark_operation();get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:
		show_chunks=not show_chunks;return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F1:
		if play_requested: play_requested=false;notice.text="Play request cancelled; editing remains available.";return
		finish_brush();flush_brush()
		if editing:
			play_requested=true;notice.text="Preparing play mode; live progress above. F1 cancels."
		else: switch_editor_mode(true)
		return
	if play_requested: return
	if not editing and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_B:
		throw_grenade();return
	if editing:
		if event is InputEventKey and event.pressed and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			brush_template.radius=clampf(brush_template.radius+(1 if event.keycode==KEY_BRACKETRIGHT else -1),1,120);refresh();return
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and not panel.get_global_rect().has_point(event.position):
			if event.shift_pressed:
				brush_template.radius=clampf(brush_template.radius+(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1),1,120);refresh();return
			var direction := camera.project_ray_normal(event.position)
			camera.position+=direction*(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1)*fly_speed*.25
			return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
			looking=event.pressed and not panel.get_global_rect().has_point(event.position)
			if looking:
				var focus := get_viewport().gui_get_focus_owner()
				if focus: focus.release_focus()
		if event is InputEventMouseMotion and looking:
			look.x-=event.relative.x*.003;look.y=clampf(look.y-event.relative.y*.003,-1.5,1.5);camera.rotation=Vector3(look.y,look.x,0)
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and endpoint_dragging:
			endpoint_dragging=false
			var initial := Vector3(features[selected].x,features[selected].y,features[selected].z) if dragging_entry else endpoint_position()
			if not endpoint_preview.is_equal_approx(initial):
				if dragging_entry: set_tunnel_entry(endpoint_preview)
				else: set_endpoint(endpoint_preview)
			dragging_entry=false;return
		if event is InputEventMouseMotion and endpoint_dragging:
			var point: Variant=endpoint_plane.intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
			if point!=null: endpoint_preview=snap_endpoint(point)
			return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not panel.get_global_rect().has_point(event.position) and not brush_mode and not placing and selected>=0 and features[selected].has("end_x"):
			# Handles take priority over surface placement: both interactions are
			# always available without switching tools. Choose nearest on screen.
			var entrance := Vector3(features[selected].x,features[selected].y,features[selected].z)
			var entry_distance := INF if camera.is_position_behind(entrance) else camera.unproject_position(entrance).distance_to(event.position)
			var exit_distance := INF if camera.is_position_behind(endpoint_position()) else camera.unproject_position(endpoint_position()).distance_to(event.position)
			if minf(entry_distance,exit_distance)<20:
				dragging_entry=entry_distance<exit_distance;picking_entry=dragging_entry;picking_endpoint=not dragging_entry
				endpoint_dragging=true;endpoint_preview=entrance if dragging_entry else endpoint_position();endpoint_plane=Plane(camera.basis.z,endpoint_preview)
				notice.text=("Entrance" if dragging_entry else "Exit")+" active: drag this centre point, or click a surface to place it."
				return
			if picking_entry:
				var hit := cursor_hit()
				if not hit.is_empty():
					set_tunnel_entry(hit.position)
				return
			else:
				var hit := tunnel_target_hit(event.position,event.alt_pressed)
				if not hit.is_empty(): set_endpoint(hit.position);picking_endpoint=true
				return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not placing and brush_mode:
			if event.pressed:
				if not panel.get_global_rect().has_point(event.position):
					var focus := get_viewport().gui_get_focus_owner()
					if focus: focus.release_focus()
					start_brush()
			else: finish_brush()
			return
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			finish_brush();looking=false;placing=false;dragging=false;endpoint_dragging=false;picking_endpoint=false;picking_entry=false
			if tunnel_new_armed: tunnel_new_armed=false;brush_mode=false;brush_mode_toggle.set_pressed_no_signal(false)
			refresh()
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			dragging=false
			reposition_selected(drag_position)
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position):
			if event.pressed and not placing and selected>=0 and not camera.is_position_behind(marker.position) and camera.unproject_position(marker.position).distance_to(event.position)<18:
				dragging=true;drag_position=marker.position
		if event is InputEventMouseMotion and dragging:
			var start := camera.project_ray_origin(event.position);var direction := camera.project_ray_normal(event.position)
			if absf(direction.y)>.01:
				var distance := (drag_position.y-start.y)/direction.y
				if distance>0:
					drag_position=start+direction*distance
					drag_position.x=clampf(drag_position.x,-740,740);drag_position.z=clampf(drag_position.z,-740,740)
					marker.position=drag_position
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and placing and not panel.get_global_rect().has_point(event.position):
			var start := camera.project_ray_origin(event.position)
			var query := PhysicsRayQueryParameters3D.create(start,start+camera.project_ray_normal(event.position)*1500,1)
			query.exclude=[player.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				reposition_selected(hit.position);placing=false
		return
	var kit := live_kit()
	if kit and kit.handle_input(event): return
	# Old demo hotkeys change an untracked base recipe; use authored features instead.
	if event is InputEventKey and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_R]: return
	super._input(event)

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	if briefing_open():
		if editing: settle_editor_contacts(delta)
		return
	if editing:
		settle_editor_contacts(delta)
		if play_requested: return
		editor_fly(delta)
		var hit := cursor_hit()
		var targeting := tunnel_new_armed or picking_entry or picking_endpoint
		if targeting and not endpoint_dragging:
			update_surface_cursor(tunnel_target_hit(get_viewport().get_mouse_position(),picking_endpoint and Input.is_key_pressed(KEY_ALT)))
		else: surface_cursor.hide()
		aim_valid=not hit.is_empty()
		if aim_valid: aim_point=hit.position
		brush_cursor.visible=brush_mode and not targeting and not hit.is_empty()
		if not hit.is_empty(): update_brush_outline(hit.position)
		if brushing and not hit.is_empty():
			brush_time+=delta
			if brush_time>=1.0/60.0:
				if not brush_dirty: latest_input_usec=Time.get_ticks_usec()
				brush.dab(hit.position,brush_rate*brush_time);brush_time=0;brush_dirty=true
		physics_ms=(Time.get_ticks_usec()-started)/1000.0
		return
	var kit := live_kit()
	if not editing and (not kit or not kit.own_movement()): super._physics_process(delta)

func resettle_edited_actors(kit: Node) -> void:
	# Explicit editor-to-play relocation, not live deformation under moving bodies.
	var bodies: Array=[];bodies.append_array(kit.vehicle_system.vehicles);bodies.append_array(kit.actors)
	for body in bodies:
		var affected := false
		for area in edited_bounds:
			if area.grow(12).has_point(Vector2(body.position.x,body.position.z)): affected=true;break
		if not affected: continue
		var top := -INF
		for x in [-3.0,0.0,3.0]:
			for z in [-4.0,0.0,4.0]:
				var p: Vector3=body.position+Vector3(x,0,z)
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,70,p.z),Vector3(p.x,-24,p.z),1))
				if not hit.is_empty(): top=maxf(top,hit.position.y)
		if is_finite(top): body.position.y=top+1.5
		if body is RigidBody3D:
			body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO;body.stream_velocity=Vector3.ZERO;body.stream_angular=Vector3.ZERO
	edited_bounds.clear()

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	grenade_cooldown=maxf(0,grenade_cooldown-delta)
	var gap_ms := (started-last_process_usec)/1000.0 if last_process_usec else 0.0
	last_process_usec=started
	# Let each in-flight preview finish: continuous strokes must not starve meshing
	# by invalidating its revision every input frame. Recipes still accumulate now.
	if brush_dirty and preview_expected.is_empty(): flush_brush()
	if not crater_queue.is_empty() and not brush_dirty and preview_expected.is_empty():
		var next := features.duplicate(true);next.append_array(crater_queue);crater_queue.clear();change(next,true,false)
	var submitted := Time.get_ticks_usec()
	super._process(delta)
	var streamed := Time.get_ticks_usec()
	pump_editor_collision()
	var collided := Time.get_ticks_usec()
	publish_preview()
	update_chunk_overlay()
	update_endpoint_guide()
	panel.position.x=maxf(0,get_viewport().get_visible_rect().size.x-panel.size.x-10)
	var kit := live_kit()
	if kit:
		kit.test_capture=editing or briefing_open()
		kit.health_hud.visible=not editing
		if kit.holder: kit.holder.visible=not editing and not briefing_open() and walking and not kit.own_movement()
		if editing: kit.crosshair.hide()
		for actor in kit.actors: actor.set_physics_process(not editing)
		if editing:
			for body in kit.vehicle_system.vehicles:
				body.controlled=false;body.set_controls(0,0,true)
				body.set_stream_ready(chunks.has(key_at(body.position)))
	if not editing: brush_cursor.hide()
	hud.text="SDF WORKSHOP / WASD fly | RMB look | LMB sculpt | F1 play\n%s / %.1f strength/s / radius %.1fm | features %d | %.0f FPS\n%s" % [brush_template.kind,brush_rate,brush_template.radius,features.size(),Engine.get_frames_per_second(),"Stroke queued; preview catching up" if brush_dirty else "Wheel zoom | Shift-wheel size | F3 chunks | Space/Ctrl rise/fall"]
	if kit and kit.vehicle_system.driving:
		var vehicle: RigidBody3D=kit.vehicle_system.driving
		hud.text+="\nCollision-ahead speed limit: %.1f m/s%s" % [vehicle.stream_speed_limit," / waiting for terrain" if vehicle.streaming_suspended else ""]
	if editing: hud.text+="\nPreview %.0f ms | warm %s | rebuilt %d/16 blocks | collision queue %d" % [preview_latency_ms,str(last_field_profile.get("warm_field",false)),last_field_profile.get("rebuilt_blocks",0),collision_pending.size()]
	hud.text+="\n"+operation_marker_status
	update_play_status()
	if not editing: hud.text+="\nB: grenade / queued craters %d" % crater_queue.size()
	var total_ms := (Time.get_ticks_usec()-started)/1000.0
	if gap_ms>80 or total_ms>40 or physics_ms>20:
		trace_edit("stall",{"frame_gap_ms":gap_ms,"process_ms":total_ms,"submit_ms":(submitted-started)/1000.0,"stream_ms":(streamed-submitted)/1000.0,"collision_ms":(collided-streamed)/1000.0,"physics_ms":physics_ms,"engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"engine_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
	if trace_file and started-trace_flush_usec>1000000: trace_file.flush();trace_flush_usec=started
	update_loading_screen()
	if OS.get_cmdline_user_args().has("--authoring-loading-check") and loading_screen and loading_screen.ready_to_enter and not loading_test_started:
		loading_test_started=true;check_loading_screen.call_deferred()

func check_loading_screen() -> void:
	assert(loading_screen.bar.value==100 and not loading_screen.enter.disabled and loading_screen.preview.texture!=null)
	assert(not live_kit().holder.visible,"Viewmodel visible while editing")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://workshop-loading-brief-check.png")
	loading_screen.close();assert(not briefing_open())
	loading_screen.reopen();assert(briefing_open())
	print("PASS: loading complete, briefing screenshot present, enter/reopen works, first-person viewmodel hidden in edit mode")
	get_tree().quit()

func remember_collision_support(key: Vector2i) -> void:
	var kit := live_kit()
	if not editing or not kit: return
	var bodies: Array=[];bodies.append_array(kit.vehicle_system.vehicles);bodies.append_array(kit.actors)
	for body in bodies:
		if key_at(body.position)!=key or collision_supports.has(body): continue
		var p: Vector3=body.position
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.5,p-Vector3.UP*3,1))
		if not hit.is_empty(): collision_supports[body]={"height":hit.position.y,"tick":Engine.get_physics_frames()}

func settle_editor_contacts(delta: float) -> void:
	var kit := live_kit()
	if not kit: return
	for body in collision_supports.keys():
		if not is_instance_valid(body): collision_supports.erase(body);continue
		var previous: Dictionary=collision_supports[body]
		if Engine.get_physics_frames()<=previous.tick+1: continue
		var p: Vector3=body.position
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,64,p.z),Vector3(p.x,-24,p.z),1))
		# Added solid cannot reliably push a buried rigid body out. Carry supported
		# objects up with the edited floor, but never snap them down into a cut.
		if not hit.is_empty() and hit.position.y>previous.height and p.y-previous.height<2 and (hit.position.y<=p.y+1.5 or Recipe.field(p+Vector3.UP*.5,tunnel_radius,roughness,features)<0):
			body.position.y+=hit.position.y-previous.height
			if body is RigidBody3D: body.sleeping=false
		collision_supports.erase(body)
	for actor in kit.actors:
		if chunks.has(key_at(actor.position)):
			actor.velocity.x=0;actor.velocity.z=0;actor.velocity.y-=20*delta;actor.move_and_slide()

func check_repeated_clicks() -> void:
	while ready_frames<3 or not live_kit(): await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--authoring-isolate"): await profile_frame_components()
	set_physics_process(false)
	var original := features.duplicate(true)
	brush_template=Recipe.feature("lower",Vector3.ZERO);brush_template.radius=16
	var before := preview_publications
	var started := Time.get_ticks_usec()
	var marker_key := InputEventKey.new();marker_key.keycode=KEY_F8;marker_key.pressed=true
	var original_revision := revision
	_input(marker_key)
	assert(operation_marker_started>0 and revision==original_revision,"BEGIN marker modified terrain")
	marker_key.echo=true;_input(marker_key);marker_key.echo=false
	assert(operation_marker_started>0,"Key repeat closed marker")
	for click in 20:
		start_brush({"position":Vector3(-32,0,-48),"normal":Vector3.UP})
		finish_brush()
		await get_tree().process_frame
	while brush_dirty or not preview_expected.is_empty() or not collision_pending.is_empty() or ready_frames<3: await get_tree().process_frame
	assert(features.size()==original.size()+20,"Rapid clicks lost edits")
	trace_edit("rapid_click_test",{"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"updates":preview_publications-before})
	_input(marker_key)
	assert(operation_marker_started==0,"END marker did not close interval")
	var recorded := []
	for line in FileAccess.get_file_as_string(trace_path).split("\n",false):
		var entry: Variant=JSON.parse_string(line)
		if entry is Dictionary and entry.get("event")=="operation_marker": recorded.append(entry)
	assert(recorded.size()==2 and recorded[0].phase=="BEGIN" and recorded[1].phase=="END" and recorded[0].marker_id==recorded[1].marker_id and recorded[1].elapsed_ms>0,"Marker pair was not flushed to disk")
	# Restore source then test physical response without editor-to-play relocation.
	change([],false)
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	set_physics_process(true)
	var kit := live_kit();var car: RigidBody3D=kit.vehicle
	for frame in 60: await get_tree().physics_frame
	var initial_y := car.position.y
	var cut := Recipe.feature("lower",car.position);cut.radius=12;cut.amount=4
	change([cut],false)
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	for frame in 120: await get_tree().physics_frame
	assert(not car.freeze and car.position.y<initial_y-1,"Editor vehicle did not fall into cut")
	var low_y := car.position.y
	change([],false)
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	for frame in 60: await get_tree().physics_frame
	assert(car.position.y>low_y+1,"Editor vehicle did not rise with restored ground")
	# Shared walk/fly controller must allow the valid -8..-24 m terrain band.
	editing=false;walking=false;camera.position=Vector3(-48,-18,-48)
	_physics_process(0)
	assert(camera.position.y< -17,"Deep-hole camera was teleported")
	editing=true
	trace_edit("repro_pass",{"vehicle_start_y":initial_y,"vehicle_hole_y":low_y,"vehicle_restored_y":car.position.y})
	print("PASS: 20 repeated 16m clicks retained; live editor vehicle falls and rises; deep-hole camera not teleported. Trace: ",trace_path)
	get_tree().quit()

func check_simple_ui() -> void:
	var original := features.duplicate(true)
	brush_mode=false;placing=true;picking_endpoint=true
	brush_template=Recipe.feature("tunnel",Vector3.ZERO);brush_template.end_x=12.0
	brush_template.shape="ellipse";brush_template.aspect=2.0
	select_simple_brush("hill")
	assert(brush_mode and brush_mode_toggle.button_pressed and not placing and not picking_endpoint)
	assert(brush_template.kind=="hill" and brush_template.shape=="circle" and not brush_template.has("end_x"))
	simple_radius.value=8;simple_strength.value=3
	assert(brush_template.radius==8 and brush_rate==3)
	select_simple_brush("lower")
	assert(brush_template.kind=="lower" and brush_template.radius==8 and features==original)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://sdf-authoring-simple-ui.png")
	print("PASS: simple Raise/Lower presets reset advanced modes without changing source; radius and strength controls; UI capture saved")
	get_tree().quit()

func wait_editor_idle() -> bool:
	var deadline := Time.get_ticks_msec()+120000
	while ready_frames<3 or not preview_expected.is_empty() or not collision_pending.is_empty() or brush_dirty or not crater_queue.is_empty():
		if Time.get_ticks_msec()>deadline:
			push_error("Editor queue failed to drain within 120 seconds");get_tree().quit(1);return false
		await get_tree().process_frame
	return true

func check_brush_recovery() -> void:
	while not live_kit(): await get_tree().process_frame
	set_physics_process(false)
	assert(await wait_editor_idle())
	var hill := Recipe.feature("hill",Vector3(-48,0,-48));hill.radius=20;hill.height=12
	change([hill],false);assert(await wait_editor_idle())
	var flat := Recipe.feature("flatten",Vector3(-48,5,-48));flat.radius=4;flat.amount=.2
	change([hill,flat],false)
	var footprint := preview_expected.keys()
	assert(footprint.size()<=4,"Small Flatten invalidated distant chunks")
	for i in 12:
		flat.amount+=.1;change([hill,flat],false)
		assert(preview_expected.keys()==footprint,"Resubmitting pending edits spread dirty chunk boundaries")
	assert(await wait_editor_idle())
	var before := preview_publications
	for kind in ["flatten","hill","lower"]:
		if kind=="flatten": add_feature(kind)
		else: select_simple_brush(kind)
		brush_template.radius=4
		start_brush({"position":Vector3(-48,5,-48),"normal":Vector3.UP})
		for i in 12: brush.dab(Vector3(-48+i*.1,5,-48),.05)
		finish_brush();flush_brush()
		assert(await wait_editor_idle())
		assert(preview_publications>before,"Brush failed after changing tools")
		before=preview_publications
	# Queue play during a real pending edit; it must enter automatically.
	flat.amount+=.1;change([hill,flat],false)
	var f1 := InputEventKey.new();f1.keycode=KEY_F1;f1.pressed=true;_input(f1)
	assert(play_requested and editing)
	assert(await wait_editor_idle())
	await get_tree().process_frame
	assert(not editing and not play_requested,"Queued F1 did not enter play")
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-48,60,-80),Vector3(-48,-22,-80),1))
	assert(not floor_hit.is_empty())
	camera.position=floor_hit.position+Vector3.UP*3;camera.look_at(floor_hit.position+Vector3(0,0,-5))
	assert(await wait_editor_idle())
	var count := features.size()
	var throw_key := InputEventKey.new();throw_key.keycode=KEY_B;throw_key.pressed=true;_input(throw_key)
	var deadline := Time.get_ticks_msec()+15000
	while features.size()==count:
		if Time.get_ticks_msec()>deadline: push_error("Grenade did not submit a crater");get_tree().quit(1);return
		await get_tree().process_frame
	assert(await wait_editor_idle())
	await get_tree().physics_frame
	var crater: Dictionary=features[-1]
	assert(crater.kind=="carve" and crater.localized and crater.radius==2)
	var from := Vector3(crater.x,64,crater.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+Vector3.DOWN*87,1))
	var sampled := field_cache.pick_surface(from,Vector3.DOWN,64-crater.y)
	assert(not hit.is_empty() and not sampled.is_empty() and absf(hit.position.y-sampled.position.y)<.03,"Grenade collision differs from generated surface")
	assert(not request_crater(Vector3(0,-24,0),2),"Grenade can cut through volume bottom")
	_input(f1);assert(editing)
	print("PASS: Flatten remains local; unfinished edits do not spread; Flatten/Raise/Lower publish; queued F1 enters; B grenade creates matching mesh/collision; bottom guarded")
	get_tree().quit()

func check_tunnel_editing() -> void:
	set_physics_process(false)
	var hill := Recipe.feature("hill",Vector3(-48,0,-48));hill.radius=30;hill.height=18
	var tunnel := Recipe.feature("tunnel",Vector3(-60,6,-48));tunnel.radius=3
	tunnel.end_x=-36.0;tunnel.end_y=6.0;tunnel.end_z=-48.0
	change([hill,tunnel],false);select_tunnel(1)
	assert(not brush_mode and not tunnel_new_armed and features.size()==2)
	# Centre grabs take priority even while surface targeting is active.
	var saved_camera := camera.transform;var saved_panel := panel.position
	camera.position=Vector3(-48,26,-70);camera.look_at(Vector3(-48,6,-48));panel.position.x=5000
	for entry in [true,false]:
		var centre := Vector3(tunnel.x,tunnel.y,tunnel.z) if entry else Vector3(tunnel.end_x,tunnel.end_y,tunnel.end_z)
		var press := InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=camera.unproject_position(centre)
		_input(press)
		assert(endpoint_dragging and dragging_entry==entry,"Centre handle did not win over surface targeting")
		var motion := InputEventMouseMotion.new();motion.position=press.position+Vector2(8,4);_input(motion)
		assert(endpoint_preview.distance_to(centre)>.01,"Centre drag did not move preview")
		var release := InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=motion.position;_input(release)
		assert(not endpoint_dragging and features.size()==2)
		undo();select_tunnel(1)
	update_surface_cursor({"position":Vector3(-48,6,-48),"normal":Vector3.RIGHT})
	assert(surface_cursor.basis.y.normalized().dot(Vector3.RIGHT)>.999,"Target circle not aligned to vertical wall")
	camera.transform=saved_camera;panel.position=saved_panel;surface_cursor.hide()
	assert(Recipe.field(Vector3(-48,6,-48),tunnel_radius,roughness,features)>0)
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	await get_tree().physics_frame
	var old_roof := PhysicsRayQueryParameters3D.create(Vector3(-48,6,-48),Vector3(-48,12,-48),1)
	assert(not get_world_3d().direct_space_state.intersect_ray(old_roof).is_empty(),"Initial tunnel roof missing")
	reposition_selected(Vector3(-60,6,-36))
	assert(features.size()==2 and features[1].end_z==-36 and features[1].end_x==-36)
	assert(Recipe.field(Vector3(-48,6,-48),tunnel_radius,roughness,features)<0,"Old tunnel cut remained")
	assert(Recipe.field(Vector3(-48,6,-36),tunnel_radius,roughness,features)>0,"Moved tunnel missing")
	undo();assert(features[1].z==-48 and features[1].end_z==-48)
	redo();assert(features[1].z==-36 and features[1].end_z==-36)
	set_endpoint(Vector3(-34,7,-35))
	assert(features.size()==2 and features[1].x==-60 and features[1].end_x==-34)
	tunnel_radius_control.value=4
	assert(features[1].radius==4 and features.size()==2)
	# A normal click after creation must not append another cut.
	arm_new_tunnel()
	start_brush({"position":Vector3(-48,10,-48),"normal":Vector3.UP})
	assert(features.size()==3 and not brush_mode and not tunnel_new_armed)
	start_brush({"position":Vector3(-40,10,-48),"normal":Vector3.UP})
	assert(features.size()==3,"Editing created an accidental extra tunnel")
	arm_new_tunnel()
	var escape := InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;_input(escape)
	assert(not tunnel_new_armed and features.size()==3)
	# Restore deterministic moved tunnel and await the actual mesh/collision.
	change([hill,tunnel],false);select_tunnel(1);reposition_selected(Vector3(-60,6,-36))
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var new_cut := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-59,6,-36),Vector3(-37,6,-36),1))
	assert(new_cut.is_empty(),"Moved tunnel collision is blocked")
	assert(space.intersect_ray(old_roof).is_empty(),"Old tunnel cavity collision survived the move")
	# Ray from old cavity upwards must now start inside solid; use a top-down
	# hit as an unambiguous check of the rebuilt hill surface instead.
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-48,30,-48),Vector3(-48,-20,-48),1))
	assert(not ground.is_empty() and ground.position.y>14,"Old tunnel region did not restore hill")
	# Let the asynchronously imported live kit finish before clean shutdown.
	while not live_kit(): await get_tree().process_frame
	print("PASS: tunnel move replaces old cut; both endpoints translate; endpoint/radius edits and undo/redo retain feature count; creation disarms; moved collision clear")
	get_tree().quit()

func profile_frame_components() -> void:
	# Diagnostic only: keep simulation running and restore visibility afterwards.
	# Within-run comparisons avoid mistaking changing machine load for edit speed.
	var visuals := []
	for entry in arena_content.entries: visuals.append([entry.root,entry.root.visible])
	var ring_visible := ring_background.visible
	var disabled := get_viewport().disable_3d
	for mode in ["full_scene","actors_hidden","ring_and_actors_hidden","render_3d_disabled","full_scene_restored"]:
		for pair in visuals: pair[0].visible=pair[1] if mode in ["full_scene","full_scene_restored"] else false
		ring_background.visible=ring_visible if mode in ["full_scene","actors_hidden","full_scene_restored"] else false
		get_viewport().disable_3d=mode=="render_3d_disabled"
		for warmup in 5: await get_tree().process_frame
		var gaps := [];var process := [];var physics := []
		var previous := Time.get_ticks_usec()
		for frame in 30:
			await get_tree().process_frame
			var now := Time.get_ticks_usec();gaps.append((now-previous)/1000.0);previous=now
			process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		gaps.sort();process.sort();physics.sort()
		var report := {"mode":mode,"frame_median_ms":gaps[15],"frame_p95_ms":gaps[28],"engine_process_median_ms":process[15],"engine_physics_median_ms":physics[15]}
		trace_edit("component_profile",report);print("COMPONENT_PROFILE ",JSON.stringify(report))
	get_viewport().disable_3d=disabled

func check_workshop() -> void:
	while ready_frames<3 or not collision_pending.is_empty() or not live_kit(): await get_tree().process_frame
	var baseline := features.duplicate(true)
	var latency := []
	set_physics_process(false) # Inject deterministic editor deltas, not mouse-position-dependent dabs.
	var trial_offset := float(Time.get_ticks_usec()%1000000)/100000000.0
	brushing=true;brush.previous=Vector3(-48,0,-48)
	for dose in range(1,7):
		var stamp := Recipe.feature("lower",brush.previous);stamp.radius=4;stamp.amount=float(dose)*.5+trial_offset
		latest_input_usec=Time.get_ticks_usec()
		change(baseline+[stamp],false)
		while not preview_expected.is_empty(): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		latency.append((Time.get_ticks_usec()-latest_input_usec)/1000.0)
	brushing=false;change(baseline,false)
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	# Continuous input, not a sequence of edits each waiting for the last to finish.
	var tool := Recipe.feature("lower",Vector3.ZERO);tool.radius=4
	brush.begin(baseline,tool);brush.previous=Vector3(-36,0,-48);brushing=true
	var publications_before := preview_publications
	for tick in 60:
		if not brush_dirty: latest_input_usec=Time.get_ticks_usec()
		brush.dab(Vector3(-36+tick*8.0/59,0,-48),4.0/60.0);brush_dirty=true
		await get_tree().physics_frame
	var live_updates := preview_publications-publications_before
	var released := Time.get_ticks_usec()
	finish_brush();flush_brush()
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	var release_ms := (Time.get_ticks_usec()-released)/1000.0
	var amount := 0.0
	for feature in features.slice(baseline.size()): amount+=feature.amount
	assert(absf(amount-4)<.00001,"Continuous stroke lost input strength")
	assert(live_updates>=2,"Continuous stroke did not publish while held")
	for x in [-32.01,-31.99]:
		var from := Vector3(x,40,-48)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+Vector3.DOWN*63,1))
		var expected := field_cache.pick_surface(from,Vector3.DOWN,40)
		assert(not hit.is_empty() and not expected.is_empty() and absf(hit.position.y-expected.position.y)<.02,"Accumulated collision differs at stroke seam")
	print("CONTINUOUS_BRUSH updates=",live_updates," strength=",amount," release_to_collision_ms=",release_ms)
	change(baseline,false)
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	var timing_file := FileAccess.open("user://sdf-edit-latency.json",FileAccess.WRITE)
	timing_file.store_string(JSON.stringify({"warm_stroke_to_draw_ms":latency,"continuous_updates":live_updates,"continuous_strength":amount,"release_to_collision_ms":release_ms,"last_field_profile":last_field_profile},"\t"));timing_file.close()
	print("EDIT_TO_DRAW_MS ",latency)
	set_physics_process(true)
	var original_transform := camera.transform
	var wheel := InputEventMouseButton.new();wheel.position=Vector2(100,300);wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	_input(wheel);assert(camera.transform!=original_transform)
	var old_radius: float=brush_template.radius;wheel.shift_pressed=true;_input(wheel);assert(brush_template.radius==old_radius+1)
	brush_template.radius=old_radius;camera.transform=original_transform
	show_chunks=true;update_chunk_overlay();assert(chunk_overlay.mesh!=null)
	var original := features.duplicate(true)
	var f := Recipe.feature("hill",Vector3(-40,0,-40));f.radius=12;f.height=10
	change([f]);undo();assert(features==original);redo();assert(features.size()==1)
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	await get_tree().physics_frame
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40,40,-40),Vector3(-40,-20,-40),1))
	assert(not hit.is_empty() and absf(hit.position.y-10)<.2)
	assert(Recipe.save_recipe("user://sdf-authoring-test.json",features)==OK)
	assert(Recipe.validate(JSON.parse_string(FileAccess.get_file_as_string("user://sdf-authoring-test.json"))))
	var tunnel := Recipe.feature("tunnel",Vector3(-40,5,-40));tunnel.radius=3
	var bridge := Recipe.feature("bridge",Vector3(-40,20,-70));bridge.height=20
	change([f,tunnel,bridge])
	while ready_frames<3 or not collision_pending.is_empty(): await get_tree().process_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-58,5,-40),Vector3(-22,5,-40),1)).is_empty())
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40,5,-40),Vector3(-40,15,-40),1))
	assert(not roof.is_empty() and roof.position.y>7)
	var deck := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40,25,-70),Vector3(-40,15,-70),1))
	assert(not deck.is_empty() and absf(deck.position.y-20)<.1)
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-50,10,-70),Vector3(-30,10,-70),1)).is_empty())
	var kit := live_kit();resettle_edited_actors(kit)
	editing=false;panel.hide();kit.test_capture=false
	for i in 120: await get_tree().physics_frame
	kit.enter_vehicle();kit.test_vehicle_controls=true
	var start: Vector3=kit.vehicle.position
	for i in 180: await get_tree().physics_frame
	assert(kit.vehicle.position.distance_to(start)>1,"Vehicle did not move in play mode")
	var vehicle_transform: Transform3D=kit.vehicle.transform
	kit.vehicle.position.x=movement_limit()+20;kit.vehicle.linear_velocity=Vector3(20,0,0)
	kit.vehicle_system.tick(1.0/60,true)
	assert(kit.vehicle.position.x<=movement_limit()-8 and kit.vehicle.linear_velocity.x<=0,"Vehicle escaped finite terrain domain")
	kit.vehicle.transform=vehicle_transform;kit.vehicle.set_stream_ready(true)
	kit.test_vehicle_controls=false;kit.release_control();editing=true;panel.show();selected=2;refresh()
	print("PASS: workshop undo/redo, hill/tunnel/bridge collision, recipe save/load, live Warthog movement, boundary guard, wheel zoom/size, chunk outlines")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://sdf-authoring.png")
	get_tree().quit()
