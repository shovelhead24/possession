extends "res://world/tree_paint_editor.gd"
const Parts=preload("res://world/forge_parts.gd")
const Store=preload("res://world/forge_store.gd")
var foliage_review: Node
var forge: Node3D
var build_panel: PanelContainer
var build_info: Label
var selection_text: Label
var build_notice: Label
var position_fields: Array[SpinBox]=[]
var rotation_fields: Array[SpinBox]=[]
var selection: Array=[]
var draft: Array=[]
var preview_records: Array=[]
var preview_nodes: Array[MeshInstance3D]=[]
var moving := false
var existing_draft := false
var valid_preview := false
var grid := .5
var angle_step := 15.0
var face_snap := true
var edge_snap := true
var edge_selected := false
var edge_guide: MeshInstance3D
var center_marker: Label
var center_selected := false
var face_choice := 0
var phased := true
var floating := false
var finish := 0
var rotation_delta := Vector3.ZERO
var lift := 0.0
var hold_distance := 15.0
var preview_material: StandardMaterial3D
var preview_colors: Array[StandardMaterial3D]=[]
var color_buttons: Array[Button]=[]
var outline: MeshInstance3D
var preview_clock := 0.0
var displayed_revision := -1
var syncing := false

func setup(owner_arena: Node3D) -> void:
	forge=owner_arena.forge
	super.setup(owner_arena)
	var open_button := Button.new();open_button.text="Construction…  /  walls, floors, ramps"
	var column: VBoxContainer=tool_help.get_parent();column.add_child(open_button);column.move_child(open_button,1)
	open_button.pressed.connect(select_tool.bind("forge"))
	if arena.get("collision_debug"): column.move_child(arena.collision_debug.add_toggle(column),2)
	foliage_review=preload("res://world/foliage_review.gd").new();add_child(foliage_review);foliage_review.setup(arena,column)
	# Keep the expanded terrain/tree tools reachable on short windows.
	var margin=column.get_parent();var scroll=ScrollContainer.new();margin.add_child(scroll)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.reparent(scroll,false);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE);panel.offset_left=-360;panel.offset_right=-16;panel.offset_top=16;panel.offset_bottom=-16
	build_ui()
	preview_material=StandardMaterial3D.new();preview_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;preview_material.albedo_color=Color(1,.2,.15,.55)
	for color in Parts.COLORS:
		var material: StandardMaterial3D=preview_material.duplicate()
		material.albedo_color=Color(color,.65);preview_colors.append(material)
	outline=MeshInstance3D.new();outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var line_material := StandardMaterial3D.new();line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_material.albedo_color=Color(1,.75,.15)
	outline.material_override=line_material;arena.add_child(outline)
	edge_guide=MeshInstance3D.new();edge_guide.material_override=line_material;edge_guide.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arena.add_child(edge_guide)
	refresh_selection()

func button(parent: Control, title: String, action: Callable) -> Button:
	var node := Button.new();node.text=title;node.focus_mode=Control.FOCUS_NONE;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(node);node.pressed.connect(action);return node
func options(parent: Control, title: String, names: Array, selected: int, action: Callable) -> void:
	var row := HBoxContainer.new();parent.add_child(row)
	var label := Label.new();label.text=title;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
	var option := OptionButton.new();row.add_child(option)
	for text in names: option.add_item(str(text))
	option.select(selected);option.item_selected.connect(action)
func check(parent: Control, title: String, value: bool, action: Callable) -> void:
	var node := CheckBox.new();node.text=title;node.button_pressed=value;node.toggled.connect(action);parent.add_child(node)
func heading(parent: Control, title: String) -> void:
	var node := Label.new();node.text=title;node.add_theme_color_override("font_color",Color(.5,.85,1));parent.add_child(node)

func build_ui() -> void:
	var screen: Control=layer.get_child(0)
	build_panel=PanelContainer.new();screen.add_child(build_panel)
	build_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE);build_panel.offset_left=-370;build_panel.offset_right=-12;build_panel.offset_top=12;build_panel.offset_bottom=-12
	var margin := MarginContainer.new();build_panel.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(scroll)
	var column := VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",4);scroll.add_child(column)
	heading(column,"CONSTRUCTION  /  F1")
	if arena.get("collision_debug"): arena.collision_debug.add_toggle(column)
	button(column,"← Terrain & trees",select_tool.bind("hill"))
	var palette := GridContainer.new();palette.columns=2;column.add_child(palette)
	for kind in Parts.NAMES:
		var title: String=Parts.NAMES[kind].split(" · ")[0]
		if kind in ["floor","floor_large"]: title="Floor 4 × 4" if kind=="floor" else "Floor 8 × 8"
		var node := button(palette,title,start_new.bind(kind));node.tooltip_text=Parts.NAMES[kind]
	var actions := HBoxContainer.new();column.add_child(actions)
	button(actions,"Select",cancel_preview);button(actions,"Move [G]",start_move.bind(false));button(actions,"Copy",start_move.bind(true))
	selection_text=Label.new();selection_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selection_text.custom_minimum_size.x=310;column.add_child(selection_text)
	var tabs := TabContainer.new();column.add_child(tabs)
	var snap_tab := VBoxContainer.new();snap_tab.name="Snap";tabs.add_child(snap_tab)
	var transform_tab := VBoxContainer.new();transform_tab.name="Transform";tabs.add_child(transform_tab)
	var layout_tab := VBoxContainer.new();layout_tab.name="Layout";tabs.add_child(layout_tab)
	for tab in [snap_tab,transform_tab,layout_tab]: tab.add_theme_constant_override("separation",4)
	heading(snap_tab,"ALIGNMENT")
	options(snap_tab,"Grid (m)",["Off","0.25","0.5","1","2","4"],maxi(0,[0.0,.25,.5,1.0,2.0,4.0].find(grid)),func(i): grid=[0.0,.25,.5,1.0,2.0,4.0][i])
	options(transform_tab,"Rotation step",["15°","30°","45°","90°"],maxi(0,[15.0,30.0,45.0,90.0].find(angle_step)),func(i): angle_step=[15.0,30.0,45.0,90.0][i])
	check(snap_tab,"Snap to part faces",face_snap,func(v): face_snap=v)
	check(snap_tab,"Align camera-nearest overlapping edge",edge_snap,func(v): edge_snap=v)
	options(snap_tab,"Target face",["Aimed face","+X / right","−X / left","+Y / top","−Y / bottom","+Z / front","−Z / back"],face_choice,func(i): face_choice=i)
	check(snap_tab,"Phased: allow overlapping placement",phased,func(v): phased=v)
	check(snap_tab,"Float at held distance",floating,func(v): floating=v)
	heading(snap_tab,"COLOUR")
	var colors := GridContainer.new();colors.columns=6;snap_tab.add_child(colors)
	for i in Parts.COLORS.size():
		var swatch := Button.new();swatch.custom_minimum_size=Vector2(43,28);swatch.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		swatch.focus_mode=Control.FOCUS_NONE;swatch.toggle_mode=true;swatch.tooltip_text=Parts.COLOR_NAMES[i]
		for state in ["normal","hover","pressed"]:
			var style := StyleBoxFlat.new();style.bg_color=Parts.COLORS[i];style.set_corner_radius_all(3)
			style.set_border_width_all(3 if state=="pressed" else 1);style.border_color=Color.WHITE if state!="normal" else Color(.15,.17,.2)
			swatch.add_theme_stylebox_override(state,style)
		colors.add_child(swatch);swatch.pressed.connect(set_finish.bind(i));color_buttons.append(swatch)
	color_buttons[finish].set_pressed_no_signal(true)
	heading(transform_tab,"TRANSFORM  /  selected part or group")
	for title in ["Arc (m)","Height (m)","Lateral (m)"]:
		position_fields.append(number_row(transform_tab,title,-1500000,1500000,.05,0,func(_v): pass))
	button(transform_tab,"Apply position",apply_position)
	for axis in 3:
		var control := number_row(transform_tab,["Pitch X (°)","Yaw Y (°)","Roll Z (°)"][axis],-360,360,1,0,func(v): set_preview_angle(axis,v))
		rotation_fields.append(control)
	button(transform_tab,"Apply orientation",apply_orientation)
	var nudges := GridContainer.new();nudges.columns=3;transform_tab.add_child(nudges)
	for axis in 3:
		var row := HBoxContainer.new();nudges.add_child(row)
		button(row,["X−","Y−","Z−"][axis],nudge.bind(axis,-1));button(row,["X+","Y+","Z+"][axis],nudge.bind(axis,1))
	var turns := HBoxContainer.new();transform_tab.add_child(turns)
	for axis in 3: button(turns,"Rotate "+["X","Y","Z"][axis],rotate_axis.bind(axis,1))
	var groups := HBoxContainer.new();transform_tab.add_child(groups)
	button(groups,"Join",join_selection);button(groups,"Separate",unjoin_selection);button(groups,"Delete",delete_selection)
	var history := HBoxContainer.new();layout_tab.add_child(history)
	button(history,"Undo",undo);button(history,"Redo",redo)
	button(layout_tab,"Save world  [Ctrl+S]",save);button(layout_tab,"Reload construction",load_saved)
	build_notice=Label.new();build_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;build_notice.position=Vector2(16,208);build_notice.size=Vector2(660,90);screen.add_child(build_notice)
	build_notice.add_theme_color_override("font_shadow_color",Color.BLACK);build_notice.add_theme_constant_override("shadow_offset_x",1);build_notice.add_theme_constant_override("shadow_offset_y",1)
	button(layout_tab,"Reload development changes [Ctrl+F6]",func(): arena.dev_reload.request())
	button(layout_tab,"Return to play  [F1]",toggle)
	build_info=Label.new();screen.add_child(build_info);build_info.position=Vector2(16,16)
	build_info.text="CONSTRUCTION\nChoose a part → aim → click to place\nClick selects · Shift-click adds to selection\nG move · Ctrl+D copy · Delete remove\nQ / E rotate yaw · Shift-wheel raise / lower\nRMB + WASD fly · Space / Ctrl up / down\nEsc cancels · Ctrl+Z / Y undo / redo"
	build_info.add_theme_color_override("font_shadow_color",Color.BLACK);build_info.add_theme_constant_override("shadow_offset_x",1);build_info.add_theme_constant_override("shadow_offset_y",1)
	center_marker=Label.new();center_marker.text="⊕";center_marker.add_theme_font_size_override("font_size",28)
	center_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.add_child(center_marker);center_marker.hide()
	build_panel.hide();build_info.hide();build_notice.hide()

func select_tool(kind: String) -> void:
	if is_instance_valid(forge): cancel_preview()
	super.select_tool("hill" if kind=="forge" else kind)
	if kind=="forge": tool="forge"
	update_panels()
func update_panels() -> void:
	if not is_instance_valid(build_panel): return
	build_panel.visible=opened and tool=="forge";build_info.visible=build_panel.visible;build_notice.visible=build_panel.visible
	panel.visible=opened and tool!="forge";arena.hud.visible=not build_panel.visible
	if is_instance_valid(outline): outline.visible=build_panel.visible
func toggle() -> void:
	cancel_preview();super.toggle();update_panels()
func over_panel() -> bool:
	if tool=="forge" and is_instance_valid(build_panel): return build_panel.get_global_rect().has_point(arena.get_viewport().get_mouse_position())
	return super.over_panel()
func pick(far_surface := false) -> Dictionary:
	if tool=="forge": return {} # Suppress terrain-brush drawing in construction mode.
	return super.pick(far_surface)
func save() -> void:
	cancel_preview();super.save();forge.store.save()
func undo() -> void:
	if tool!="forge": super.undo();return
	cancel_preview();forge.store.undo();refresh_selection();sync_fields()
func redo() -> void:
	if tool!="forge": super.redo();return
	cancel_preview();forge.store.redo();refresh_selection();sync_fields()
func load_saved() -> void:
	if tool!="forge": super.load_saved();return
	cancel_preview();forge.store.load_saved();refresh_selection();sync_fields()

func cancel_preview() -> void:
	if is_instance_valid(center_marker): center_marker.hide()
	if is_instance_valid(edge_guide): edge_guide.hide()
	draft.clear();preview_records.clear();moving=false;existing_draft=false;valid_preview=false;rotation_delta=Vector3.ZERO;lift=0
	for node in preview_nodes: node.queue_free()
	preview_nodes.clear()
	if is_instance_valid(forge): forge.hidden_ids=[]
func start_new(kind: String) -> void:
	cancel_preview();selection=[]
	draft=[forge.store.make(kind,Transform3D.IDENTITY,finish)];create_previews();sync_fields();refresh_selection()
	forge.store.notice="Aim at terrain or a part. Click to place; Esc cancels."
func start_move(copy: bool) -> void:
	cancel_preview()
	selection=forge.store.expanded(selection)
	if selection.is_empty(): forge.store.notice="Select a part first.";return
	var group_map := {}
	for id in selection:
		var source: Dictionary=forge.store.find(id)
		if source.is_empty(): continue
		var item: Dictionary=source.duplicate(true)
		if copy:
			item.id=forge.store.next_id;forge.store.next_id+=1
			if item.group>0:
				if not group_map.has(item.group): group_map[item.group]=forge.store.next_id;forge.store.next_id+=1
				item.group=group_map[item.group]
		draft.append(item)
	moving=not copy;existing_draft=true
	if moving: forge.hidden_ids=selection.duplicate()
	create_previews();sync_fields()
func create_previews() -> void:
	for item in draft:
		var node := MeshInstance3D.new();node.mesh=Parts.get_part(item.kind).mesh;node.material_override=preview_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arena.add_child(node);node.hide();preview_nodes.append(node)
func select_id(id: int, additive := false) -> void:
	cancel_preview()
	var ids: Array=forge.store.expanded([id]) if id>0 else []
	if not additive: selection=ids
	else:
		var remove := id in selection
		for selected in ids:
			if remove: selection.erase(selected)
			elif selected not in selection: selection.append(selected)
	refresh_selection();sync_fields()

func update_preview(hit: Dictionary) -> void:
	if draft.is_empty(): return
	var mouse := arena.get_viewport().get_mouse_position()
	var origin: Vector3=arena.camera.project_ray_origin(mouse);var direction: Vector3=arena.camera.project_ray_normal(mouse)
	var point: Vector3=origin+direction*hold_distance if hit.is_empty() or floating else hit.position
	var up := Ring.up_at(point)
	var initial := Store.pose(draft[0]);var local_basis := Basis.IDENTITY
	if existing_draft: local_basis=Ring.tangent_basis(point,0).inverse()*initial.basis
	var basis: Basis=Ring.tangent_basis(point,0)*local_basis*Basis.from_euler(rotation_delta)
	var pose := Transform3D(basis,point)
	if edge_snap and face_snap and not floating and hit.get("id",0)==0:
		var overlap_pose := pose
		if not hit.is_empty(): overlap_pose.origin+=up*Parts.support(basis,Parts.get_part(draft[0].kind).size,up)
		var candidate: Dictionary=forge.overlapping_snap_target(overlap_pose,Parts.get_part(draft[0].kind).size,selection if moving else [],arena.camera.global_position)
		if not candidate.is_empty(): hit=candidate

	var snapping: bool= not floating and face_snap and not hit.is_empty() and hit.get("id",0)>0
	center_selected=false;edge_selected=false
	if is_instance_valid(edge_guide): edge_guide.hide()
	if is_instance_valid(center_marker): center_marker.hide()
	if snapping:
		var target: Dictionary=forge.store.find(hit.id)
		var target_pose := Store.pose(target)
		var normal: Vector3=hit.normal
		if face_choice>0:
			var local := Vector3.ZERO;local[(face_choice-1)/2]=1 if face_choice%2==1 else -1;normal=target_pose.basis*local
		var target_size: Vector3=Parts.get_part(target.kind).size
		var centre := Parts.face_center(target_pose,target_size,normal)
		if not arena.camera.is_position_behind(centre):
			var pixel: Vector2=arena.camera.unproject_position(centre)
			center_selected=mouse.distance_to(pixel)<=18.0
			center_marker.position=pixel-Vector2(14,20);center_marker.show()
			center_marker.modulate=Color(1,.8,.15) if center_selected else Color(.3,.9,1)
		pose=Parts.snap_face(target_pose,target_size,basis,Parts.get_part(draft[0].kind).size,normal,hit.position,center_selected)
		if edge_snap and not center_selected:
			var edge := Parts.snap_edge(target_pose,target_size,pose,Parts.get_part(draft[0].kind).size,normal,arena.camera.global_position)
			if not edge.is_empty():
				pose=edge.pose;edge_selected=true
				var lines := ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
				lines.surface_add_vertex(edge.a);lines.surface_add_vertex(edge.b);lines.surface_end()
				edge_guide.mesh=lines;edge_guide.show()

	else:
		if not hit.is_empty() and not floating: pose.origin+=up*Parts.support(basis,Parts.get_part(draft[0].kind).size,up)
		if grid>0:
			var coordinate := Ring.coordinates(pose.origin)
			coordinate.x=snappedf(coordinate.x,grid);coordinate.z=snappedf(coordinate.z,grid)
			coordinate.y=ceilf(coordinate.y/grid)*grid
			pose.origin=Ring.point(coordinate.x,coordinate.y,coordinate.z)
	pose.origin+=up*lift
	var delta := pose*initial.affine_inverse();preview_records=[]
	for i in draft.size():
		var item: Dictionary=draft[i].duplicate(true);Store.set_pose(item,delta*Store.pose(item));preview_records.append(item)
		preview_nodes[i].transform=Store.pose(item);preview_nodes[i].show()
	var coord := Ring.coordinates(pose.origin);var tile := Vector2i(floori(coord.x/200),floori(coord.z/200))
	valid_preview=arena.tile_entries.has(tile) and (phased or forge.clear_placement(preview_records,selection if moving else []))
	for i in preview_nodes.size(): preview_nodes[i].material_override=preview_colors[preview_records[i].finish] if valid_preview else preview_material
	forge.store.notice="Click to place · %s" % (("face centres snapped" if center_selected else ("nearest edge aligned" if edge_selected else "face snapped")) if snapping else "grid %.2f m" % grid) if valid_preview else "Blocked: use loaded terrain or enable Phased placement."
func commit_preview() -> bool:
	if not valid_preview or preview_records.is_empty(): return false
	var before: Array=forge.store.snapshot();var ids := []
	if moving: forge.store.records=forge.store.records.filter(func(r): return r.id not in selection)
	for item in preview_records: forge.store.records.append(item.duplicate(true));ids.append(item.id)
	forge.store.commit(before);cancel_preview();selection=ids;refresh_selection();sync_fields();forge.store.notice="Placed. Ctrl+D copies; G moves; Shift-click selects more.";return true

func join_selection() -> void:
	cancel_preview();forge.store.join(selection);refresh_selection()
func unjoin_selection() -> void:
	cancel_preview();forge.store.unjoin(selection);refresh_selection()
func delete_selection() -> void:
	cancel_preview();forge.store.erase(selection);selection=[];refresh_selection()
func set_finish(value: int) -> void:
	finish=value
	for i in color_buttons.size(): color_buttons[i].set_pressed_no_signal(i==value)
	if not draft.is_empty():
		for item in draft: item.finish=value
		return
	var before: Array=forge.store.snapshot()
	for item in forge.store.records:
		if item.id in selection: item.finish=value
	forge.store.commit(before)
	forge.store.notice="Colour: "+Parts.COLOR_NAMES[value]+" · %d selected parts" % selection.size()
func set_preview_angle(axis: int, degrees: float) -> void:
	if not syncing and not draft.is_empty(): rotation_delta[axis]=deg_to_rad(degrees)
func sync_fields() -> void:
	if position_fields.is_empty(): return
	syncing=true
	var item: Dictionary=forge.store.find(selection[0]) if not selection.is_empty() else {}
	var rotation := Vector3.ZERO
	if not item.is_empty():
		finish=item.finish
		for i in color_buttons.size(): color_buttons[i].set_pressed_no_signal(i==finish)
		for i in 3: position_fields[i].set_value_no_signal(item.p[i])
		var pose := Store.pose(item);rotation=(Ring.tangent_basis(pose.origin,0).inverse()*pose.basis).get_euler()
	if not draft.is_empty(): rotation=rotation_delta
	for i in 3: rotation_fields[i].set_value_no_signal(rad_to_deg(rotation[i]))
	syncing=false
func apply_pose(pose: Transform3D) -> void:
	if selection.is_empty(): return
	var primary: Dictionary=forge.store.find(selection[0])
	if primary.is_empty(): return
	var delta := pose*Store.pose(primary).affine_inverse()
	var proposed := []
	for id in selection:
		var item: Dictionary=forge.store.find(id).duplicate(true);Store.set_pose(item,delta*Store.pose(item))
		if not Store.valid_record(item): forge.store.notice="Transform is outside the supported world coordinates.";return
		proposed.append(item)
	if not phased and not forge.clear_placement(proposed,selection): forge.store.notice="Blocked transform. Enable Phased to overlap parts.";return
	forge.store.transform_selection(selection,delta);refresh_selection();sync_fields()
func apply_position() -> void:
	cancel_preview()
	if selection.is_empty(): return
	var old := Store.pose(forge.store.find(selection[0]));var p := Ring.point(position_fields[0].value,position_fields[1].value,position_fields[2].value)
	var basis := Ring.tangent_basis(p,0)*Ring.tangent_basis(old.origin,0).inverse()*old.basis
	apply_pose(Transform3D(basis,p))
func apply_orientation() -> void:
	if not draft.is_empty(): return
	if selection.is_empty(): return
	var pose := Store.pose(forge.store.find(selection[0]))
	pose.basis=Ring.tangent_basis(pose.origin,0)*Basis.from_euler(Vector3(deg_to_rad(rotation_fields[0].value),deg_to_rad(rotation_fields[1].value),deg_to_rad(rotation_fields[2].value)))
	apply_pose(pose)
func nudge(axis: int, direction: int) -> void:
	if not draft.is_empty():
		forge.store.notice="Place the part before using local-axis nudges. Shift-wheel adjusts preview height.";return
	if selection.is_empty(): return
	var pose := Store.pose(forge.store.find(selection[0]));pose.origin+=pose.basis[axis]*direction*(grid if grid>0 else .25);apply_pose(pose)
func rotate_axis(axis: int, direction: int) -> void:
	if not draft.is_empty(): rotation_delta[axis]+=deg_to_rad(angle_step*direction);sync_fields();return
	if selection.is_empty(): return
	var pose := Store.pose(forge.store.find(selection[0]));var direction_axis := Vector3.ZERO;direction_axis[axis]=1
	pose.basis=pose.basis*Basis(direction_axis,deg_to_rad(angle_step*direction));apply_pose(pose)
func refresh_selection() -> void:
	if not is_instance_valid(selection_text): return
	selection=selection.filter(func(id): return not forge.store.find(id).is_empty())
	selection_text.text="%d selected · Shift-click to add" % selection.size()
	if selection.size()==1: selection_text.text=Parts.NAMES[forge.store.find(selection[0]).kind]+" · selected"
	if not is_instance_valid(outline): return
	if selection.is_empty(): outline.mesh=null;return
	var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for id in selection:
		var item: Dictionary=forge.store.find(id);var pose := Store.pose(item);var half: Vector3=Parts.get_part(item.kind).size*.505
		var vertices := []
		for x in [-1,1]:
			for y in [-1,1]:
				for z in [-1,1]: vertices.append(pose*Vector3(x*half.x,y*half.y,z*half.z))
		for i in 8:
			for bit in [1,2,4]:
				if (i&bit)==0: mesh.surface_add_vertex(vertices[i]);mesh.surface_add_vertex(vertices[i|bit])
	mesh.surface_end();outline.mesh=mesh

func handle_input(event: InputEvent) -> bool:
	if foliage_review and (foliage_review.sampling or foliage_review.dialog.visible): return true
	if not opened or tool!="forge": return super.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1: toggle();return true
		if event.ctrl_pressed and event.keycode==KEY_S: save();return true
		var focused := arena.get_viewport().gui_get_focus_owner()
		if focused is LineEdit: return true
		if event.ctrl_pressed and event.keycode==KEY_Z: undo();return true
		if event.ctrl_pressed and event.keycode==KEY_Y: redo();return true
		if event.ctrl_pressed and event.keycode==KEY_D: start_move(true);return true
		if not looking:
			match event.keycode:
				KEY_G: start_move(false);return true
				KEY_DELETE: delete_selection();return true
				KEY_Q: rotate_axis(1,-1);return true
				KEY_E: rotate_axis(1,1);return true
				KEY_ESCAPE: cancel_preview();return true
				KEY_ENTER: commit_preview();return true
	if event is InputEventMouseButton and event.pressed and not over_panel() and not looking:
		if event.button_index==MOUSE_BUTTON_LEFT:
			var focus := arena.get_viewport().gui_get_focus_owner()
			if focus: focus.release_focus()
			if not draft.is_empty(): update_preview(forge.ray_pick(selection if moving else []));commit_preview()
			else:
				var hit: Dictionary=forge.ray_pick();select_id(int(hit.get("id",0)),event.shift_pressed)
			return true
		if event.shift_pressed and not draft.is_empty() and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			lift+=(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1)*(grid if grid>0 else .25);return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: return true
	return super.handle_input(event)
func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(build_notice): return
	if is_instance_valid(outline): outline.visible=opened and tool=="forge" and draft.is_empty()
	if opened and tool=="forge":
		build_notice.text=forge.store.notice+"\n%d parts · %s" % [forge.store.records.size(),"Unsaved" if forge.store.unsaved() else "Saved"]
		if displayed_revision!=forge.store.revision: displayed_revision=forge.store.revision;refresh_selection()
func _physics_process(delta: float) -> void:
	if not opened or tool!="forge" or draft.is_empty() or looking or over_panel(): return
	preview_clock-=delta
	if preview_clock>0: return
	preview_clock=.05;update_preview(forge.ray_pick(selection if moving else []))
