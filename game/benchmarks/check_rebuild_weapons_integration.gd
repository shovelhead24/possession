extends SceneTree
var arena: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapons-output="): output=arg.trim_prefix("--weapons-output=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	create_timer(300).timeout.connect(func(): push_error("Weapon integration timeout");quit(1))
	run.call_deferred()
func key(code: int) -> void:
	var event := InputEventKey.new();event.keycode=code;event.pressed=true;arena._input(event)
func trigger(pressed: bool) -> void:
	var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;arena._input(event)
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(name+".png"))
func measure() -> Dictionary:
	for i in 60: await process_frame
	var values := [];var last := Time.get_ticks_usec()
	for i in 240:
		await process_frame
		var now := Time.get_ticks_usec();values.append((now-last)/1000.0);last=now
	var sum := 0.0
	for value in values: sum+=value
	values.sort()
	return {"frames":values.size(),"mean_ms":sum/values.size(),"fps":1000/(sum/values.size()),"p95_ms":values[int(values.size()*.95)],"p99_ms":values[int(values.size()*.99)],"draws_last":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func run() -> void:
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.forge.store.path.contains("weapons-test"),"Isolated construction save required")
	var weapons: Node=arena.weapons
	assert(weapons.initialized and weapons.models.size()==5 and is_instance_valid(weapons.arms))
	assert(arena.loading.brief.controls.contains("1 Carbine, 2 Railgun") and arena.loading.brief.controls.contains("R reload"))
	var title_found := false
	for label in arena.loading.root.find_children("*","Label",true,false):
		if label.text==arena.loading.brief.title: title_found=true
	assert(title_found,"Actual loading UI must show the revised title")
	await capture("weapons-loading-screen")
	assert(not weapons.available() and not weapons.view_active)
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	for i in 5: await physics_frame
	key(KEY_E);assert(arena.on_foot.active);arena.on_foot.test_controls=true
	await create_timer(.7).timeout
	assert(weapons.view_active and weapons.models[0].visible and not weapons.models[1].visible)
	await capture("weapons-carbine")
	var redraws: int=weapons.view_redraws
	for i in 15: await process_frame
	assert(weapons.view_redraws==redraws,"Idle viewmodel must reuse its rendered image")
	var shots: int=weapons.shots;trigger(true)
	for i in 2: await physics_frame
	trigger(false);assert(weapons.shots==shots+1 and weapons.ammo[0]==29)
	key(KEY_R);assert(weapons.reload_time>0)
	await create_timer(1.65).timeout;assert(weapons.ammo[0]==30)
	key(KEY_2);assert(weapons.selected==1 and weapons.models[1].visible)
	await create_timer(.2).timeout;await capture("weapons-railgun")
	shots=weapons.shots;trigger(true)
	for i in 2: await physics_frame
	trigger(false);assert(weapons.shots==shots+1 and weapons.ammo[1]==4)
	key(KEY_R);key(KEY_F1)
	await create_timer(.1).timeout
	assert(arena.editor.opened and not weapons.view_active and weapons.reload_time==0 and not weapons.fire())
	arena.editor.select_tool("forge");key(KEY_Q);assert(weapons.selected==1)
	key(KEY_F1);await create_timer(.1).timeout;assert(arena.on_foot.active and weapons.view_active)
	key(KEY_F2);await create_timer(.1).timeout
	assert(not arena.loading.dismissed and not weapons.view_active and not weapons.fire())
	arena.loading.close();await create_timer(.1).timeout
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;shots=weapons.shots;trigger(true)
	for i in 3: await physics_frame
	assert(weapons.shots==shots and not weapons.trigger_held);trigger(false)
	key(KEY_E);await create_timer(.1).timeout
	assert(arena.vehicle_kit.driving and not weapons.view_active and weapons.view.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	key(KEY_E);assert(arena.on_foot.active)
	await create_timer(.3).timeout
	key(KEY_1);weapons.ammo=[30,5,100,80,100]
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	weapons.presentation_enabled=false
	var baseline: Dictionary=await measure()
	weapons.presentation_enabled=true
	var idle: Dictionary=await measure()
	trigger(true);var firing: Dictionary=await measure();trigger(false)
	await create_timer(.25).timeout;key(KEY_2)
	var railgun: Dictionary=await measure()
	var report := {"result":"PASS","device":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"checks":["actual revised loading screen","both source weapon models and arms","idle viewport cache","LMB fire","reload","1/2 switching","construction input isolation","briefing gate","cursor recapture does not fire","vehicle return and holstered viewport disabled"],"performance":{"no_overlay":baseline,"carbine_idle":idle,"carbine_firing":firing,"railgun_idle":railgun},"notes":"240-frame stationary cases with 60 warm-up frames; same foot position. Short-run variability applies; no full-route FPS guarantee."}
	var file := FileAccess.open(output.path_join("weapons-validation.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WEAPONS_INTEGRATION_PASS ",JSON.stringify(report));quit()
