@tool
extends Control

const PARTS_DIR := "res://pipeline/parts/"
const RECIPES_DIR := "res://pipeline/recipes/"

const BIPED_SLOTS := [
	"head", "torso",
	"left_upper_arm", "left_forearm", "left_hand",
	"right_upper_arm", "right_forearm", "right_hand",
	"left_thigh", "left_shin", "left_foot",
	"right_thigh", "right_shin", "right_foot",
]

const BIPED_BONES := {
	"head":            "mixamorig_Head",
	"torso":           "mixamorig_Spine1",
	"left_upper_arm":  "mixamorig_LeftArm",
	"left_forearm":    "mixamorig_LeftForeArm",
	"left_hand":       "mixamorig_LeftHand",
	"right_upper_arm": "mixamorig_RightArm",
	"right_forearm":   "mixamorig_RightForeArm",
	"right_hand":      "mixamorig_RightHand",
	"left_thigh":      "mixamorig_LeftUpLeg",
	"left_shin":       "mixamorig_LeftLeg",
	"left_foot":       "mixamorig_LeftFoot",
	"right_thigh":     "mixamorig_RightUpLeg",
	"right_shin":      "mixamorig_RightLeg",
	"right_foot":      "mixamorig_RightFoot",
}

var _body_plan: String = "biped"
var _recipe: CharacterRecipe = CharacterRecipe.new()
var _slot_buttons: Dictionary = {}   # slot -> Button
var _part_library: Dictionary = {}   # body_plan -> [PartDef, ...]
var _status_label: Label

func _init() -> void:
	name = "Char Pipeline"
	custom_minimum_size = Vector2(260, 0)

func _ready() -> void:
	_build_ui()
	_scan_parts()
	_refresh_recipe_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# ── Header ──────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Character Pipeline"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ── Body plan selector ───────────────────────────────────────────────────
	var plan_row := HBoxContainer.new()
	vbox.add_child(plan_row)
	var plan_label := Label.new()
	plan_label.text = "Body plan:"
	plan_row.add_child(plan_label)
	var plan_opt := OptionButton.new()
	plan_opt.add_item("biped")
	plan_opt.add_item("quadruped")
	plan_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_opt.item_selected.connect(_on_body_plan_changed)
	plan_row.add_child(plan_opt)

	vbox.add_child(HSeparator.new())

	# ── Slot list ────────────────────────────────────────────────────────────
	var slots_label := Label.new()
	slots_label.text = "Slots"
	vbox.add_child(slots_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)

	var slot_vbox := VBoxContainer.new()
	slot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_vbox)

	for slot in BIPED_SLOTS:
		var row := HBoxContainer.new()
		slot_vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = slot.replace("_", " ")
		lbl.custom_minimum_size = Vector2(110, 0)
		lbl.clip_text = true
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "(none)"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(btn)

		var clr := Button.new()
		clr.text = "X"
		clr.custom_minimum_size = Vector2(24, 0)
		clr.pressed.connect(_on_slot_cleared.bind(slot))
		row.add_child(clr)

		_slot_buttons[slot] = btn

	vbox.add_child(HSeparator.new())

	# ── Recipe name + save/load ──────────────────────────────────────────────
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "recipe_name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t): _recipe.label = t)
	name_row.add_child(name_edit)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var save_btn := Button.new()
	save_btn.text = "Save Recipe"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_recipe)
	btn_row.add_child(save_btn)

	var export_btn := Button.new()
	export_btn.text = "Export Scene"
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_btn.pressed.connect(_export_scene)
	btn_row.add_child(export_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

# ── Part scanning ────────────────────────────────────────────────────────────

func _scan_parts() -> void:
	_part_library.clear()
	_scan_dir(PARTS_DIR)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir() and not fname.begins_with("."):
			_scan_dir(path + fname + "/")
		elif fname.ends_with(".tres") or fname.ends_with(".res"):
			var full := path + fname
			var res := load(full)
			if res is PartDef:
				var plan: String = res.body_plan
				if not _part_library.has(plan):
					_part_library[plan] = []
				_part_library[plan].append(res)
		fname = dir.get_next()

# ── UI callbacks ─────────────────────────────────────────────────────────────

func _on_body_plan_changed(idx: int) -> void:
	_body_plan = ["biped", "quadruped"][idx]
	_recipe = CharacterRecipe.new()
	_recipe.body_plan = _body_plan
	_refresh_recipe_ui()

func _on_slot_pressed(slot: String) -> void:
	var parts: Array = _part_library.get(_body_plan, [])
	var candidates := parts.filter(func(p: PartDef): return p.slot == slot)
	if candidates.is_empty():
		_set_status("No parts found for slot '%s' — add .tres PartDef files to pipeline/parts/%s/" % [slot, _body_plan])
		return
	_show_picker(slot, candidates)

func _on_slot_cleared(slot: String) -> void:
	_recipe.parts.erase(slot)
	_refresh_recipe_ui()

func _show_picker(slot: String, candidates: Array) -> void:
	var popup := PopupPanel.new()
	add_child(popup)
	var vb := VBoxContainer.new()
	popup.add_child(vb)
	var lbl := Label.new()
	lbl.text = "Pick part for: " + slot
	vb.add_child(lbl)
	for part: PartDef in candidates:
		var btn := Button.new()
		btn.text = part.label if part.label != "" else part.resource_path.get_file()
		btn.pressed.connect(func():
			_recipe.parts[slot] = part
			_refresh_recipe_ui()
			popup.queue_free()
		)
		vb.add_child(btn)
	popup.popup_centered(Vector2(240, 0))

func _refresh_recipe_ui() -> void:
	for slot in _slot_buttons:
		var btn: Button = _slot_buttons[slot]
		var part: PartDef = _recipe.parts.get(slot, null)
		if part:
			btn.text = part.label if part.label != "" else part.resource_path.get_file().get_basename()
			btn.modulate = Color(0.6, 1.0, 0.6)
		else:
			btn.text = "(none)"
			btn.modulate = Color(1, 1, 1)

func _save_recipe() -> void:
	var rname := _recipe.label.strip_edges()
	if rname == "":
		_set_status("Set a name before saving.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECIPES_DIR))
	var path := RECIPES_DIR + rname + ".tres"
	var err := ResourceSaver.save(_recipe, path)
	if err == OK:
		_set_status("Saved: " + path)
	else:
		_set_status("Save failed (err %d)" % err)

func _export_scene() -> void:
	if _recipe.parts.is_empty():
		_set_status("Recipe is empty — assign at least one part.")
		return
	# Inject bone names from the slot map before assembling
	for slot in _recipe.parts:
		var part: PartDef = _recipe.parts[slot]
		if part.bone_name == "" and BIPED_BONES.has(slot):
			part.bone_name = BIPED_BONES[slot]

	var root := CharacterAssembler.assemble(_recipe)
	if not root:
		_set_status("Assembly failed — check template exists.")
		return

	var rname := _recipe.label.strip_edges()
	if rname == "":
		rname = "character_export"
	var out_path := "res://pipeline/exports/" + rname + ".tscn"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://pipeline/exports/")
	)
	var packed := PackedScene.new()
	packed.pack(root)
	root.queue_free()
	var err := ResourceSaver.save(packed, out_path)
	if err == OK:
		_set_status("Exported: " + out_path)
		EditorInterface.get_resource_filesystem().scan()
	else:
		_set_status("Export failed (err %d)" % err)

func _set_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
