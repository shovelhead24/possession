extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene=load("res://tactical.tscn").instantiate();root.add_child(scene)
	await process_frame
	var kit=scene.kit;var menu=kit.menu;var car=kit.vehicles[0]
	var original={}
	for key in menu.controls:
		original[key]=menu.settings[key] if key.begins_with("camera_") else car.get(key)
	menu.controls.spring_rate.value=35000
	menu.controls.engine_force.value=2400
	assert(car.spring_rate==35000 and car.engine_force==2400,"Sliders must update physics")
	car.spring_rate=28000;menu.load_settings();assert(car.spring_rate==35000,"Saved tuning must reload")
	scene.walker.position=car.position+Vector3(3,0,0);kit.toggle_vehicle()
	assert(kit.driving==car and kit.driver_model.visible)
	var switch=InputEventKey.new();switch.keycode=KEY_C;switch.pressed=true
	var old_mode=int(menu.settings.camera_mode)
	assert(kit.handle_vehicle_input(switch) and int(menu.settings.camera_mode)!=old_mode,"C must switch views")
	var weapon=InputEventKey.new();weapon.keycode=KEY_Q;weapon.pressed=true
	var old_weapon=kit.selected;kit._input(weapon);assert(kit.selected!=old_weapon,"Q must cycle weapons")
	var sound=car.get_node("DrivingAudio")
	assert(sound.engine.stream.data.size()>0,"Engine sound must contain samples")
	menu.set_open(true);kit._physics_process(.016)
	assert(car.throttle==0 and car.braking,"Menu must block driving and apply brakes")
	menu.settings.camera_mode=1.0;kit.update_vehicle_camera(.016)
	assert(scene.camera.global_position.distance_to(car.to_global(kit.seat_position+Vector3(0,.68,-.03)))<.01)
	assert(not kit.driver_model.visible)
	menu.settings.camera_mode=0.0;kit.update_vehicle_camera(.016);assert(kit.driver_model.visible)
	if OS.get_cmdline_user_args().has("--pictures"):
		await create_timer(3.0).timeout
		assert(car.grounded_count==4,"Resized vehicle must settle on all four tyres")
		scene.camera.position=car.position+Vector3(-4,3,-4);scene.camera.look_at(car.position+Vector3(0,1.5,0))
		kit.set_physics_process(false);menu.set_open(false)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/seated-driver.png")
		menu.set_open(true)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/vehicle-menu.png")
		menu.panel.get_child(0).get_child(2).current_tab=3
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/camera-buttons.png")
		menu.set_open(false);menu.settings.camera_mode=1.0;kit.update_vehicle_camera(.016)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/driver-view.png")
	for key in original:
		if key=="camera_mode": menu.settings[key]=original[key];menu.controls[key].select(int(original[key]))
		else: menu.controls[key].value=original[key]
	menu.save_settings();menu.set_open(false)
	if OS.get_cmdline_user_args().has("--reset-settings"): menu.reset_defaults()
	var key=InputEventKey.new();key.keycode=KEY_F2;key.pressed=true
	assert(kit.handle_vehicle_input(key) and menu.opened)
	key.keycode=KEY_ESCAPE;assert(kit.handle_vehicle_input(key) and not menu.opened)
	print("PASS: live tuning, menu brakes, seated driver, driver/chase cameras; settings restored")
	quit()
