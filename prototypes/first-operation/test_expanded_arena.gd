extends SceneTree
const Data=preload("res://arena_bake_data.gd")
func _initialize(): call_deferred("run")
func run():
	var data=load(Data.FILE)
	assert(data.heights.size()==Data.WIDTH*Data.DEPTH)
	assert(data.sector_counts.size()==16 and data.homes.size()==62)
	var guarded=0
	for home in data.homes:
		if home.distance_to(Vector3(0,0,-307))<55: guarded+=1
	assert(guarded>=6,"Enemy relay not reinforced")
	for i in 4: assert(Data.patrol_route(i).size()>=16,"Rex route does not cover all sectors")
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await process_frame
	var manager=arena.get_node("PracticeRange")
	assert(manager.tyrants.size()==4 and get_nodes_in_group("tyrants").size()==4,"Must spawn exactly four Tyrants")
	assert(arena.get_node("TacticalGround").get_child_count()==16)
	assert(manager.garrisons.size()==62 and manager.enemies.size()<150,"Squad streaming failed")
	var path=manager.navigation.path(Vector3(0,0,-100),Vector3(1050,0,-2200),true)
	assert(not path.is_empty() and path[-1].distance_to(Vector3(1050,arena.height_at(1050,-2200),-2200))<30,"Navigation still constrained to old arena")
	assert(not arena.rex_menu.indicators_visible and not arena.rex_menu.hud_visible and not arena.rex_menu.damage_visible)
	for label in get_nodes_in_group("optional_hud_text"): assert(not label.visible)
	for label in get_nodes_in_group("enemy_damage_text"): assert(not label.visible)
	var a=manager.tyrants[0];var b=manager.tyrants[1]
	assert(a.animator.get_animation_library("")!=b.animator.get_animation_library(""),"Rex animation libraries are shared mutable state")
	for actor in manager.tyrants: actor.set_physics_process(false)
	a.position=Vector3(500,arena.height_at(500,-700),-700);b.position=a.position+Vector3(0,0,-10)
	a.begin_bite(b);b.begin_bite(a)
	assert(not a.has_meta("trex_held") and not b.has_meta("trex_held"),"Tyrants must not grab/toss one another")
	a._physics_process(.6);b._physics_process(.6)
	assert(a.health==3855 and b.health==3855,"Tyrants did not damage each other")
	var count=manager.enemies.size()
	arena.walker.position=Vector3(0,0,-300);manager.stream_squads()
	var live_guards=0
	for entry in manager.garrisons:
		if entry.home.distance_to(Vector3(0,0,-307))<55 and is_instance_valid(entry.squad): live_guards+=entry.squad.members.size()
	assert(live_guards>=30,"Relay should have at least thirty defenders when approached")
	print("PASS: sixteen disk-baked sectors, broad navigation, 62 persistent squad placements, ",live_guards," relay guards, four independent map-wide patrols, mutual Tyrant damage, clean HUD; initial active enemies=",count)
	quit()
