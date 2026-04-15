extends CanvasLayer

# Pause / controls overlay.
# Toggle: Esc (keyboard) or Start (controller).
# Quit & push log: Enter (keyboard) or X (controller).

var is_open: bool = false

func _ready() -> void:
	layer = 100
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Dim backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred panel
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "POSSESSION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Two-column controls table
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	vbox.add_child(cols)

	cols.add_child(_make_col("KEYBOARD / MOUSE", [
		["F3",            "Toggle editor"],
		["WASD",          "Pan camera"],
		["Q / E",         "Altitude"],
		["1 / 2",         "Zoom step"],
		["Shift+drag",    "Orbit camera"],
		["Ctrl+drag",     "Pan camera"],
		["Scroll",        "Brush size"],
		["M",             "Cycle brush mode"],
		["F",             "Cycle falloff"],
		["R (hold)",      "Boost strength"],
		["LMB",           "Apply brush"],
		["RMB",           "Lower terrain"],
		["Esc",           "This menu"],
		["Enter",         "Quit & push log"],
	]))

	cols.add_child(VSeparator.new())

	cols.add_child(_make_col("CONTROLLER", [
		["—",             "Toggle editor"],
		["Left stick",    "Pan camera"],
		["—",             "—"],
		["D-pad ↑/↓",    "Zoom step"],
		["Right stick",   "Orbit / free cursor"],
		["R3",            "Toggle cursor mode"],
		["LB / RB",       "Brush size"],
		["Y",             "Cycle brush mode"],
		["D-pad ←/→",   "Cycle falloff"],
		["X (hold)",      "Boost strength"],
		["RT",            "Apply brush"],
		["LT",            "Lower terrain"],
		["Start",         "This menu"],
		["X",             "Quit & push log"],
	]))

	# Note
	var note := Label.new()
	note.text = "Right stick default = orbit.  Press R3 to switch to free-cursor aim."
	note.add_theme_font_size_override("font_size", 11)
	note.modulate = Color(0.55, 0.55, 0.55)
	vbox.add_child(note)

	vbox.add_child(HSeparator.new())

	# Footer
	var footer := Label.new()
	footer.text = "[Esc / Start]  Close          [Enter / X]  Quit & push log"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 14)
	footer.modulate = Color(1.0, 0.75, 0.2)
	vbox.add_child(footer)

func _make_col(heading: String, rows: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 13)
	h.modulate = Color(1.0, 0.65, 0.1)
	col.add_child(h)
	col.add_child(HSeparator.new())

	for row in rows:
		var rb := HBoxContainer.new()
		col.add_child(rb)

		var k := Label.new()
		k.text = row[0]
		k.custom_minimum_size.x = 120
		k.add_theme_font_size_override("font_size", 12)
		rb.add_child(k)

		var d := Label.new()
		d.text = row[1]
		d.add_theme_font_size_override("font_size", 12)
		d.modulate = Color(0.70, 0.70, 0.70)
		rb.add_child(d)

	return col

func toggle() -> void:
	is_open = not is_open
	visible = is_open

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		var ek := event as InputEventKey
		if not ek.pressed or ek.echo:
			return
		if ek.physical_keycode == KEY_ESCAPE:
			toggle()
		elif ek.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_quit_and_push()
	elif event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return
		if jb.button_index == JOY_BUTTON_START:
			toggle()
		elif jb.button_index == JOY_BUTTON_X:
			_quit_and_push()

func _quit_and_push() -> void:
	# Write flag so the watcher pushes log and doesn't relaunch
	var flag := ProjectSettings.globalize_path("res://logs/quit_requested")
	var f := FileAccess.open(flag, FileAccess.WRITE)
	if f:
		f.store_string("1")
		f.close()
	get_tree().quit()
