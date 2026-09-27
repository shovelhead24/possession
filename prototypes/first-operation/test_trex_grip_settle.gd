extends "res://test_trex_grounding.gd"

class FakeLizard extends Node3D:
	var ragdoll: Node
	var dying := false
	func die(_velocity: Vector3=Vector3.ZERO,_impulse: Vector3=Vector3.ZERO): dying=true
	func toss(_velocity: Vector3,_impulse: Vector3,_source: Node): dying=true
class FakeSquad extends Node:
	func report_contact(_point: Vector3): pass
	func issue_orders(): pass
class AlienManager extends TestRange:
	var active := false
class HeldAlien extends "res://squad_enemy.gd":
	func _ready():
		shape=CollisionShape3D.new();shape.shape=CapsuleShape3D.new();shape.position.y=.9;add_child(shape)
		label=Label3D.new();add_child(label)
		lizard=FakeLizard.new();add_child(lizard)
		squad=FakeSquad.new();add_child(squad)
		set_physics_process(false)

func run() -> void:
	var arena=SlopeArena.new();arena.kit=TestKit.new();arena.add_child(arena.kit);root.add_child(arena)
	arena.walker=CharacterBody3D.new();arena.add_child(arena.walker)
	var shape=CollisionShape3D.new();shape.shape=CapsuleShape3D.new();shape.position.y=.9;arena.walker.add_child(shape)
	var manager=TestRange.new();root.add_child(manager)
	var predator=preload("res://trex.gd").new();predator.arena=arena;predator.manager=manager;arena.add_child(predator)
	predator.set_physics_process(false);predator.set_process(false)
	predator.animator.play("CINEMA_4D_Main") # Deliberately sample every original rest/stride pose.
	var solver=predator.grounding;var worst=0.0
	for gradient in [Vector2.ZERO,Vector2(0,-.7),Vector2(.7,0)]:
		arena.gradient=gradient;predator.position=Vector3(0,.05,0)
		for phase in range(0,420,3):
			predator.animator.seek(phase/30.0,true);solver.settle_weight=1.0;solver._process_modification()
			for side in 2:
				var error=solver.last_feet[side].distance_to(solver.last_targets[side]);worst=maxf(worst,error)
				assert(error<.14,"Settling foot could not reach ground: %.2f phase %.2f" % [error,phase/30.0])
				var p=solver.last_targets[side];var normal=solver.surface_normal(p)
				assert(absf((p.y-arena.height_at(p.x,p.z))*normal.y-.66)<.001,"Stopped foot remained lifted")
	# Both a character and a rigid object follow the mouth through changing
	# animation poses; release restores controls/collision and starts at jaws.
	for victim in [arena.walker,RigidBody3D.new()]:
		if not victim.is_inside_tree(): arena.add_child(victim)
		victim.position=predator.mouth_point();var layer=victim.collision_layer;var mask=victim.collision_mask
		predator.begin_bite(victim);predator.bite_grabbed=true
		for phase in [0.0,3.0,8.0,12.0]:
			predator.animator.seek(phase,true);solver._process_modification()
			assert((victim.global_position+predator.grip_offset).distance_to(solver.last_mouth)<.001,"Victim left animated mouth")
		predator.toss(victim)
		assert(not victim.has_meta("trex_held") and victim.collision_layer==layer and victim.collision_mask==mask,"Hold did not restore victim")
		if victim is RigidBody3D: assert(not victim.freeze and victim.linear_velocity.length()>5,"Object did not launch")
		predator.bite_target=null;predator.bite_grabbed=false
	assert(predator.sounds.feet[0].volume_db==1.0,"Footsteps did not get louder")
	var alien=HeldAlien.new();var alien_manager=AlienManager.new();arena.add_child(alien_manager);alien.manager=alien_manager;arena.add_child(alien)
	alien.health=20;predator.begin_bite(alien);predator.bite_grabbed=true;predator.bite_damage=30
	predator.clamp_to_mouth(alien);predator.apply_bite(alien)
	assert(alien.dead and not alien.lizard.dying,"Alien ragdolled before leaving mouth")
	predator.animator.seek(3.0,true);solver._process_modification()
	assert((alien.global_position+predator.grip_offset).distance_to(solver.last_mouth)<.001,"Dead alien left mouth")
	predator.toss(alien)
	assert(alien.lizard.dying and alien.collision_layer==0,"Dead alien did not ragdoll on release")
	predator.bite_target=null;predator.bite_grabbed=false
	# Verify the transition is gradual, not a single-frame foot snap.
	solver.settle_weight=0;predator.motion_previous=predator.position
	predator.update_settle(.1);assert(solver.settle_weight>0 and solver.settle_weight<1)
	predator.update_settle(.3);assert(solver.settle_weight==1)
	print("PASS: settled feet across 420 slope/pose combinations; max error=",worst,"; character/object mouth tracking and release; louder footsteps")
	if "--preview-grip" in OS.get_cmdline_user_args():
		arena.gradient=Vector2.ZERO;predator.position=Vector3(0,.05,0)
		predator.animator.seek(12.0,true);predator.animator.speed_scale=0;solver.settle_weight=1.0
		predator.begin_bite(arena.walker);predator.bite_grabbed=true
		predator.bite_debug.hide();predator.sight.hide()
		var mesh=MeshInstance3D.new();var capsule=CapsuleMesh.new();capsule.radius=.3;capsule.height=1.8;mesh.mesh=capsule;mesh.position.y=.9
		var material=StandardMaterial3D.new();material.albedo_color=Color(1,.4,.05);mesh.material_override=material;arena.walker.add_child(mesh)
		var floor_mesh=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();arena.add_child(floor_mesh);floor_mesh.scale=Vector3.ONE*30
		var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=2;arena.add_child(light)
		var camera=Camera3D.new();arena.add_child(camera);camera.position=Vector3(12,7,-6);camera.look_at(Vector3(0,3,1));camera.current=true
		for tick in 8: await process_frame
		await RenderingServer.frame_post_draw
		print("GRIP_RENDER mouth=",solver.last_mouth," victim=",arena.walker.global_position," feet=",solver.last_feet)
		root.get_texture().get_image().save_png("C:/Games/possession/logs/trex_grip_preview.png")
	arena.free();manager.free();quit()
