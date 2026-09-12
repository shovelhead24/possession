extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await physics_frame;await physics_frame
	var kit=arena.kit
	assert(kit.arms!=null and kit.names.size()==7 and kit.vehicles.size()==2,"Local asset import incomplete")
	var target: Node3D
	for child in arena.get_children():
		if child.has_meta("target_hits"): target=child;break
	arena.set_physics_process(false)
	arena.camera.position=target.position+Vector3(0,0,8);arena.camera.look_at(target.position)
	kit.use_weapon();assert(target.get_meta("target_hits")==1,"Gun failed to hit target")
	kit.select_weapon(kit.names.find("Blade"));kit.cooldown=0;kit.use_weapon();assert(target.get_meta("target_hits")==1,"Melee hit beyond short test reach")
	kit.select_weapon(0);kit.cooldown=0
	arena.solid(target.position+Vector3(0,0,4),Vector3(3,3,.5),arena.inactive)
	await physics_frame;await physics_frame
	kit.use_weapon();assert(target.get_meta("target_hits")==1,"Shot passed through wall")
	for i in range(60): await physics_frame
	for vehicle in kit.vehicles:
		arena.walker.position=vehicle.position+Vector3(4,0,0)
		kit.toggle_vehicle();assert(kit.driving!=null and arena.walker.collision_mask==0,"Vehicle entry failed")
		var start=kit.driving.position
		var forward=InputEventKey.new();forward.physical_keycode=KEY_W;forward.pressed=true;Input.parse_input_event(forward)
		for i in range(150): await physics_frame
		forward.pressed=false;Input.parse_input_event(forward)
		assert(kit.driving.position.distance_to(start)>5,"Vehicle cannot drive out of parking place")
		kit.toggle_vehicle();assert(kit.driving==null and arena.walker.collision_mask==1,"Safe exit failed")
	arena.set_physics_process(false)
	arena.camera.position=Vector3(0,2,-296.5);arena.use_station();assert(arena.state.connected(),"Relay needs repeated presses")
	var previous=int(target.get_meta("target_hits"))
	arena.camera.position=Vector3(4,2,-6);arena.use_station()
	assert(arena.strike_busy,"Strike did not start")
	await create_timer(2.5).timeout
	assert(not arena.strike_busy and int(target.get_meta("target_hits"))>previous,"Strike did not impact range")
	print("PASS: seven weapons/two vehicles/arms loaded; target hit; melee range limited; wall blocks shot; both vehicles travel over 5 m and exit safely; one-press relay; strike impacts")
	quit()
