extends "res://world/forge_editor.gd"
const Actors=preload("res://world/actor_store.gd")
var actors: Node3D
var actor_panel: PanelContainer
var actor_list: ItemList
var waypoint_list: ItemList
var behavior: OptionButton
var enabled_box: CheckBox
var loop_box: CheckBox
var yaw_field: SpinBox
var speed_field: SpinBox
var wait_field: SpinBox
var actor_notice: Label
var actor_summary: Label
var actor_id := 0
var waypoint := -1
var operation := ""
var new_kind := "grunt"
var pending_copy := {}
var actor_revision := -1
var markers: Node3D
var placement_marker: MeshInstance3D
var object_preview: Node3D
var syncing_actor := false
func setup(owner_arena: Node3D) -> void:
	super.setup(owner_arena)
	var column=tool_help.get_parent()
	var open_button=button(column,"Actors + patrol routes",select_tool.bind("actors"));column.move_child(open_button,1)
	button(selection_text.get_parent(),"Actors + patrol routes",select_tool.bind("actors"))
	actor_panel=PanelContainer.new();panel.get_parent().add_child(actor_panel)
	var background=StyleBoxFlat.new();background.bg_color=Color(.045,.06,.075,.97)
	for side in ["left","right","top","bottom"]: background.set("content_margin_"+side,10.0)
	actor_panel.add_theme_stylebox_override("panel",background);actor_panel.add_theme_font_size_override("font_size",14)
	actor_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE);actor_panel.offset_left=-414;actor_panel.offset_right=-16;actor_panel.offset_top=16;actor_panel.offset_bottom=-16
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;actor_panel.add_child(scroll)
	var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",7);scroll.add_child(body)
	heading(body,"ACTORS / PATROL ROUTES")
	var palette=GridContainer.new();palette.columns=2;body.add_child(palette)
	for item in [["Grunt","grunt"],["Captain","captain"],["Squad (5)","squad"],["T. rex","trex"],["Warthog","warthog"],["Altay tank","tank"],["Heavy crate","crate"]]: button(palette,"+ "+item[0],begin_place.bind(item[1]))
	actor_list=ItemList.new();actor_list.custom_minimum_size.y=85;body.add_child(actor_list);actor_list.item_selected.connect(func(index): select_actor(int(actor_list.get_item_metadata(index))))
	var actions=HBoxContainer.new();body.add_child(actions)
	button(actions,"Select",func(): operation="")
	button(actions,"Focus",focus_actor)
	button(actions,"Move [G]",func(): begin_operation("move"))
	button(actions,"Copy",copy_actor)
	button(actions,"Delete",delete_actor)
	var tabs=TabContainer.new();body.add_child(tabs)
	var behavior_body=VBoxContainer.new();behavior_body.name="Behavior";tabs.add_child(behavior_body)
	var route_body=VBoxContainer.new();route_body.name="Patrol route";tabs.add_child(route_body)
	tabs.current_tab=1
	enabled_box=CheckBox.new();enabled_box.text="Enabled";behavior_body.add_child(enabled_box);enabled_box.toggled.connect(func(value): change("enabled",value))
	behavior=OptionButton.new();behavior_body.add_child(behavior);behavior.item_selected.connect(func(index): change("mode",index))
	yaw_field=number_row(behavior_body,"Facing (degrees)",-180,180,5,0,func(v): change("yaw",v))
	speed_field=number_row(behavior_body,"Patrol speed (m/s)",.25,24,.25,1.25,func(v): change("speed",v))
	wait_field=number_row(route_body,"Wait at each point (s)",0,300,.5,0,func(v): change("wait",v))
	loop_box=CheckBox.new();loop_box.text="Loop route (off = stop at last point)";route_body.add_child(loop_box);loop_box.toggled.connect(func(value): change("loop",value))
	heading(route_body,"WAYPOINTS / click terrain to place")
	waypoint_list=ItemList.new();waypoint_list.custom_minimum_size.y=95;route_body.add_child(waypoint_list);waypoint_list.item_selected.connect(func(index): waypoint=index;draw_markers())
	var points=GridContainer.new();points.columns=3;route_body.add_child(points)
	button(points,"Add point",func(): begin_operation("add_point"))
	button(points,"Move point",func(): begin_operation("move_point"))
	button(points,"Remove",remove_point)
	button(points,"Earlier",reorder_point.bind(-1))
	button(points,"Later",reorder_point.bind(1))
	button(points,"Clear route",clear_route)
	actor_summary=Label.new();actor_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;actor_summary.custom_minimum_size.x=350;body.add_child(actor_summary)
	actor_notice=Label.new();actor_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;actor_notice.custom_minimum_size.x=350;body.add_child(actor_notice)
	var history=HBoxContainer.new();body.add_child(history)
	button(history,"Undo",undo);button(history,"Redo",redo);button(history,"Save all",save);button(history,"Reload actors",load_saved)
	var help=Label.new();help.text="Click a pin to select. G moves; Delete removes.\nRMB + WASD fly; Space/Ctrl vertical. Esc cancels.\nRoutes use loaded terrain. Empty route holds at spawn.\nEdits apply on leaving the editor. F7 resets actors."
	help.add_theme_font_size_override("font_size",12);body.add_child(help)
	button(body,"Reload development changes [Ctrl+F6]",func(): arena.dev_reload.request())
	var navigation=HBoxContainer.new();body.add_child(navigation)
	button(navigation,"Terrain",select_tool.bind("hill"));button(navigation,"Construction",select_tool.bind("forge"));button(navigation,"Play [F1]",toggle)
	object_preview=preload("res://world/actor_preview.gd").new();arena.add_child(object_preview);object_preview.hide()
	markers=Node3D.new();arena.add_child(markers)
	placement_marker=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.75;sphere.height=1.5;placement_marker.mesh=sphere;placement_marker.material_override=marker_material(Color(1,.8,.1));placement_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arena.add_child(placement_marker);placement_marker.hide()
	update_panels()
func connect_actors(world: Node3D) -> void:
	actors=world;refresh_actors()
func marker_material(color: Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color;m.no_depth_test=true;return m
func select_tool(kind: String) -> void:
	operation="";super.select_tool("hill" if kind=="actors" else kind)
	if kind=="actors": tool="actors"
	update_panels()
func update_panels() -> void:
	super.update_panels()
	if not is_instance_valid(actor_panel): return
	actor_panel.visible=opened and tool=="actors"
	if actor_panel.visible: panel.hide();arena.hud.hide()
	if is_instance_valid(markers): markers.visible=actor_panel.visible
	if is_instance_valid(placement_marker) and not actor_panel.visible: placement_marker.hide()
	if is_instance_valid(object_preview) and not actor_panel.visible: object_preview.hide()
func toggle() -> void:
	operation="";super.toggle();update_panels()
func over_panel() -> bool:
	if tool=="actors" and is_instance_valid(actor_panel): return actor_panel.get_global_rect().has_point(arena.get_viewport().get_mouse_position())
	return super.over_panel()
func pick(far_surface := false) -> Dictionary:
	if tool=="actors": return {}
	return super.pick(far_surface)
func ground_pick() -> Dictionary:
	var mouse=arena.get_viewport().get_mouse_position();var origin=arena.camera.project_ray_origin(mouse);var direction=arena.camera.project_ray_normal(mouse)
	var hit=arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*800,1))
	if hit.is_empty() or not arena.aliens.resident(hit.position) or hit.normal.dot(Ring.up_at(hit.position))<cos(deg_to_rad(46)): return {}
	return hit
func selected() -> Dictionary: return actors.store.find(actor_id) if actors else {}
func begin_place(kind: String) -> void:
	new_kind=kind;operation="place";actors.store.notice="Click loaded terrain to place a "+kind+". Esc cancels."
func begin_operation(value: String) -> void:
	if selected().is_empty(): actors.store.notice="Select an actor first.";return
	if selected().kind=="crate" and value in ["add_point","move_point"]: actors.store.notice="Crates are physics props and have no patrol route.";return
	if not actors.editable(actor_id): actors.store.notice="Exit this Warthog before editing its spawn.";return
	if value=="move_point" and waypoint<0: actors.store.notice="Select a waypoint first.";return
	operation=value;actors.store.notice="Click loaded terrain. Esc cancels."
func select_actor(id: int) -> void:
	actor_id=id;waypoint=-1;operation="";refresh_actors()
func change(key: String, value: Variant) -> void:
	if syncing_actor or selected().is_empty(): return
	if not actors.editable(actor_id): actors.store.notice="Exit this Warthog before editing it.";refresh_actors();return
	var before=actors.store.snapshot();selected()[key]=value;actors.store.commit(before);refresh_actors()
func commit_at(point: Vector3) -> void:
	var before=actors.store.snapshot();var record=selected()
	if operation=="place":
		record=actors.store.make(new_kind,point);actors.store.records.append(record);actor_id=record.id;waypoint=-1
	elif operation=="copy":
		record=pending_copy.duplicate(true);record.id=actors.store.next_id;actors.store.next_id+=1
		var target=Actors.coordinate(point);var shift=Vector3(target[0]-record.p[0],target[1]-record.p[1],target[2]-record.p[2])
		for p in record.route: p[0]=wrapf(p[0]+shift.x,-1500000,1500000);p[1]+=shift.y;p[2]+=shift.z
		record.p=target;actors.store.records.append(record);actor_id=record.id
	elif record.is_empty(): return
	elif operation=="move":
		var target=Actors.coordinate(point);var shift=Vector3(target[0]-record.p[0],target[1]-record.p[1],target[2]-record.p[2])
		for p in record.route: p[0]=wrapf(p[0]+shift.x,-1500000,1500000);p[1]+=shift.y;p[2]+=shift.z
		record.p=target
	elif operation=="add_point": record.route.append(Actors.coordinate(point));waypoint=record.route.size()-1
	elif operation=="move_point" and waypoint>=0 and waypoint<record.route.size(): record.route[waypoint]=Actors.coordinate(point)
	else: return
	if not Actors.valid_record(record):
		actors.store.records=before;actors.store.notice="Placement is outside supported world coordinates.";return
	actors.store.commit(before);actors.store.notice="Actor layout changed. Ctrl+S saves; F1 resumes play."
	if operation!="add_point": operation=""
	refresh_actors()
func copy_actor() -> void:
	var record=selected()
	if record.is_empty(): return
	pending_copy=record.duplicate(true);operation="copy";actors.store.notice="Click the copied spawn position. Esc cancels without changing the layout."

func delete_actor() -> void:
	if not actors.editable(actor_id): actors.store.notice="Exit this Warthog before removing it.";return
	actors.store.erase([actor_id]);actor_id=0;operation="";refresh_actors()
func remove_point() -> void:
	if not actors.editable(actor_id): actors.store.notice="Exit this Warthog before editing its route.";return
	var record=selected()
	if record.is_empty() or waypoint<0 or waypoint>=record.route.size(): return
	var before=actors.store.snapshot();record.route.remove_at(waypoint);waypoint=mini(waypoint,record.route.size()-1);actors.store.commit(before);refresh_actors()
func reorder_point(direction: int) -> void:
	if not actors.editable(actor_id): actors.store.notice="Exit this Warthog before editing its route.";return
	var record=selected()
	if record.is_empty() or waypoint<0 or waypoint+direction<0 or waypoint+direction>=record.route.size(): return
	var before=actors.store.snapshot();var p=record.route[waypoint];record.route[waypoint]=record.route[waypoint+direction];record.route[waypoint+direction]=p;waypoint+=direction;actors.store.commit(before);refresh_actors()
func clear_route() -> void:
	if not actors.editable(actor_id): actors.store.notice="Exit this Warthog before editing its route.";return
	if selected().is_empty(): return
	var before=actors.store.snapshot();selected().route=[];waypoint=-1;actors.store.commit(before);refresh_actors()
func focus_actor() -> void:
	var record=selected()
	if record.is_empty(): return
	var p=Actors.point(record.p);var up=Ring.up_at(p);var distance=65 if record.kind=="trex" else 28
	arena.camera.position=p+Ring.tangent_basis(p,0)*Vector3(0,distance*.7,distance);arena.camera.look_at(p+up*2,up)
func refresh_actors() -> void:
	if not actors: return
	syncing_actor=true;actor_list.clear();waypoint_list.clear();behavior.clear()
	for record in actors.store.records:
		var index=actor_list.add_item("#%d  %s%s" % [record.id,record.kind," (disabled)" if not record.enabled else ""]);actor_list.set_item_metadata(index,record.id)
		if record.id==actor_id: actor_list.select(index);actor_list.ensure_current_is_visible()
	var record=selected()
	if not record.is_empty():
		for mode_name in Actors.modes(record.kind): behavior.add_item(mode_name)
		speed_field.editable=record.kind!="crate";wait_field.editable=record.kind!="crate";loop_box.disabled=record.kind=="crate"
		behavior.select(record.mode);enabled_box.set_pressed_no_signal(record.enabled);loop_box.set_pressed_no_signal(record.loop)
		yaw_field.set_value_no_signal(record.yaw);speed_field.set_value_no_signal(record.speed);wait_field.set_value_no_signal(record.wait)
		for i in record.route.size():
			var p=record.route[i];waypoint_list.add_item("%d   arc %.1f / height %.1f / across %.1f" % [i+1,p[0],p[1],p[2]])
		if waypoint>=0 and waypoint<record.route.size(): waypoint_list.select(waypoint)
	actor_summary.text="%d actors / %s\nRuntime budget: 10 aliens, 2 T. rexes, 4 Warthogs, 2 tanks + 8 crates nearby. Extra actors wait; distant actors suspend." % [actors.store.records.size(),"Unsaved" if actors.store.unsaved() else "Saved"]
	syncing_actor=false;actor_revision=actors.store.revision;draw_markers()
func draw_markers() -> void:
	if not is_instance_valid(markers) or not actors: return
	for child in markers.get_children(): child.free()
	var vertices: Array[Vector3]=[]
	for record in actors.store.records:
		var p=Actors.point(record.p);var color=Color(1,.8,.1) if record.id==actor_id else (Color(.5,.5,.5) if not record.enabled else Color(.2,.8,1))
		var pin=MeshInstance3D.new();var cone=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=1.3;cone.height=3;pin.mesh=cone;pin.material_override=marker_material(color);pin.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;markers.add_child(pin);pin.transform=Transform3D(Ring.tangent_basis(p,0),p+Ring.up_at(p)*1.5)
		var label=Label3D.new();label.text="#%d %s" % [record.id,record.kind];label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.font_size=26;label.pixel_size=.015;markers.add_child(label);label.position=p+Ring.up_at(p)*4
		if record.id!=actor_id: continue
		var previous=p
		vertices.append(p);vertices.append(p-Ring.tangent_basis(p,deg_to_rad(record.yaw)).z*6)
		for i in record.route.size():
			var target=Actors.point(record.route[i])+Ring.up_at(Actors.point(record.route[i]))*.5
			vertices.append(previous);vertices.append(target);previous=target
			var sphere=MeshInstance3D.new();var ball=SphereMesh.new();ball.radius=.65;ball.height=1.3;sphere.mesh=ball;sphere.material_override=marker_material(Color(1,.3,.2) if i==waypoint else Color(.3,1,.45));sphere.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;markers.add_child(sphere);sphere.position=target
			var number=Label3D.new();number.text=str(i+1);number.billboard=BaseMaterial3D.BILLBOARD_ENABLED;number.no_depth_test=true;number.pixel_size=.025;markers.add_child(number);number.position=target+Ring.up_at(target)*1.7
		if record.loop and record.route.size()>1: vertices.append(previous);vertices.append(Actors.point(record.route[0])+Ring.up_at(p)*.5)
	if not vertices.is_empty():
		var lines=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
		for v in vertices: lines.surface_add_vertex(v)
		lines.surface_end();var path_mesh=MeshInstance3D.new();path_mesh.mesh=lines;path_mesh.material_override=marker_material(Color(.3,1,.45));path_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;markers.add_child(path_mesh)
func pin_at_cursor() -> int:
	var best=28.0;var found=0;var mouse=arena.get_viewport().get_mouse_position()
	for record in actors.store.records:
		var p=Actors.point(record.p)+Ring.up_at(Actors.point(record.p))*1.5
		if arena.camera.is_position_behind(p): continue
		var distance=arena.camera.unproject_position(p).distance_to(mouse)
		if distance<best: best=distance;found=record.id
	return found
func save() -> void:
	super.save()
	if actors: actors.store.save();refresh_actors()
func undo() -> void:
	if tool!="actors": super.undo();return
	if not actor_history_allowed(): return
	operation="";actors.store.undo();refresh_actors()
func redo() -> void:
	if tool!="actors": super.redo();return
	if not actor_history_allowed(): return
	operation="";actors.store.redo();refresh_actors()
func load_saved() -> void:
	if tool!="actors": super.load_saved();return
	if not actor_history_allowed(): return
	operation="";actors.store.load_saved();refresh_actors()
func handle_input(event: InputEvent) -> bool:
	if not opened or tool!="actors": return super.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1: toggle();return true
		if event.ctrl_pressed and event.keycode==KEY_S: save();return true
		if arena.get_viewport().gui_get_focus_owner() is LineEdit: return true
		if event.ctrl_pressed and event.keycode==KEY_Z: undo();return true
		if event.ctrl_pressed and event.keycode==KEY_Y: redo();return true
		if event.ctrl_pressed and event.keycode==KEY_D: copy_actor();return true
		if not looking:
			if event.keycode==KEY_G: begin_operation("move");return true
			if event.keycode==KEY_DELETE: delete_actor();return true
			if event.keycode==KEY_ESCAPE: operation="";return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and not looking and not over_panel():
			var focus=arena.get_viewport().gui_get_focus_owner()
			if focus: focus.release_focus()
			if operation.is_empty(): select_actor(pin_at_cursor())
			else:
				var hit=ground_pick()
				if not hit.is_empty(): commit_at(hit.position)
				else: actors.store.notice="Choose loaded terrain on a walkable slope."
		return true
	return super.handle_input(event)
func _process(delta: float) -> void:
	super._process(delta)
	if not actors or not opened or tool!="actors": return
	if actor_revision!=actors.store.revision: refresh_actors()
	actor_notice.text=actors.store.notice
	placement_marker.visible=false;object_preview.hide()
	if not operation.is_empty() and not looking and not over_panel():
		var hit=ground_pick()
		if not hit.is_empty():
			if operation in ["place","move","copy"]:
				var record=pending_copy if operation=="copy" else selected()
				var kind=new_kind if operation=="place" else str(record.get("kind",""))
				if not kind.is_empty():
					object_preview.configure(kind,arena)
					object_preview.place(hit.position,0.0 if operation=="place" else float(record.get("yaw",0.0)))
			else:
				placement_marker.position=hit.position+Ring.up_at(hit.position)*.75;placement_marker.show()

func actor_history_allowed() -> bool:
	for id in actors.live:
		if not actors.editable(id): actors.store.notice="Exit the authored Warthog before undo, redo or reload.";return false
	return true
