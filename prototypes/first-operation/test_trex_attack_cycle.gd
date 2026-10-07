extends "res://test_trex_grip_settle.gd"

func run() -> void:
	var arena=SlopeArena.new();arena.kit=TestKit.new();arena.add_child(arena.kit);root.add_child(arena)
	arena.walker=CharacterBody3D.new();arena.add_child(arena.walker)
	var shape=CollisionShape3D.new();shape.shape=CapsuleShape3D.new();shape.position.y=.9;arena.walker.add_child(shape)
	var manager=TestRange.new();root.add_child(manager)
	var predator=preload("res://trex.gd").new();predator.arena=arena;predator.manager=manager;arena.add_child(predator)
	predator.set_physics_process(false);predator.set_process(false)
	var solver=predator.grounding
	var peak_stomp=0.0
	for attack in 5:
		manager.health=100;manager.hits.clear();arena.last_toss=Vector3.ZERO
		predator.skeleton.reset_bone_poses()
		predator.animator.seek(1.6,true);solver._process_modification() # Source frame 360 in the trimmed walk.
		predator.begin_bite(arena.walker)
		assert(predator.attack_kind==attack%4,"Attack order not up/left/right/finisher")
		for frame in range(245 if attack==3 else 75):
			predator.skeleton.reset_bone_poses()
			predator.animator.seek(1.6,true)
			predator._physics_process(1.0/60.0)
			solver._process_modification()
			if predator.bite_grabbed:
				assert((arena.walker.global_position+predator.grip_offset).distance_to(predator.mouth_point())<.001,"Victim detached before throw")
			if attack==3: peak_stomp=maxf(peak_stomp,predator.stomp_lift())
		if attack%4==0: assert(arena.last_toss.y==14 and absf(arena.last_toss.x)<.01,"Up animation/impulse mismatch")
		elif attack==1: assert(arena.last_toss.x< -15 and arena.last_toss.y==3,"Left animation/impulse mismatch")
		elif attack==2: assert(arena.last_toss.x>15 and arena.last_toss.y==3,"Right animation/impulse mismatch")
		else:
			assert(predator.slam_started and predator.stomp_applied and predator.consumed,"Finisher skipped a stage")
			assert(peak_stomp>1.5 and predator.sounds.events.stomp==1,"Missing or duplicate stomp")
			assert("T-REX EATEN" in manager.hits and manager.health<0,"Player was not consumed")
		assert(not arena.walker.has_meta("trex_held"),"Player controls remained locked")
		print("ATTACK_PASS index=",attack+1," kind=",attack%4," impulse=",arena.last_toss)
	print("PASS: ordered up/left/right/slam-stomp-eat/wrap; animated mouth hold, directional impulses, single stomp, player death and controls restored")
	if "--preview-cycle" in OS.get_cmdline_user_args():
		arena.gradient=Vector2.ZERO;predator.position=Vector3(0,.05,0);predator.sight.hide()
		var mesh=MeshInstance3D.new();var capsule=CapsuleMesh.new();capsule.radius=.3;capsule.height=1.8;mesh.mesh=capsule;mesh.position.y=.9
		var material=StandardMaterial3D.new();material.albedo_color=Color(1,.4,.05);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material;arena.walker.add_child(mesh)
		var floor_mesh=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();arena.add_child(floor_mesh);floor_mesh.scale=Vector3.ONE*30
		var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=2;arena.add_child(light)
		var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;arena.add_child(environment)
		var camera=Camera3D.new();arena.add_child(camera);camera.position=Vector3(12,9,-11);camera.look_at(Vector3(0,4,1));camera.current=true
		for pose in [[0,1.18,"up"],[1,1.18,"left"],[2,1.18,"right"],[3,1.65,"stomp_lift"],[3,2.1,"stomp"],[3,2.95,"eat"]]:
			predator.release_hold();predator.bite_number=pose[0]
			predator.skeleton.reset_bone_poses()
			predator.animator.seek(1.6,true);predator.animator.speed_scale=0;solver.settle_weight=1.0
			predator.begin_bite(arena.walker);predator.bite_grabbed=true;predator.bite_applied=true;predator.bite_debug.hide()
			predator.bite_time=predator.attack_duration-pose[1]
			if pose[0]==3:
				predator.slam_started=true;predator.bite_grabbed=false;predator.slam_origin=predator.mouth_point()
			for tick in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Games/possession/logs/trex_cycle_"+pose[2]+".png")
	arena.free();manager.free();quit()
