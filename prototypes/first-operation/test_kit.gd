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
	arena.walker.position=kit.vehicles[0].position+Vector3(4,0,0)
	kit.toggle_vehicle();assert(kit.driving!=null and arena.walker.collision_mask==0,"Vehicle entry failed")
	kit.toggle_vehicle();assert(kit.driving==null and arena.walker.collision_mask==1,"Safe exit failed")
	print("PASS: seven weapons/two vehicles/arms loaded; target hit; melee range limited; wall blocks shot; enter/exit restores player collision")
	quit()
