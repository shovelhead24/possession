extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	var manager=arena.get_node("PracticeRange");manager.health=100000
	for actor in manager.tyrants: assert(actor.health==4000 and actor.waypoint==1)
	var initial: Dictionary={}
	for unit in manager.enemies:
		for other in manager.enemies:
			if unit!=other: assert(Vector2(unit.position.x-other.position.x,unit.position.z-other.position.z).length()>2,"Overlapping alien spawn")
		initial[unit.get_instance_id()]=unit.position
	var worst_spawn_height=0.0
	for second in 480:
		await create_timer(1.0).timeout
		if second<8:
			for unit in manager.enemies:
				if initial.has(unit.get_instance_id()) and not unit.has_meta("trex_held") and unit.trex_toss_time<=0:
					worst_spawn_height=maxf(worst_spawn_height,unit.position.y-arena.height_at(unit.position.x,unit.position.z))
		var hits=0;var states=[]
		for actor in manager.tyrants:
			if is_instance_valid(actor): hits+=actor.rival_hits_given;states.append([actor.name,actor.position,actor.health,actor.waypoint,actor.rival_hits_given])
		if second%10==0: print("RENDEZVOUS ",second+1," ",states)
		if hits>=4:
			assert(second>=100,"Encounter still too early")
			assert(worst_spawn_height<4,"Alien spawn caused a launch above normal hop height")
			print("PASS: autonomous Tyrant encounter with aliens active at ",second+1,"s; rival hits=",hits,"; max initial alien ground gap=",worst_spawn_height)
			quit();return
	assert(false,"No autonomous Tyrant fight within eight minutes")
	quit(1)
