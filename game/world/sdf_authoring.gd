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

func stream_worker_limit() -> int:
	return 2

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
	var cursor_mesh := SphereMesh.new();cursor_mesh.radius=1;cursor_mesh.height=2
	brush_cursor.mesh=cursor_mesh
	var cursor_mat := StandardMaterial3D.new();cursor_mat.albedo_color=Color(1,.65,.1,.22);cursor_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;cursor_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	brush_cursor.material_override=cursor_mat;add_child(brush_cursor)
	add_child(chunk_overlay)
	var line_material := StandardMaterial3D.new();line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_material.vertex_color_use_as_albedo=true;line_material.no_depth_test=true
	chunk_overlay.material_override=line_material
	add_child(endpoint_guide);endpoint_guide.material_override=line_material
	endpoint_handle.mesh=cursor_mesh;endpoint_handle.material_override=line_material;add_child(endpoint_handle)
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
			if not chunks.has(key) or chunks[key].revision!=revision: return false
	return true

func chunk_sampler() -> Callable:
	# Snapshot on the main thread, never read mutable editor data from a worker.
	return Recipe.field.bind(features.duplicate(true))

static func cached_path(local: Array, origin: Vector3, cells: Vector3i, spacing: float, radius: float, detail: float) -> String:
	var version := FileAccess.get_file_as_string("res://world/sdf_field_cache.gd").sha256_text()
	return CACHE_PATH+(version+Recipe.cache_key(local,origin,cells,spacing,radius,detail)).sha256_text()+".bin"

func generate(radius: float, detail: float, origin := ORIGIN, cells := CELLS, spacing := 1.0, sampler := Callable()) -> Dictionary:
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
					data.ms=0;data.cached=true;data.profile={"warm_field":true,"base_evaluations":0,"rebuilt_blocks":0,"disk_restore":true};return data
	var result := field_cache.build(origin,cells,spacing,local,radius,detail)
	var writer := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if writer:
		writer.store_var(result,false);writer.close()
		DirAccess.rename_absolute(path+".tmp",path)
	return result

func chunk_generated(result: Dictionary) -> void:
	last_field_profile=result.get("profile",{})
	if result.get("cached",false): cache_reads+=1
	else: cache_builds+=1

func install(key: Vector2i, result: Dictionary) -> void:
	if editing and chunks.has(key):
		# Visual feedback is independent of expensive physics construction.
		var mesh := ArrayMesh.new()
		if not result.vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_arrays(result))
		chunks[key].revision=active_revision;chunks[key].triangles=triangle_count(result)
		preview_meshes[key]={"mesh":mesh,"parts":result._field_state.parts}
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
	preview_meshes.clear();preview_expected.clear()

func queue_editor_collision(key: Vector2i, parts: Dictionary) -> void:
	# Compare with LIVE collision, not the last generated revision: several visual
	# updates may have accumulated while a stroke held physics work back.
	if collision_pending.has(key):
		for body in collision_pending[key].staged.values(): body.queue_free()
	var old_parts: Dictionary=chunks[key].get("collision_parts",{})
	var dirty := []
	for id in parts:
		if not old_parts.has(id) or old_parts[id].vertices!=parts[id].vertices or old_parts[id].indices!=parts[id].indices: dirty.append(id)
	collision_pending[key]={"parts":parts,"dirty":dirty,"staged":{},"tick":-1}

func pump_editor_collision() -> void:
	if brushing or brush_dirty or collision_pending.is_empty(): return
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

func change(next: Array, remember := true, update_ui := true) -> void:
	if remember:
		undo_stack.append(features.duplicate(true));redo_stack.clear()
	var changed := []
	for key in preview_expected: changed.append(Rect2(Vector2(key)*CHUNK,Vector2.ONE*CHUNK).grow(.1))
	preview_expected.clear();preview_meshes.clear()
	# Conservatively invalidate both old and new footprints, but retain unrelated chunks.
	for i in maxi(features.size(),next.size()):
		if i<features.size() and i<next.size() and features[i]==next[i]: continue
		if i<features.size(): changed.append(field_cache.influence(features[i]).grow(2.1))
		if i<next.size(): changed.append(field_cache.influence(next[i]).grow(2.1))
	if edit_started_usec==0: edit_started_usec=latest_input_usec if latest_input_usec>0 else Time.get_ticks_usec()
	features=next.duplicate(true);revision+=1;ready_frames=0
	# Unrelated background jobs still have valid snapshots; don't discard them
	# merely because a nearby stroke advanced the global editor revision.
	for job in stream_jobs:
		var dirty := false
		for area in changed:
			if area.intersects(Rect2(Vector2(job.key)*CHUNK,Vector2.ONE*CHUNK)): dirty=true;break
		if not dirty: job.revision=revision
	edited_bounds.append_array(changed)
	for key in chunks:
		var dirty := false
		for area in changed:
			if area.intersects(Rect2(Vector2(key)*CHUNK,Vector2.ONE*CHUNK)): dirty=true;break
		if not dirty: chunks[key].revision=revision
		else: preview_expected[key]=true
	selected=mini(selected,features.size()-1)
	if update_ui: refresh()
	notice.text="Edited — Save to keep recipe. Old meshes retained on disk."

func make_panel() -> void:
	panel=PanelContainer.new();panel.position=Vector2(550,100);panel.size=Vector2(400,480)
	var canvas := CanvasLayer.new();add_child(canvas);canvas.add_child(panel)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size=Vector2(400,470);panel.add_child(scroll)
	var column := VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	var title := Label.new();title.text="SDF RECIPE / F1 edit-play";column.add_child(title)
	var toggle := CheckButton.new();toggle.text="Brush (off = edit/move features)";toggle.button_pressed=true;column.add_child(toggle)
	toggle.toggled.connect(func(value: bool): finish_brush();flush_brush();brush_mode=value;refresh())
	var debug_button := Button.new();debug_button.text="F3 chunk outlines / cyan ready, orange pending";column.add_child(debug_button)
	debug_button.pressed.connect(func(): show_chunks=not show_chunks)
	var shape_row := HBoxContainer.new();column.add_child(shape_row)
	var shapes := OptionButton.new()
	for label in ["circle","square","ellipse"]: shapes.add_item(label)
	shape_row.add_child(shapes)
	shapes.item_selected.connect(func(index: int): brush_template.shape=["circle","square","ellipse"][index])
	var aspect_label := Label.new();aspect_label.text="Ellipse ratio";shape_row.add_child(aspect_label)
	var aspect := SpinBox.new();aspect.min_value=.25;aspect.max_value=4;aspect.step=.25;aspect.value=1;shape_row.add_child(aspect)
	aspect.value_changed.connect(func(value: float): brush_template.aspect=value)
	var end_button := Button.new();end_button.text="Set tunnel exit (Alt-click = far surface)";column.add_child(end_button)
	end_button.pressed.connect(func(): picking_endpoint=true;notice.text="Click exit surface; Alt-click looks through the near surface. Ctrl snaps heading to 45 degrees.")
	var rates := HBoxContainer.new();column.add_child(rates)
	for spec in [["Strength/s",4.0],["Fly m/s",25.0]]:
		var label := Label.new();label.text=spec[0];rates.add_child(label)
		var speed := SpinBox.new();speed.min_value=.25;speed.max_value=100;speed.step=.25;speed.value=spec[1];rates.add_child(speed)
		if spec[0]=="Strength/s": speed.value_changed.connect(func(value: float): brush_rate=value)
		else: speed.value_changed.connect(func(value: float): fly_speed=value)
	var tools := HFlowContainer.new();column.add_child(tools)
	for kind in Recipe.TYPES:
		var button := Button.new();button.text="ravine" if kind=="lower" else kind;tools.add_child(button);button.pressed.connect(add_feature.bind(kind))
	feature_list=ItemList.new();feature_list.custom_minimum_size=Vector2(270,85);column.add_child(feature_list)
	feature_list.item_selected.connect(func(index: int): selected=index;brush_template=features[index].duplicate(true);brush_template.erase("amount");refresh())
	var grid := GridContainer.new();grid.columns=4;column.add_child(grid)
	for key in ["x","y","z","radius","height","length","width","thickness","yaw","bend"]:
		var label := Label.new();label.text=key;grid.add_child(label)
		var value := SpinBox.new();value.min_value=-740;value.max_value=740;value.step=1;value.custom_minimum_size.x=78
		if key in ["radius","height","length","width","thickness"]: value.min_value=1;value.max_value=120
		if key=="y": value.min_value=-20;value.max_value=55
		grid.add_child(value);fields[key]=value;value.value_changed.connect(edit_value.bind(key))
	var actions := HFlowContainer.new();column.add_child(actions)
	for spec in [["Move feature",place_selected],["Focus",focus_selected],["Delete",delete_selected],["Earlier",reorder.bind(-1)],["Later",reorder.bind(1)],["Undo",undo],["Redo",redo],["Save",save],["Load",load_saved]]:
		var button := Button.new();button.text=spec[0];actions.add_child(button);button.pressed.connect(spec[1])
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.x=270
	notice.text="WASD fly, RMB look, LMB sculpt. Wheel zoom; Shift-wheel size. Strokes accumulate. Save explicitly."
	column.add_child(notice)

func refresh() -> void:
	if feature_list==null: return
	if selected<0 and not features.is_empty(): selected=0
	updating=true;feature_list.clear()
	for i in features.size(): feature_list.add_item("%d  %s" % [i+1,features[i].kind])
	if selected>=0:
		feature_list.select(selected)
	var values: Dictionary=brush_template if brush_mode else (features[selected] if selected>=0 else brush_template)
	for key in fields: fields[key].value=values[key]
	marker.visible=selected>=0 and editing and not brush_mode
	if selected>=0: marker.position=Vector3(features[selected].x,features[selected].y,features[selected].z)
	updating=false

func add_feature(kind: String) -> void:
	finish_brush();flush_brush()
	if brush_mode:
		brush_template.kind=kind;brush_template.erase("amount")
		for key in ["end_x","end_y","end_z"]: brush_template.erase(key)
		refresh()
		if kind=="tunnel": brush_template.radius=4;refresh()
		notice.text="Brush: "+kind+" — hold left mouse on terrain; earlier strokes stay."
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
	if brush_mode: brush_template[key]=value;return
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
		finish_brush();flush_brush();placing=true
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

func start_brush() -> void:
	var hit := cursor_hit()
	if hit.is_empty(): return
	latest_input_usec=Time.get_ticks_usec()
	if brush_template.kind=="tunnel":
		flush_brush()
		var f := brush_template.duplicate(true);f.erase("amount")
		var p: Vector3=hit.position
		f.x=p.x;f.y=p.y;f.z=p.z
		var end := suggested_exit(p,hit.normal)
		f.end_x=end.x;f.end_y=end.y;f.end_z=end.z
		var next := features.duplicate(true);next.append(f);selected=next.size()-1;change(next)
		notice.text="Tunnel created. Drag cyan exit through terrain; Ctrl = 45° snap. Set tunnel exit enables surface picking."
		return
	var source: Array=brush.draft if brush_dirty else features
	undo_stack.append(source.duplicate(true));redo_stack.clear()
	brush.begin(source,brush_template);brushing=true;brush_time=0
	brush.dab(hit.position,brush_rate/60.0);brush_dirty=true

func finish_brush() -> void:
	brushing=false
	refresh()

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
	var offset := p-start;var length := Vector2(offset.x,offset.z).length()
	var angle := snappedf(atan2(offset.z,offset.x),PI/4)
	return Vector3(start.x+cos(angle)*length,p.y,start.z+sin(angle)*length)

func set_endpoint(p: Vector3) -> void:
	var next := features.duplicate(true);p=snap_endpoint(p)
	next[selected].end_x=p.x;next[selected].end_y=p.y;next[selected].end_z=p.z;change(next)

func update_endpoint_guide() -> void:
	var active: bool = editing and selected>=0 and features[selected].has("end_x")
	endpoint_guide.visible=active;endpoint_handle.visible=active
	if not active: return
	var f: Dictionary=features[selected];var start := Vector3(f.x,f.y,f.z)
	var end := endpoint_preview if endpoint_dragging else endpoint_position()
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
	brush_dirty=false;change(brush.draft,false,not brushing)

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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:
		show_chunks=not show_chunks;return
	if event is InputEventKey and event.pressed and event.keycode==KEY_F1:
		finish_brush();flush_brush()
		if editing and (ready_frames<3 or not collision_pending.is_empty()):
			notice.text="Wait for edited collision to finish before playing.";return
		var kit := live_kit()
		if kit:
			kit.release_control()
			if editing: resettle_edited_actors(kit)
		editing=not editing;panel.visible=editing;placing=false;dragging=false;walking=false
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if editing else Input.MOUSE_MODE_CAPTURED
		refresh();return
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
			endpoint_dragging=false;set_endpoint(endpoint_preview);return
		if event is InputEventMouseMotion and endpoint_dragging:
			var point: Variant=endpoint_plane.intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
			if point!=null: endpoint_preview=snap_endpoint(point)
			return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not panel.get_global_rect().has_point(event.position) and selected>=0 and features[selected].has("end_x"):
			if picking_endpoint:
				var point: Variant=far_surface(event.position) if event.alt_pressed else cursor_hit().get("position")
				if point!=null: set_endpoint(point);picking_endpoint=false
				return
			if not camera.is_position_behind(endpoint_position()) and camera.unproject_position(endpoint_position()).distance_to(event.position)<20:
				endpoint_dragging=true;endpoint_preview=endpoint_position();endpoint_plane=Plane(camera.basis.z,endpoint_preview);return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not placing and brush_mode:
			if event.pressed:
				if not panel.get_global_rect().has_point(event.position):
					var focus := get_viewport().gui_get_focus_owner()
					if focus: focus.release_focus()
					start_brush()
			else: finish_brush()
			return
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			finish_brush();looking=false;placing=false;dragging=false;endpoint_dragging=false;picking_endpoint=false;refresh()
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
	if editing:
		editor_fly(delta)
		var hit := cursor_hit()
		aim_valid=not hit.is_empty()
		if aim_valid: aim_point=hit.position
		brush_cursor.visible=brush_mode and not hit.is_empty()
		if not hit.is_empty(): update_brush_outline(hit.position)
		if brushing and not hit.is_empty():
			brush_time+=delta
			if brush_time>=1.0/60.0:
				if not brush_dirty: latest_input_usec=Time.get_ticks_usec()
				brush.dab(hit.position,brush_rate*brush_time);brush_time=0;brush_dirty=true
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
	# Let each in-flight preview finish: continuous strokes must not starve meshing
	# by invalidating its revision every input frame. Recipes still accumulate now.
	if brush_dirty and preview_expected.is_empty(): flush_brush()
	super._process(delta)
	pump_editor_collision()
	publish_preview()
	update_chunk_overlay()
	update_endpoint_guide()
	panel.position.x=maxf(0,get_viewport().get_visible_rect().size.x-panel.size.x-10)
	var kit := live_kit()
	if kit:
		kit.test_capture=editing
		kit.health_hud.visible=not editing
		if editing: kit.crosshair.hide()
		for actor in kit.actors: actor.set_physics_process(not editing)
		if editing:
			for body in kit.vehicle_system.vehicles: body.set_stream_ready(false)
	if not editing: brush_cursor.hide()
	hud.text="SDF WORKSHOP / WASD fly | RMB look | LMB sculpt | F1 play\n%s / %.1f strength/s / radius %.1fm | features %d | %.0f FPS\n%s" % [brush_template.kind,brush_rate,brush_template.radius,features.size(),Engine.get_frames_per_second(),"Stroke queued; preview catching up" if brush_dirty else "Wheel zoom | Shift-wheel size | F3 chunks | Space/Ctrl rise/fall"]
	if kit and kit.vehicle_system.driving:
		var vehicle: RigidBody3D=kit.vehicle_system.driving
		hud.text+="\nCollision-ahead speed limit: %.1f m/s%s" % [vehicle.stream_speed_limit," / waiting for terrain" if vehicle.streaming_suspended else ""]
	if editing: hud.text+="\nPreview %.0f ms | warm %s | rebuilt %d/16 blocks | collision queue %d" % [preview_latency_ms,str(last_field_profile.get("warm_field",false)),last_field_profile.get("rebuilt_blocks",0),collision_pending.size()]

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
