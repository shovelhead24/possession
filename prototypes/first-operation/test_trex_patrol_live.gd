extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await process_frame
	var predator=find_predator(arena)
	assert(predator!=null,"No Tyrant in shortcut scene")
	# First isolate patrol from combat, retaining the actual arena collisions.
	arena.walker.position=Vector3(10000,0,10000);arena.set_physics_process(false)
	for enemy in predator.manager.enemies: enemy.dead=true;enemy.set_physics_process(false)
	var origin=predator.position
	var visited: Dictionary={}
	for sample in 60:
		await create_timer(2.0).timeout
		visited[predator.waypoint]=true
		assert(predator.animator.current_animation==predator.WALK_CLIP,"Patrol entered an emote without a kill")
		print("PATROL t=",(sample+1)*2," pos=",predator.position," distance=",predator.position.distance_to(origin)," waypoint=",predator.waypoint," path=",predator.path.size()," source_frame=",predator.diagnostic_frame()," blocker=",predator.last_blocker)
	assert(predator.position.distance_to(origin)>100,"Tyrant remained in spawn area")
	assert(visited.size()>=2,"Tyrant did not advance patrol legs")
	assert((-predator.sight.global_basis.z).dot(-predator.global_basis.z)>.999,"Visible cone does not match detection heading")
	print("PASS: live tactical patrol leaves spawn and advances route; cone matches sensing")
	quit()

func find_predator(node: Node) -> Node:
	if node.get_script()==preload("res://trex.gd"): return node
	for child in node.get_children():
		var result=find_predator(child)
		if result: return result
	return null
