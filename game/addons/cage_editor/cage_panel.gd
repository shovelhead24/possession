@tool
class_name CagePanel
extends Control

var _sub_spin: SpinBox
var _inset_spin: SpinBox
var _sym_check: CheckButton
var _status: Label
var _slot_edit: LineEdit
var _bone_edit: LineEdit

func _init() -> void:
	name = "Cage Editor"
	custom_minimum_size = Vector2(220, 0)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vb)

	var title := Label.new()
	title.text = "Cage Editor"
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)
	vb.add_child(HSeparator.new())

	# Template buttons
	var tpl_lbl := Label.new()
	tpl_lbl.text = "New cage:"
	vb.add_child(tpl_lbl)

	var tpl_row := HBoxContainer.new()
	vb.add_child(tpl_row)
	for t in ["head", "hand", "foot", "torso"]:
		var btn := Button.new()
		btn.text = t.capitalize()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_new_cage.bind(t))
		tpl_row.add_child(btn)

	vb.add_child(HSeparator.new())

	# Symmetry
	var sym_row := HBoxContainer.new()
	vb.add_child(sym_row)
	var sym_lbl := Label.new()
	sym_lbl.text = "Symmetry (X):"
	sym_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sym_row.add_child(sym_lbl)
	_sym_check = CheckButton.new()
	_sym_check.button_pressed = true
	_sym_check.toggled.connect(_on_sym_changed)
	sym_row.add_child(_sym_check)

	vb.add_child(HSeparator.new())

	# Subdivisions
	var sub_row := HBoxContainer.new()
	vb.add_child(sub_row)
	var sl := Label.new()
	sl.text = "Subdivisions:"
	sub_row.add_child(sl)
	_sub_spin = SpinBox.new()
	_sub_spin.min_value = 0
	_sub_spin.max_value = 4
	_sub_spin.value = 2
	_sub_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_spin.value_changed.connect(_on_sub_changed)
	sub_row.add_child(_sub_spin)

	vb.add_child(HSeparator.new())

	# Deformers — operate on selected (green) face
	var def_lbl := Label.new()
	def_lbl.text = "Deformers (selected face):"
	vb.add_child(def_lbl)

	# Extrude
	var ext_btn := Button.new()
	ext_btn.text = "Extrude Face"
	ext_btn.pressed.connect(_extrude)
	vb.add_child(ext_btn)

	# Inset row
	var inset_row := HBoxContainer.new()
	vb.add_child(inset_row)
	var inset_btn := Button.new()
	inset_btn.text = "Inset"
	inset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset_btn.pressed.connect(_inset)
	inset_row.add_child(inset_btn)
	_inset_spin = SpinBox.new()
	_inset_spin.min_value = 0.05
	_inset_spin.max_value = 0.75
	_inset_spin.step = 0.05
	_inset_spin.value = 0.25
	_inset_spin.custom_minimum_size = Vector2(70, 0)
	inset_row.add_child(_inset_spin)

	# Scale row
	var scale_row := HBoxContainer.new()
	vb.add_child(scale_row)
	var sl_lbl := Label.new()
	sl_lbl.text = "Scale face:"
	sl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(sl_lbl)
	var scale_up := Button.new()
	scale_up.text = "+"
	scale_up.custom_minimum_size = Vector2(32, 0)
	scale_up.pressed.connect(_scale.bind(1.25))
	scale_row.add_child(scale_up)
	var scale_dn := Button.new()
	scale_dn.text = "−"
	scale_dn.custom_minimum_size = Vector2(32, 0)
	scale_dn.pressed.connect(_scale.bind(0.8))
	scale_row.add_child(scale_dn)

	vb.add_child(HSeparator.new())

	# Bake settings
	var bake_lbl := Label.new()
	bake_lbl.text = "Bake settings:"
	vb.add_child(bake_lbl)

	var slot_row := HBoxContainer.new()
	vb.add_child(slot_row)
	var sll := Label.new()
	sll.text = "Slot:"
	sll.custom_minimum_size = Vector2(50, 0)
	slot_row.add_child(sll)
	_slot_edit = LineEdit.new()
	_slot_edit.placeholder_text = "e.g. head"
	_slot_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_row.add_child(_slot_edit)

	var bone_row := HBoxContainer.new()
	vb.add_child(bone_row)
	var bll := Label.new()
	bll.text = "Bone:"
	bll.custom_minimum_size = Vector2(50, 0)
	bone_row.add_child(bll)
	_bone_edit = LineEdit.new()
	_bone_edit.placeholder_text = "e.g. mixamorig_Head"
	_bone_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bone_row.add_child(_bone_edit)

	var bake_btn := Button.new()
	bake_btn.text = "Bake → PartDef"
	bake_btn.pressed.connect(_bake)
	vb.add_child(bake_btn)

	vb.add_child(HSeparator.new())

	_status = Label.new()
	_status.text = "Select a template to begin."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	vb.add_child(_status)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_cage() -> CageMesh:
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node is CageMesh:
			return node
	return null

# ── Actions ───────────────────────────────────────────────────────────────────

func _new_cage(tpl: String) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root:
		_set_status("Open a scene first.")
		return

	var data: Array
	match tpl:
		"head":  data = CageTemplates.head()
		"hand":  data = CageTemplates.hand()
		"foot":  data = CageTemplates.foot()
		"torso": data = CageTemplates.torso()
		_: return

	var cage := CageMesh.new()
	cage.name = tpl.capitalize() + "Cage"
	cage.subdivision_levels = int(_sub_spin.value)
	cage.symmetry = _sym_check.button_pressed
	root.add_child(cage)
	cage.owner = root
	cage.set_template(data[0], data[1])

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(cage)

	match tpl:
		"head":
			_slot_edit.text = "head"
			_bone_edit.text = "mixamorig_Head"
		"hand":
			_slot_edit.text = "right_hand"
			_bone_edit.text = "mixamorig_RightHand"
		"foot":
			_slot_edit.text = "right_foot"
			_bone_edit.text = "mixamorig_RightFoot"
		"torso":
			_slot_edit.text = "torso"
			_bone_edit.text = "mixamorig_Spine1"

	_set_status("Click a teal handle to select a face.\nDrag face to move it.\nUse Extrude/Inset to add detail.")

func _on_sym_changed(on: bool) -> void:
	var cage := _get_cage()
	if cage:
		cage.symmetry = on

func _on_sub_changed(val: float) -> void:
	var cage := _get_cage()
	if cage:
		cage.subdivision_levels = int(val)

func _extrude() -> void:
	var cage := _get_cage()
	if not cage:
		_set_status("Select a CageMesh node first.")
		return
	if cage.selected_face < 0:
		_set_status("Click a teal face handle to select a face first.")
		return
	cage.extrude_selected()
	_set_status("Extruded. Drag the new face to shape it.")

func _inset() -> void:
	var cage := _get_cage()
	if not cage:
		_set_status("Select a CageMesh node first.")
		return
	if cage.selected_face < 0:
		_set_status("Click a teal face handle to select a face first.")
		return
	cage.inset_selected(_inset_spin.value)
	_set_status("Inset done.")

func _scale(factor: float) -> void:
	var cage := _get_cage()
	if not cage:
		_set_status("Select a CageMesh node first.")
		return
	if cage.selected_face < 0:
		_set_status("Click a teal face handle to select a face first.")
		return
	cage.scale_selected(factor)

func _bake() -> void:
	var cage := _get_cage()
	if not cage:
		_set_status("Select a CageMesh node first.")
		return

	var mesh := CageSubdivider.subdivide(cage.vertices, cage.faces, int(_sub_spin.value))
	var part := PartDef.new()
	part.label     = cage.name
	part.mesh      = mesh
	part.slot      = _slot_edit.text.strip_edges()
	part.bone_name = _bone_edit.text.strip_edges()
	part.body_plan = "biped"

	var dir_path := "res://pipeline/parts/baked/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var save_path := dir_path + cage.name.to_lower().replace(" ", "_") + ".tres"
	var err := ResourceSaver.save(part, save_path)
	if err == OK:
		EditorInterface.get_resource_filesystem().scan()
		_set_status("Baked → %s\nNow visible in Character Pipeline." % save_path)
	else:
		_set_status("Save failed (err %d)" % err)

func _set_status(msg: String) -> void:
	if _status:
		_status.text = msg
