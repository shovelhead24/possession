extends SceneTree
func _initialize(): call_deferred("run")
func report(manager: Node,tag: String):
	for unit in manager.enemies.slice(0,5):
		var min_y=INF;var rig=unit.lizard.skeleton
		for i in rig.get_bone_count(): min_y=minf(min_y,rig.to_global(rig.get_bone_global_pose(i).origin).y)
		print("SPAWN ",tag," p=",unit.global_position," terrain=",manager.arena.height_at(unit.position.x,unit.position.z)," lowest_bone=",min_y," velocity=",unit.velocity," floor=",unit.is_on_floor())
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	var manager=arena.get_node("PracticeRange");manager.health=100000
	report(manager,"ready")
	for i in 90:
		await physics_frame
		if i in [0,3,15,60,89]: report(manager,str(i))
	quit()
