extends SceneTree
const Devices=preload("res://world/rebuild_devices.gd")
class Controller extends Node:
	var device_name="DualSense Wireless Controller"
	var source_mode="auto"
	func scan_devices(): pass
class Arena extends Node3D:
	var controller=Controller.new()
func _initialize(): run.call_deferred()
func run():
	root.size=Vector2i(1280,800)
	assert(Devices.choose_audio(PackedStringArray(["Default","Speakers (3- Realtek(R) Audio)","Speakers (DualSense Wireless Controller)"]),"Realtek")=="Speakers (3- Realtek(R) Audio)")
	assert(Devices.choose_audio(PackedStringArray(["Default"]),"Realtek")=="","Absent device is reported, not mistaken for default")
	var arena=Arena.new();root.add_child(arena);arena.add_child(arena.controller)
	var devices=Devices.new();devices.settings_path="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/work/test-devices.cfg";arena.add_child(devices);devices.setup(arena)
	var menu=load("res://world/vehicle_menu.gd").new()
	menu.panel=PanelContainer.new();menu.panel.position=Vector2(24,24);menu.panel.size=Vector2(540,620);root.add_child(menu.panel)
	var column=VBoxContainer.new();menu.panel.add_child(column);var tabs=TabContainer.new();tabs.custom_minimum_size=Vector2(510,430);column.add_child(tabs)
	for name in ["Suspension","Steering","Engine","Axles","Camera"]: menu.page(tabs,name)
	devices.add_menu(menu);tabs.current_tab=tabs.get_tab_count()-1
	var page=tabs.get_current_tab_control();var choices=page.get_child(1)
	choices.select(1);choices.item_selected.emit(1)
	assert(arena.controller.source_mode=="native" and devices.controller_mode=="native")
	var config=ConfigFile.new();assert(config.load(devices.settings_path)==OK and config.get_value("devices","controller")=="native","Device preference saves")
	var realtek=Devices.choose_audio(AudioServer.get_output_device_list(),"Realtek")
	if not realtek.is_empty(): assert(AudioServer.output_device==realtek,"Real output pin applied")
	var second=load("res://world/vehicle_menu.gd").new()
	second.panel=PanelContainer.new();root.add_child(second.panel);second.panel.hide()
	var second_column=VBoxContainer.new();second.panel.add_child(second_column);second_column.add_child(TabContainer.new())
	devices.add_menu(second);devices.refresh_audio()
	assert(devices.output_lists.size()==2 and devices.source_choices.size()==2)
	assert(devices.output_lists[0].item_count==devices.output_lists[1].item_count)
	assert(devices.source_choices[0].selected==devices.source_choices[1].selected)
	second.panel.free();second.free()
	devices.output_lists.pop_back();devices.source_choices.pop_back();devices.status_labels.pop_back()
	print("DEVICES_PASS audio=",AudioServer.output_device," available=",AudioServer.get_output_device_list())
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/devices-menu.png")
	menu.free();quit()
