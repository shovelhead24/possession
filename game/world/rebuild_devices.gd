extends Node
var arena: Node3D
var preferred_audio := "Realtek"
var controller_mode := "auto"
var settings_path := "user://Rebuild Demo/devices.cfg"
var clock := 0.0
var output_list: OptionButton
var status: Label
var available_audio := PackedStringArray()
var output_lists: Array[OptionButton]=[]
var status_labels: Array[Label]=[]
var source_choices: Array[OptionButton]=[]
func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--devices-file="): settings_path=arg.trim_prefix("--devices-file=")
	var config=ConfigFile.new()
	if config.load(settings_path)==OK:
		preferred_audio=str(config.get_value("devices","audio","Realtek"))
		controller_mode=str(config.get_value("devices","controller","auto"))
	if controller_mode not in ["auto","native","virtual"]: controller_mode="auto"
	refresh_audio()
static func choose_audio(devices: PackedStringArray, wanted: String) -> String:
	if devices.has(wanted): return wanted
	for entry in devices:
		if wanted.to_lower() in entry.to_lower(): return entry
	return ""
func refresh_audio() -> void:
	var devices=AudioServer.get_output_device_list()
	var wanted=choose_audio(devices,preferred_audio)
	if not wanted.is_empty() and AudioServer.output_device!=wanted:
		AudioServer.output_device=wanted;print("REBUILD_AUDIO: pinned output ",wanted)
	for output in output_lists:
		if devices!=available_audio:
			output.clear()
			for entry in devices: output.add_item(entry)
		for index in output.item_count:
			if output.get_item_text(index)==AudioServer.output_device: output.select(index)
	available_audio=devices
	for label in status_labels:
		label.text="Audio: "+AudioServer.output_device+(" (preferred output unavailable)" if wanted.is_empty() else "")+"\nController: "+arena.controller.device_name
	for choices in source_choices: choices.select(["auto","native","virtual"].find(controller_mode))
func save() -> void:
	var config=ConfigFile.new();config.set_value("devices","audio",preferred_audio);config.set_value("devices","controller",controller_mode)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_path).get_base_dir())
	if config.save(settings_path)!=OK: push_warning("Could not save device preferences")
func add_menu(menu: Node) -> void:
	var tabs: TabContainer
	for child in menu.panel.get_child(0).get_children():
		if child is TabContainer: tabs=child;break
	if not tabs: return
	var page=menu.page(tabs,"Devices")
	var heading=Label.new();heading.text="Controller source";page.add_child(heading)
	var choices=OptionButton.new();choices.add_item("Auto (keep connected device)");choices.add_item("Native DualSense - bypass DS4Windows");choices.add_item("DS4Windows / XInput only");page.add_child(choices)
	choices.select(["auto","native","virtual"].find(controller_mode));source_choices.append(choices)
	choices.item_selected.connect(func(index): controller_mode=["auto","native","virtual"][index];arena.controller.source_mode=controller_mode;arena.controller.scan_devices();save())
	var audio_heading=Label.new();audio_heading.text="Game audio output";page.add_child(audio_heading)
	var output=OptionButton.new();output.custom_minimum_size.x=480;page.add_child(output);output_lists.append(output);output_list=output
	for entry in available_audio: output.add_item(entry)
	output.item_selected.connect(func(index): preferred_audio=output.get_item_text(index);refresh_audio();save())
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(status);status_labels.append(status)
	var help=Label.new();help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.text="Native accepts USB or a controller already paired in Windows Bluetooth. It does not change DS4Windows or pair devices. Realtek keeps audio on the PC when the controller reconnects. A bad USB connection can still disconnect native input.";page.add_child(help)
	refresh_audio()
func _process(delta: float) -> void:
	clock-=delta
	if clock<=0: clock=1;refresh_audio()
func telemetry() -> Dictionary:
	return {"audio":AudioServer.output_device,"preferred_audio":preferred_audio,"controller_mode":controller_mode}
