extends Node
const Ring = preload("res://world/terrain_drive_ring.gd")
const Recipe = preload("res://world/sdf_recipe.gd")
const Brush = preload("res://world/sdf_brush.gd")
var arena: Node3D
var opened := false
var was_driving := true
var tool := "hill"
var radius := 12.0
var strength := 4.0
var mountain_height := 24.0
var mountain_seed := 1
var mountain_noise := "ridged"
var stroke := false
var stroke_clock := 0.0
var looking := false
var save_when_ready := false
var entrance := Vector3.ZERO
var has_entrance := false
var layer: CanvasLayer
var panel: PanelContainer
var notice: Label
var tool_help: Label
var state_label: Label
var radius_control: SpinBox
var strength_row: HBoxContainer
var mountain_rows: VBoxContainer
var tool_buttons: Array=[]
var cursor: MeshInstance3D
var guide: MeshInstance3D
var aim := Vector3.ZERO
func origin_shifted(delta: Vector3):
	aim-=delta;entrance-=delta
	cursor.position=Vector3.ZERO;guide.position=Vector3.ZERO
var aim_valid := false
var input_strokes: Array=[]
var active_stroke := {}
var queued_action := ""

func start_stroke(point: Vector3) -> void:
	finish_stroke()
	var template := Recipe.feature(tool,Ring.coordinates(point));template.radius=radius
	var brush := Brush.new();brush.begin([],template)
	active_stroke={"brush":brush,"id":arena.destruction.begin_stroke(),"submitted":{},"closed":false}
	input_strokes.append(active_stroke);stroke=true;stroke_clock=0
	brush.dab(Ring.coordinates(point),strength/60.0)
	flush_strokes()

func finish_stroke() -> void:
	stroke=false;stroke_clock=0
	if not active_stroke.is_empty(): active_stroke.closed=true
	active_stroke={}

func flush_strokes() -> void:
	# Input is accumulated independently of worker/collision progress. Moving
	# cursor samples are interpolated by the original brush, retaining every dose.
	for context in input_strokes.duplicate():
		var all_submitted := true
		for i in context.brush.draft.size():
			var f: Dictionary=context.brush.draft[i]
			var amount: float=f.amount-float(context.submitted.get(i,0.0))
			if amount<=.000000001: continue
			var delta := f.duplicate(true);delta.amount=amount
			if arena.destruction.request_feature(delta,context.id): context.submitted[i]=f.amount
			else: all_submitted=false;break
		if context.closed and all_submitted: input_strokes.erase(context)
		if not all_submitted: break

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	layer=CanvasLayer.new();add_child(layer)
	var screen := Control.new();screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(screen)
	panel=PanelContainer.new();screen.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT);panel.offset_left=-344;panel.offset_right=-16;panel.offset_top=16
	var margin := MarginContainer.new();panel.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",8);margin.add_child(column)
	var title := Label.new();title.text="TERRAIN TOOLS  /  F1";column.add_child(title)
	var tools_grid := GridContainer.new();tools_grid.columns=2;column.add_child(tools_grid)
	for spec in [["Raise","hill"],["Lower","lower"],["Tunnel boring","tunnel"],["Mountain fill","mountain"]]:
		var button := Button.new();button.text=spec[0];button.toggle_mode=true;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tools_grid.add_child(button);button.pressed.connect(select_tool.bind(spec[1]));tool_buttons.append(button)
	tool_help=Label.new();tool_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;tool_help.custom_minimum_size.x=294;column.add_child(tool_help)
	radius_control=number_row(column,"Radius (m)",2,120,1,radius,func(value): radius=value)
	strength_row=HBoxContainer.new();column.add_child(strength_row)
	number_row(strength_row,"Strength (m/s)",.5,32,.5,strength,func(value): strength=value)
	mountain_rows=VBoxContainer.new();column.add_child(mountain_rows)
	number_row(mountain_rows,"Height (m)",2,128,2,mountain_height,func(value): mountain_height=value)
	number_row(mountain_rows,"Seed",1,999999,1,mountain_seed,func(value): mountain_seed=int(value))
	var noise := OptionButton.new();mountain_rows.add_child(noise)
	for label in ["Ridged mountain","Soft simplex","Perlin hills"]: noise.add_item(label)
	noise.item_selected.connect(func(index): mountain_noise=["ridged","simplex","perlin"][index])
	var actions := GridContainer.new();actions.columns=2;column.add_child(actions)
	for spec in [["Undo",undo],["Redo",redo],["Save terrain",save],["Load saved",load_saved]]:
		var button := Button.new();button.text=spec[0];button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(button);button.pressed.connect(spec[1])
	state_label=Label.new();column.add_child(state_label)
	notice=Label.new();notice.custom_minimum_size.x=294;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(notice)
	var help := Label.new();help.text="Hold RMB + WASD to fly\nSpace / Ctrl vertical · Shift faster\nWheel zoom · Shift-wheel radius\nCtrl+S save · Ctrl+Z / Y undo / redo\nF1 returns to play";column.add_child(help)
	var close_button := Button.new();close_button.text="Return to play  [F1]";column.add_child(close_button);close_button.pressed.connect(toggle)
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,.75,.15);material.no_depth_test=true
	cursor=MeshInstance3D.new();cursor.material_override=material;arena.add_child(cursor)
	guide=MeshInstance3D.new();guide.material_override=material;arena.add_child(guide)
	select_tool("hill");panel.hide();cursor.hide();guide.hide()

func number_row(parent: Control, title: String, low: float, high: float, step: float, value: float, changed: Callable) -> SpinBox:
	var row := HBoxContainer.new();parent.add_child(row)
	var label := Label.new();label.text=title;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
	var control := SpinBox.new();control.min_value=low;control.max_value=high;control.step=step;control.value=value;control.custom_minimum_size.x=106;row.add_child(control)
	control.value_changed.connect(changed);return control

func select_tool(kind: String) -> void:
	finish_stroke();tool=kind;has_entrance=false
	var kinds := ["hill","lower","tunnel","mountain"]
	for i in tool_buttons.size(): tool_buttons[i].set_pressed_no_signal(kinds[i]==kind)
	strength_row.visible=kind in ["hill","lower"];mountain_rows.visible=kind=="mountain"
	if kind=="tunnel": radius_control.value=4
	elif kind=="mountain": radius_control.value=32
	else: radius_control.value=12
	tool_help.text="Hold left mouse on terrain to "+("raise" if kind=="hill" else "lower")+" it."
	if kind=="tunnel": tool_help.text="Click the entrance, then the exit. Alt-click picks the far surface. Esc cancels the entrance."
	if kind=="mountain": tool_help.text="Click terrain once to place mountain fill. Adjust radius, height and seed before placing."

func toggle() -> void:
	if not opened:
		if arena.vehicle_kit.menu.opened: return
		was_driving=arena.vehicle_kit.driving;arena.vehicle_kit.driving=false
		opened=true;panel.show()
	else:
		opened=false;panel.hide();arena.vehicle_kit.driving=was_driving
	finish_stroke();looking=false;has_entrance=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;cursor.hide();guide.hide()

func over_panel() -> bool:
	return panel.get_global_rect().has_point(arena.get_viewport().get_mouse_position())

func pick(far_surface := false) -> Dictionary:
	var mouse := arena.get_viewport().get_mouse_position()
	var origin: Vector3=arena.camera.project_ray_origin(mouse)
	var direction: Vector3=arena.camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*800,1)
	if far_surface: query.from=origin+direction*800;query.to=origin;query.hit_back_faces=true
	return arena.get_world_3d().direct_space_state.intersect_ray(query)

func sculpt(point: Vector3, seconds: float) -> bool:
	var template := Recipe.feature(tool,Ring.coordinates(point));template.radius=radius
	var brush := Brush.new();brush.begin([],template);brush.dab(Ring.coordinates(point),minf(strength*seconds,32))
	return arena.destruction.request_feature(brush.draft[0])

func place_mountain(point: Vector3) -> bool:
	var feature := Recipe.feature("mountain",Ring.coordinates(point))
	feature.radius=radius;feature.height=mountain_height;feature.seed=mountain_seed;feature.noise=mountain_noise
	return arena.destruction.request_feature(feature)

func bore_tunnel(start: Vector3, end: Vector3) -> bool:
	var a := Ring.coordinates(start);var b := Ring.coordinates(end)
	if a.distance_to(b)<4 or a.distance_to(b)>500:
		arena.destruction.notice="Choose an exit between 4 and 500 metres away.";return false
	var axis := (b-a).normalized();a-=axis*2;b+=axis*2
	var feature := Recipe.feature("tunnel",a);feature.radius=radius
	feature.end_x=b.x;feature.end_y=b.y;feature.end_z=b.z
	return arena.destruction.request_feature(feature)

func save() -> void:
	finish_stroke();save_when_ready=true;arena.destruction.notice="Saving after the terrain update…"

func load_saved() -> void:
	finish_stroke();has_entrance=false;queued_action="load"

func undo() -> void:
	finish_stroke();has_entrance=false;queued_action="undo"

func redo() -> void:
	finish_stroke();has_entrance=false;queued_action="redo"

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F1:
		toggle();return true
	if not opened: return false
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.ctrl_pressed and event.keycode==KEY_S: save()
			elif event.ctrl_pressed and event.keycode==KEY_Z: undo()
			elif event.ctrl_pressed and event.keycode==KEY_Y: redo()
			elif event.keycode==KEY_ESCAPE: finish_stroke();has_entrance=false;looking=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return true
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			looking=event.pressed and not over_panel();finish_stroke()
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
			return true
		if event.button_index==MOUSE_BUTTON_LEFT:
			if not event.pressed: finish_stroke();return true
			if over_panel() or looking: return true
			if save_when_ready or not queued_action.is_empty(): return true
			var hit := pick(event.alt_pressed and tool=="tunnel")
			if hit.is_empty(): return true
			if arena.destruction.busy() and tool not in ["hill","lower"]: arena.destruction.notice="Wait for the terrain update.";return true
			if tool in ["hill","lower"]:
				start_stroke(hit.position)
			elif tool=="mountain": place_mountain(hit.position)
			elif not has_entrance: entrance=hit.position;has_entrance=true
			elif bore_tunnel(entrance,hit.position): has_entrance=false
			return true
		if event.pressed and not over_panel() and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := 1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1
			if event.shift_pressed: radius_control.value+=direction*2
			else: arena.camera.position-=arena.camera.global_basis.z*direction*8
			return true
	if event is InputEventMouseMotion and looking:
		var up := Ring.up_at(arena.camera.position)
		var forward: Vector3=-arena.camera.global_basis.z
		forward=forward.rotated(up,-event.relative.x*.0025)
		var pitch := asin(clampf(forward.dot(up),-1,1))
		var delta_pitch := clampf(pitch-event.relative.y*.0025,-1.5,1.5)-pitch
		forward=forward.rotated(forward.cross(up).normalized(),delta_pitch)
		arena.camera.look_at(arena.camera.position+forward,up)
	return true

func _process(delta: float) -> void:
	flush_strokes()
	if save_when_ready and input_strokes.is_empty() and not arena.destruction.busy():
		save_when_ready=false;arena.destruction.save_edits()
	if not queued_action.is_empty() and input_strokes.is_empty() and not arena.destruction.busy():
		match queued_action:
			"load": arena.destruction.load_edits()
			"undo": arena.destruction.undo()
			"redo": arena.destruction.redo()
		queued_action=""
	if not opened: return
	if not arena.loading.dismissed: finish_stroke();return
	notice.text=arena.destruction.notice
	state_label.text="%d edits · %s" % [arena.destruction.completed,"Unsaved changes" if arena.destruction.unsaved() else "Saved"]
	if looking:
		var input := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var motion: Vector3=arena.camera.global_basis*input
		motion+=Ring.up_at(arena.camera.position)*(float(Input.is_physical_key_pressed(KEY_SPACE))-float(Input.is_physical_key_pressed(KEY_CTRL)))
		arena.camera.position+=motion.limit_length()*delta*(90 if Input.is_physical_key_pressed(KEY_SHIFT) else 25)
	var hit := pick() if not over_panel() and not looking else {}
	aim_valid=not hit.is_empty();cursor.visible=aim_valid
	if aim_valid:
		aim=hit.position
		var p := Ring.coordinates(aim)
		var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in 64:
			for angle in [i*TAU/64,(i+1)*TAU/64]: mesh.surface_add_vertex(Ring.point(p.x+cos(angle)*radius,p.y+.1,p.z+sin(angle)*radius))
		mesh.surface_end();cursor.mesh=mesh
	guide.visible=has_entrance
	if has_entrance:
		var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		mesh.surface_add_vertex(entrance);mesh.surface_add_vertex(aim if aim_valid else entrance+Ring.up_at(entrance)*4)
		mesh.surface_end();guide.mesh=mesh
	if stroke and aim_valid:
		stroke_clock+=delta
		if stroke_clock>=1.0/60.0:
			active_stroke.brush.dab(Ring.coordinates(aim),strength*stroke_clock);stroke_clock=0
