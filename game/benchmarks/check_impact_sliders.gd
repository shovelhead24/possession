extends SceneTree
class Kit extends Node:
	var vehicles=[]
	var driver_look=Vector2.ZERO
func _initialize(): run.call_deferred()
func run():
	root.size=Vector2i(1366,768)
	var kit=Kit.new();root.add_child(kit)
	var car=preload("res://world/wishbone_vehicle.gd").new();kit.add_child(car);car.freeze=true;car.set_physics_process(false);kit.vehicles.append(car)
	var menu=preload("res://world/vehicle_menu.gd").new()
	menu.config_path="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/work/impact-slider-test.cfg"
	kit.add_child(menu)
	menu.controls.impact_min_speed.value=2.25
	menu.controls.impact_damage.value=55
	menu.controls.impact_forward.value=2.1
	menu.controls.impact_lift.value=2.5
	assert(car.impact_min_speed==2.25 and car.impact_damage==55 and is_equal_approx(car.impact_forward,2.1) and car.impact_lift==2.5)
	car.impact_damage=1;menu.load_settings();assert(car.impact_damage==55,"Saved tuning restored even if slider value is unchanged")
	menu.reset_defaults();assert(car.impact_min_speed==1 and car.impact_damage==30 and car.impact_lift==1.5)
	var tabs=menu.panel.find_children("*","TabContainer",true,false)[0]
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i)=="Impacts": tabs.current_tab=i
	menu.set_open(true)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/impact-sliders.png")
	print("IMPACT_SLIDERS_PASS: live values, isolated save/load, defaults")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	kit.queue_free()
	await process_frame
	quit(0)
