extends "res://test_trex_behavior.gd"

class SlopeArena extends TestArena:
	var gradient := Vector2.ZERO
	var crest := false
	func height_at(x: float,z: float) -> float:
		return gradient.dot(Vector2(x,z))+(2.0*cos(z*.18) if crest else 0.0)

func run() -> void:
	var arena=SlopeArena.new();arena.kit=TestKit.new();arena.add_child(arena.kit);root.add_child(arena)
	arena.walker=CharacterBody3D.new();arena.walker.position=Vector3(10000,0,10000);arena.add_child(arena.walker)
	var manager=TestRange.new();root.add_child(manager)
	var predator=preload("res://trex.gd").new();predator.arena=arena;predator.manager=manager;arena.add_child(predator)
	predator.set_physics_process(false);predator.set_process(false)
	predator.animator.play("CINEMA_4D_Main") # Exercise the full source range, not trimmed-clip seconds.
	var rig: Skeleton3D=predator.skeleton
	var solver=predator.grounding
	var worst_error=0.0;var minimum_head=INF;var checks=0
	for gradient in [Vector2.ZERO,Vector2(0,-.7),Vector2(0,.7),Vector2(.7,0),Vector2(-.7,0),Vector2(0,-1)]:
		arena.gradient=gradient
		for crest in [false,true]:
			arena.crest=crest
			predator.position=Vector3(0,arena.height_at(0,0)+.05,0)
			for frame in range(0,420,3):
				predator.animator.seek(frame/30.0,true)
				var lengths: Array[float]=[]
				for leg in solver.legs:
					for link in [[leg[2],leg[1]],[leg[1],leg[0]],[leg[0],leg[3]]]:
						lengths.append(solver.bone_world(rig,link[0]).distance_to(solver.bone_world(rig,link[1])))
				solver._process_modification()
				for side in 2:
					var error=solver.last_feet[side].distance_to(solver.last_targets[side])
					worst_error=maxf(worst_error,error)
					assert(error<.12,"Foot missed slope: %s phase %.2f error %.3f" % [gradient,frame/30.0,error])
				var index=0
				for leg in solver.legs:
					for link in [[leg[2],leg[1]],[leg[1],leg[0]],[leg[0],leg[3]]]:
						var length=solver.bone_world(rig,link[0]).distance_to(solver.bone_world(rig,link[1]))
						assert(absf(length-lengths[index])<.002,"Leg segment stretched")
						index+=1
				var clearance=solver.last_head.y-arena.height_at(solver.last_head.x,solver.last_head.z)
				minimum_head=minf(minimum_head,clearance)
				assert(clearance>1.0,"Head intersected slope")
				checks+=1
	print("PASS: %d slope/animation combinations; worst foot error %.3fm, minimum head clearance %.3fm; leg lengths preserved" % [checks,worst_error,minimum_head])
	if "--capture" in OS.get_cmdline_user_args():
		arena.gradient=Vector2(0,-.7);arena.crest=false
		predator.position=Vector3(0,.05,0);predator.animator.seek(11.6,true);predator.animator.pause()
		var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(70,70);floor_mesh.mesh=plane
		floor_mesh.rotation.x=atan(.7);arena.add_child(floor_mesh)
		var material=StandardMaterial3D.new();material.albedo_color=Color(.24,.3,.21);floor_mesh.material_override=material
		var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=2.0;arena.add_child(light)
		var camera=Camera3D.new();arena.add_child(camera);camera.position=Vector3(24,17,-21);camera.look_at(Vector3(0,4,4));camera.current=true
		var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.12,.15,.2);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;arena.add_child(environment)
		for tick in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(solver.has_pose,"Grounding modifier did not run in the live scene")
		root.get_texture().get_image().save_png("C:/Games/possession/logs/trex_ground_slope.png")
		print("PASS: live modifier and slope render")
	arena.free();manager.free();quit()
