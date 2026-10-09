extends "res://world/terrain_drive_editor.gd"
var paint_button: Button
var erase_button: Button
var tree_rows: VBoxContainer
var tree_species := -1
var tree_height := 9.0
var tree_density := 4.0
var painting := false
var pending_tree_action := ""
var action_buttons: Array=[]

func setup(owner_arena: Node3D) -> void:
	super.setup(owner_arena)
	var column: VBoxContainer=tool_help.get_parent()
	var render_buttons := HBoxContainer.new();column.add_child(render_buttons)
	var light_button := Button.new();light_button.text="Daylight…";light_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;render_buttons.add_child(light_button)
	var terrain_button := Button.new();terrain_button.text="Terrain rendering…";terrain_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;render_buttons.add_child(terrain_button)
	terrain_button.pressed.connect(func(): finish_paint();finish_stroke();arena.edited_render_lods.dialog.popup_centered())
	light_button.pressed.connect(func(): finish_paint();finish_stroke();arena.daylight.dialog.popup_centered())
	var tree_buttons := HBoxContainer.new();column.add_child(tree_buttons);column.move_child(tree_buttons,2)
	paint_button=Button.new();paint_button.text="Paint trees";paint_button.toggle_mode=true;paint_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	erase_button=Button.new();erase_button.text="Erase trees";erase_button.toggle_mode=true;erase_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tree_buttons.add_child(paint_button);tree_buttons.add_child(erase_button)
	paint_button.pressed.connect(select_tool.bind("trees"));erase_button.pressed.connect(select_tool.bind("erase_trees"))
	tree_rows=VBoxContainer.new();column.add_child(tree_rows);column.move_child(tree_rows,5)
	var species := OptionButton.new();species.add_item("Mixed firs")
	for label in ["Tall fir","Medium fir","Sapling"]: species.add_item(label)
	species.item_selected.connect(func(index): tree_species=index-1);tree_rows.add_child(species)
	number_row(tree_rows,"Tree height (m)",1,30,.5,tree_height,func(value): tree_height=value)
	number_row(tree_rows,"Trees / 100 m²",1,12,1,tree_density,func(value): tree_density=value)
	var hint := Label.new();hint.text="Height varies ±20%. Minimum spacing 3 m.\nUndo/redo apply to the selected tool.\nErase affects painted trees, not demo trees.";hint.add_theme_font_size_override("font_size",12);tree_rows.add_child(hint)
	for button in panel.find_children("*","Button",true,false):
		if button.text in ["Undo","Redo","Save terrain","Load saved"]: action_buttons.append(button)
	select_tool("hill")

func is_tree_tool() -> bool:
	return tool in ["trees","erase_trees"]

func select_tool(kind: String) -> void:
	finish_paint()
	super.select_tool(kind if kind not in ["trees","erase_trees"] else "hill")
	tool=kind
	if not is_instance_valid(tree_rows): return
	paint_button.set_pressed_no_signal(kind=="trees");erase_button.set_pressed_no_signal(kind=="erase_trees")
	tree_rows.visible=is_tree_tool();strength_row.visible=kind in ["hill","lower"]
	radius_control.max_value=60 if is_tree_tool() else 120
	if is_tree_tool():
		for button in tool_buttons: button.set_pressed_no_signal(false)
		tool_help.text="Hold LMB and drag to "+("paint trees on the terrain." if kind=="trees" else "erase painted trees.")
	for button in action_buttons:
		if button.text.begins_with("Save"): button.text="Save terrain + trees"
		elif button.text.begins_with("Load"): button.text="Load trees" if is_tree_tool() else "Load terrain"
		elif button.text.begins_with("Undo"): button.text="Undo trees" if is_tree_tool() else "Undo terrain"
		elif button.text.begins_with("Redo"): button.text="Redo trees" if is_tree_tool() else "Redo terrain"

func finish_paint() -> void:
	painting=false
	if arena and is_instance_valid(arena.get("painted_trees")): arena.painted_trees.release()

func toggle() -> void:
	finish_paint();super.toggle()
	if not opened and arena.on_foot.active:
		arena.on_foot.update_camera();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func save() -> void:
	finish_paint();super.save();arena.painted_trees.request_save()

func undo() -> void:
	if not is_tree_tool(): super.undo();return
	finish_paint();pending_tree_action="undo"

func redo() -> void:
	if not is_tree_tool(): super.redo();return
	finish_paint();pending_tree_action="redo"

func load_saved() -> void:
	if not is_tree_tool(): super.load_saved();return
	finish_paint();pending_tree_action="load"

func handle_input(event: InputEvent) -> bool:
	if arena.daylight.dialog.visible or arena.edited_render_lods.dialog.visible: return true
	if opened and is_tree_tool():
		if event is InputEventMouseButton:
			if event.button_index==MOUSE_BUTTON_RIGHT: finish_paint()
			if event.button_index==MOUSE_BUTTON_LEFT:
				if not event.pressed: finish_paint();return true
				if looking or over_panel() or not pending_tree_action.is_empty() or save_when_ready: return true
				var hit := pick()
				if not hit.is_empty():
					painting=arena.painted_trees.begin_paint(hit.position,{"radius":radius,"density":tree_density,"height":tree_height,"species":tree_species,"erase":tool=="erase_trees"})
				return true
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: finish_paint()
	return super.handle_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if not arena or not is_instance_valid(arena.get("painted_trees")): return
	var painter: Node3D=arena.painted_trees
	if not pending_tree_action.is_empty() and not painter.busy():
		match pending_tree_action:
			"undo": painter.undo_paint()
			"redo": painter.redo_paint()
			"load": painter.load_paint()
		pending_tree_action=""
	if not opened: return
	if not arena.loading.dismissed: finish_paint();return
	if painting:
		if aim_valid and not looking and not over_panel(): painter.enqueue(aim)
		else: painter.last_point=Vector2(INF,INF)
	if is_tree_tool():
		notice.text=painter.store.notice
		state_label.text="%d painted trees · %s" % [painter.store.records.size(),"Painting…" if painter.busy() else ("Unsaved" if painter.store.unsaved() else "Saved")]
	else:
		state_label.text+="\nTrees: %d · %s" % [painter.store.records.size(),"Unsaved" if painter.store.unsaved() else "Saved"]
