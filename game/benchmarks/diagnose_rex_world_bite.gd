extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var rows=[]
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/work"
func _initialize():
	create_timer(240).timeout.connect(func():push_error("Live encounter timeout");quit(1))
	run.call_deferred()
func run():
	seed(47);Engine.max_fps=120
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();var manager=arena.aliens;manager.health=10000
	arena.vehicle_kit.car.freeze=true;arena.diagnostic=true
	var cam=Vector3(218.21138,-13.956993,364.6452)
	arena.on_foot.activate_at(cam-Ring.up_at(cam)*1.6);arena.on_foot.set_physics_process(false);arena.on_foot.set_process(false)
	arena.camera.position=cam;arena.camera.rotation=Vector3(.03777293,.3508586,.00042947)
	await create_timer(1).timeout
	var actor=manager.trex;actor.set_physics_process(false);var original=actor.global_transform
	var trunks=get_nodes_in_group("trex_passable_tree")
	trunks.sort_custom(func(a,b):return a.global_position.distance_squared_to(Vector3(196.62,-14.665,319.44))<b.global_position.distance_squared_to(Vector3(196.62,-14.665,319.44)))
	var proven=false
	for trunk in trunks.slice(0,20):
		var basis=Ring.tangent_basis(trunk.global_position,0)
		actor.global_transform=Transform3D(basis,trunk.global_position-basis.z*4)
		actor.remove_collision_exception_with(trunk)
		var collision=KinematicCollision3D.new()
		var before=actor.test_move(actor.global_transform,basis.z*.9,collision)
		var was_tree=before and collision.get_collider()==trunk
		actor.add_collision_exception_with(trunk)
		var after=actor.test_move(actor.global_transform,basis.z*.9)
		if was_tree and not after:
			print("REX_TREE_AB_PASS original_restore_blocks=",trunk.get_path()," fixed_passes=true trunk_layer=",trunk.collision_layer)
			assert(trunk.collision_layer==2,"Other actors retain trunk collision")
			proven=true;break
	assert(proven,"Must reproduce a real trunk blocker and confirm Rex-only fix")
	actor.global_transform=original;actor.reset_physics_interpolation();actor.set_physics_process(true)
	for i in 300:
		await create_timer(.2).timeout
		var rex=manager.trex
		if not is_instance_valid(rex): break
		var prey=rex.cached_prey
		var row={"t":i*.2,"position":str(rex.position),"mouth":str(rex.mouth_point()),"bite":rex.bite_time,"recovery":rex.attack_recovery,"bite_number":rex.bite_number,"active":rex.runtime_active,"resident":manager.resident(rex.position),"paused":manager.paused(),"speed":rex.animator.speed_scale,"clip":str(rex.animator.current_animation),"frame":rex.animator.current_animation_position,"blocker":rex.last_blocker,"movement_blocked":rex.movement_blocked,"target":str(prey.get_path()) if is_instance_valid(prey) else "none","distance":rex.position.distance_to(prey.global_position) if is_instance_valid(prey) else -1,"mouth_distance":(rex.mouth_point()-prey.global_position).slide(Ring.up_at(rex.position)).length() if is_instance_valid(prey) else -1}
		rows.append(row)
		if i%25==0: print("REX_LIVE_STATE ",JSON.stringify(row))
		if i in [75,175,275]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("rex-fixed-%d.png" % i))
	var file=FileAccess.open(output.path_join("rex-live-world-fixed.json"),FileAccess.WRITE);file.store_string(JSON.stringify(rows));file.close()
	print("REX_LIVE_DIAGNOSTIC_DONE")
	arena.free();quit()
