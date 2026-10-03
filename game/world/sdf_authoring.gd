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

func make_arena_content() -> Node:
	return preload("res://world/arena_live_content.gd").new()

func live_kit() -> Node:
	return arena_content.kit if is_instance_valid(arena_content) and arena_content.get("kit") and arena_content.kit.initialized else null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if Recipe.validate(saved): features=saved.features
	super._ready()
	make_panel()
	var sphere := SphereMesh.new();sphere.radius=.7;sphere.height=1.4
	marker.mesh=sphere
	var mat := StandardMaterial3D.new();mat.albedo_color=Color.ORANGE;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override=mat;add_child(marker)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	refresh()
	DisplayServer.window_set_title("SDF recipe workshop / F1 edit or play")
	if OS.get_cmdline_user_args().has("--authoring-check"): check_workshop.call_deferred()

func rebuild() -> void:
	revision+=1
	ready_frames=0

func chunk_layout() -> Dictionary:
	return {"bottom":-24.0,"cells":Vector3i(16,44,16),"spacing":2.0}

func movement_limit() -> float:
	return 740.0

func desired() -> Array[Vector2i]:
	var keys := super.desired()
	var centre := key_at(camera.position)
	for z in range(-2,3):
		for x in range(-2,3):
			var key := centre+Vector2i(x,z)
			if absi(key.x)<24 and absi(key.y)<24 and key not in keys: keys.append(key)
	var kit := live_kit()
	if kit:
		for body in kit.vehicle_system.vehicles:
			var ahead: Vector3=body.position+body.linear_velocity*4
			for point in [body.position,ahead]:
				var centre_key := key_at(point)
				for z in range(-2,3):
					for x in range(-2,3):
						var key := centre_key+Vector2i(x,z)
						if absi(key.x)<24 and absi(key.y)<24 and key not in keys: keys.append(key)
	return keys

func neighborhood_ready(p: Vector3) -> bool:
	var centre := key_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			var key := centre+Vector2i(x,z)
			if not chunks.has(key) or chunks[key].revision!=revision: return false
	return true

func chunk_sampler() -> Callable:
	# Snapshot on the main thread, never read mutable editor data from a worker.
	return Recipe.field.bind(features.duplicate(true))

func generate(radius: float, detail: float, origin := ORIGIN, cells := CELLS, spacing := 1.0, sampler := Callable()) -> Dictionary:
	var snapshot: Array=sampler.get_bound_arguments()[0]
	var local := Recipe.relevant(snapshot,Rect2(Vector2(origin.x,origin.z),Vector2(cells.x,cells.z)*spacing).grow(.1))
	var path := CACHE_PATH+Recipe.cache_key(local,origin,cells,spacing,radius,detail)+".bin"
	if FileAccess.file_exists(path):
		var reader := FileAccess.open(path,FileAccess.READ)
		if reader:
			var data: Variant=reader.get_var(false)
			if data is Dictionary and data.get("vertices") is PackedVector3Array and data.get("normals") is PackedVector3Array and data.get("indices") is PackedInt32Array:
				var valid: bool=data.vertices.size()==data.normals.size() and data.indices.size()%3==0
				for index in data.indices:
					if index<0 or index>=data.vertices.size(): valid=false;break
				if valid:
					data.ms=0;data.cached=true;return data
	var result := preload("res://world/tetra_mesher.gd").build(Recipe.field.bind(radius,detail,local),origin,cells,spacing)
	var writer := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if writer:
		writer.store_var(result,false);writer.close()
		DirAccess.rename_absolute(path+".tmp",path)
	return result

func chunk_generated(result: Dictionary) -> void:
	if result.get("cached",false): cache_reads+=1
	else: cache_builds+=1

func change(next: Array, remember := true) -> void:
	if remember:
		undo_stack.append(features.duplicate(true));redo_stack.clear()
	var changed := []
	# Conservatively invalidate both old and new footprints, but retain unrelated chunks.
	for i in maxi(features.size(),next.size()):
		if i<features.size() and i<next.size() and features[i]==next[i]: continue
		if i<features.size(): changed.append(Recipe.bounds(features[i]).grow(2))
		if i<next.size(): changed.append(Recipe.bounds(next[i]).grow(2))
	features=next.duplicate(true);revision+=1;ready_frames=0
	edited_bounds.append_array(changed)
	for key in chunks:
		var dirty := false
		for area in changed:
			if area.intersects(Rect2(Vector2(key)*CHUNK,Vector2.ONE*CHUNK)): dirty=true;break
		if not dirty: chunks[key].revision=revision
	selected=mini(selected,features.size()-1)
	refresh()
	notice.text="Edited — Save to keep recipe. Old meshes retained on disk."

func make_panel() -> void:
	panel=PanelContainer.new();panel.position=Vector2(550,100);panel.size=Vector2(400,480)
	var canvas := CanvasLayer.new();add_child(canvas);canvas.add_child(panel)
	var column := VBoxContainer.new();panel.add_child(column)
	var title := Label.new();title.text="SDF RECIPE / F1 edit-play";column.add_child(title)
	var tools := HFlowContainer.new();column.add_child(tools)
	for kind in Recipe.TYPES:
		var button := Button.new();button.text=kind;tools.add_child(button);button.pressed.connect(add_feature.bind(kind))
	feature_list=ItemList.new();feature_list.custom_minimum_size=Vector2(270,85);column.add_child(feature_list)
	feature_list.item_selected.connect(func(index: int): selected=index;refresh())
	var grid := GridContainer.new();grid.columns=4;column.add_child(grid)
	for key in ["x","y","z","radius","height","length","width","thickness","yaw","bend"]:
		var label := Label.new();label.text=key;grid.add_child(label)
		var value := SpinBox.new();value.min_value=-740;value.max_value=740;value.step=1;value.custom_minimum_size.x=78
		if key in ["radius","height","length","width","thickness"]: value.min_value=1;value.max_value=120
		if key=="y": value.min_value=-20;value.max_value=55
		grid.add_child(value);fields[key]=value;value.value_changed.connect(edit_value.bind(key))
	var actions := HFlowContainer.new();column.add_child(actions)
	for spec in [["Place",place_selected],["Focus",focus_selected],["Delete",delete_selected],["Earlier",reorder.bind(-1)],["Later",reorder.bind(1)],["Undo",undo],["Redo",redo],["Save",save],["Load",load_saved]]:
		var button := Button.new();button.text=spec[0];actions.add_child(button);button.pressed.connect(spec[1])
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.x=270
	notice.text="Add a feature; edit numbers or Place on terrain. Save explicitly."
	column.add_child(notice)

func refresh() -> void:
	if feature_list==null: return
	if selected<0 and not features.is_empty(): selected=0
	updating=true;feature_list.clear()
	for i in features.size(): feature_list.add_item("%d  %s" % [i+1,features[i].kind])
	if selected>=0:
		feature_list.select(selected)
		for key in fields: fields[key].value=features[selected][key]
	marker.visible=selected>=0 and editing
	if selected>=0: marker.position=Vector3(features[selected].x,features[selected].y,features[selected].z)
	updating=false

func add_feature(kind: String) -> void:
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
	if updating or selected<0: return
	var next := features.duplicate(true);next[selected][key]=value;change(next)

func delete_selected() -> void:
	if selected<0: return
	var next := features.duplicate(true);next.remove_at(selected);change(next)

func reorder(direction: int) -> void:
	if selected<0 or selected+direction<0 or selected+direction>=features.size(): return
	var next := features.duplicate(true);var temp: Dictionary=next[selected]
	next[selected]=next[selected+direction];next[selected+direction]=temp;selected+=direction;change(next)

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(features.duplicate(true));change(undo_stack.pop_back(),false)

func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(features.duplicate(true));change(redo_stack.pop_back(),false)

func save() -> void:
	notice.text="Saved sdf-authoring.json in Godot user data." if Recipe.save_recipe(SAVE_PATH,features)==OK else "Save failed; recipe still in memory."

func load_saved() -> void:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not Recipe.validate(data): notice.text="Invalid/missing recipe; current edits retained.";return
	change(data.features);notice.text="Loaded recipe. Undo restores previous edits."

func place_selected() -> void:
	if selected>=0: placing=true;notice.text="Click terrain to position selected feature. Esc cancels."

func focus_selected() -> void:
	if selected<0: return
	var target := Vector3(features[selected].x,features[selected].y,features[selected].z)
	camera.position=target+Vector3(-28,25,-35);camera.look_at(target);look=Vector2(camera.rotation.y,camera.rotation.x)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_F1:
		if editing and ready_frames<3:
			notice.text="Wait for edited collision to finish before playing.";return
		var kit := live_kit()
		if kit:
			kit.release_control()
			if editing: resettle_edited_actors(kit)
		editing=not editing;panel.visible=editing;placing=false;dragging=false;walking=false
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if editing else Input.MOUSE_MODE_CAPTURED
		refresh();return
	if editing:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			placing=false;dragging=false;refresh()
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			dragging=false
			var next := features.duplicate(true);next[selected].x=drag_position.x;next[selected].z=drag_position.z;change(next)
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
				var next := features.duplicate(true);next[selected].x=hit.position.x;next[selected].y=hit.position.y;next[selected].z=hit.position.z
				change(next);placing=false
		return
	var kit := live_kit()
	if kit and kit.handle_input(event): return
	# Old demo hotkeys change an untracked base recipe; use authored features instead.
	if event is InputEventKey and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_R]: return
	super._input(event)

func _physics_process(delta: float) -> void:
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
	super._process(delta)
	panel.position.x=maxf(0,get_viewport().get_visible_rect().size.x-panel.size.x-10)
	var kit := live_kit()
	if kit:
		kit.test_capture=editing
		kit.health_hud.visible=not editing
		if editing: kit.crosshair.hide()
		for actor in kit.actors: actor.set_physics_process(not editing)
		if editing:
			for body in kit.vehicle_system.vehicles: body.set_stream_ready(false)
	hud.text="SDF WORKSHOP / F1 edit-play | WASD + mouse fly | F walk\nRecipe features %d | cache %d / generated %d | %d chunks | %.0f FPS\n2m samples / vertical range -24..64m / drag orange centre or Place" % [features.size(),cache_reads,cache_builds,chunks.size(),Engine.get_frames_per_second()]

func check_workshop() -> void:
	while ready_frames<3 or not live_kit(): await get_tree().process_frame
	var original := features.duplicate(true)
	var f := Recipe.feature("hill",Vector3(-40,0,-40));f.radius=12;f.height=10
	change([f]);undo();assert(features==original);redo();assert(features.size()==1)
	while ready_frames<3: await get_tree().process_frame
	await get_tree().physics_frame
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40,40,-40),Vector3(-40,-20,-40),1))
	assert(not hit.is_empty() and absf(hit.position.y-10)<.2)
	assert(Recipe.save_recipe("user://sdf-authoring-test.json",features)==OK)
	assert(Recipe.validate(JSON.parse_string(FileAccess.get_file_as_string("user://sdf-authoring-test.json"))))
	var tunnel := Recipe.feature("tunnel",Vector3(-40,5,-40));tunnel.radius=3
	var bridge := Recipe.feature("bridge",Vector3(-40,20,-70));bridge.height=20
	change([f,tunnel,bridge])
	while ready_frames<3: await get_tree().process_frame
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
	kit.test_vehicle_controls=false;kit.release_control();editing=true;panel.show();selected=2;refresh()
	print("PASS: workshop undo/redo, hill/tunnel/bridge collision, recipe save/load, live Warthog movement")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://sdf-authoring.png")
	get_tree().quit()
