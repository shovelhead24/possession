extends RefCounted
## Tool-specific UI; settings only regenerate on placement or explicit Apply.
const Recipe=preload("res://world/sdf_recipe.gd")
var root: Node
var mountain := Recipe.feature("mountain",Vector3.ZERO)
var trees := Recipe.feature("trees",Vector3.ZERO)
var mountain_choice: OptionButton
var controls := {}
var noise: OptionButton
var tree_erase := false

func setup(owner_node: Node, column: VBoxContainer) -> void:
	root=owner_node
	var toggle := CheckButton.new();toggle.text="Mountains / erosion / tree painting";column.add_child(toggle)
	var box := VBoxContainer.new();column.add_child(box);box.hide()
	toggle.toggled.connect(func(on: bool): box.visible=on)
	button(box,"Mountain infill: click to place ONE",arm_mountain)
	var info := Label.new();info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.custom_minimum_size.x=270
	info.text="Seeded height infill, added to existing SDF. Water moves sediment downhill; wind transports exposed slopes downwind. Stylised simulation, not a weather model. Settings apply on placement or Apply, not while adjusting sliders."
	box.add_child(info)
	noise=OptionButton.new()
	for label in ["Ridged mountains","Smooth simplex fBm","Perlin fBm"]: noise.add_item(label)
	box.add_child(noise);noise.item_selected.connect(func(i: int): mountain.noise=["ridged","simplex","perlin"][i])
	var grid := GridContainer.new();grid.columns=2;box.add_child(grid)
	for spec in [["radius","Footprint radius (m)",8,100,1],["height","Maximum added height (m)",1,40,1],["seed","Noise seed",0,999999,1],["wavelength","Noise wavelength (m)",4,200,1],["octaves","Detail octaves",1,6,1],["roughness","Fine-detail strength",.1,.9,.05],["water","Water erosion",0,1,.05],["wind","Wind erosion",0,1,.05],["wind_direction","Wind heading (degrees)",0,360,15],["erosion_steps","Erosion iterations",0,60,1]]:
		controls[spec[0]]=number(grid,spec,mountain)
	mountain_choice=OptionButton.new();box.add_child(mountain_choice)
	mountain_choice.item_selected.connect(select_mountain)
	button(box,"Apply settings to selected mountain",apply_mountain)
	button(box,"Move selected mountain",func(): root.place_selected())
	button(box,"Paint fir trees: hold LMB",func(): arm_trees(false))
	button(box,"Erase painted tree patches: hold LMB",func(): arm_trees(true))
	var tree_grid := GridContainer.new();tree_grid.columns=2;box.add_child(tree_grid)
	for spec in [["density","Trees per 100 square metres",1,40,1],["tree_height","Typical tree height (m)",3,20,1],["slope_limit","Maximum slope (degrees)",0,60,5],["seed","Scatter seed",0,999999,1]]: number(tree_grid,spec,trees)
	var help := Label.new();help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.custom_minimum_size.x=270
	help.text="Tree brush uses the main radius control. Existing fir LODs + trunk collisions. Paint settles on finished terrain; steep ground is skipped. Erase removes whole painted patches, not the original arena trees. Save/Undo include mountains and trees. Resident painted trees capped at 600."
	box.add_child(help)

func button(parent: Node, title: String, action: Callable) -> void:
	var b := Button.new();b.text=title;parent.add_child(b);b.pressed.connect(action)

func number(parent: Node, spec: Array, settings: Dictionary) -> SpinBox:
	var label := Label.new();label.text=spec[1];parent.add_child(label)
	var spin := SpinBox.new();spin.min_value=spec[2];spin.max_value=spec[3];spin.step=spec[4];spin.value=settings[spec[0]];parent.add_child(spin)
	spin.value_changed.connect(func(value: float):
		settings[spec[0]]=value
		if (root.brush_template.kind=="trees" and settings==trees) or (root.brush_template.kind=="mountain" and settings==mountain):
			root.brush_template[spec[0]]=value;root.refresh())
	return spin

func arm_mountain() -> void:
	root.select_simple_brush("hill")
	root.brush_template=mountain.duplicate(true);root.refresh()
	root.notice.text="MOUNTAIN: click once to add infill. Select it below to revise noise/erosion without stacking another mountain."

func arm_trees(erase: bool) -> void:
	root.select_simple_brush("hill");tree_erase=erase
	var radius: float=root.brush_template.radius
	root.brush_template=trees.duplicate(true);root.brush_template.radius=radius;root.refresh()
	root.notice.text="ERASE: hold LMB to remove overlapping painted patches." if erase else "TREES: hold LMB to paint; terrain must finish before trees settle. Save explicitly."

func refresh() -> void:
	if mountain_choice==null: return
	mountain_choice.clear();mountain_choice.add_item("Select existing mountain…",2147483647)
	for i in root.features.size():
		if root.features[i].kind=="mountain":
			mountain_choice.add_item("Mountain %d" % (i+1),i)
			if root.selected==i: mountain_choice.select(mountain_choice.item_count-1)

func select_mountain(index: int) -> void:
	var id := mountain_choice.get_item_id(index)
	if id>=root.features.size(): return
	root.finish_brush();root.flush_brush();root.selected=id
	var feature: Dictionary=root.features[id]
	for key in controls:
		mountain[key]=feature[key];controls[key].set_value_no_signal(feature[key])
	mountain.noise=feature.noise;noise.select(["ridged","simplex","perlin"].find(feature.noise))
	root.brush_template=feature.duplicate(true);root.brush_mode=false;root.placing=false;root.picking_entry=false;root.picking_endpoint=false;root.tunnel_new_armed=false
	root.brush_mode_toggle.set_pressed_no_signal(false);root.refresh()
	root.notice.text="Editing mountain %d: adjust settings, then Apply. Move uses a terrain click." % (id+1)

func apply_mountain() -> void:
	root.finish_brush();root.flush_brush()
	if root.selected<0 or root.features[root.selected].kind!="mountain": root.notice.text="Select an existing mountain first.";return
	var next: Array=root.features.duplicate(true)
	var f: Dictionary=mountain.duplicate(true);var old: Dictionary=next[root.selected]
	f.x=old.x;f.y=old.y;f.z=old.z
	if not root.mountain_fits(f): return
	next[root.selected]=f;root.change(next)
