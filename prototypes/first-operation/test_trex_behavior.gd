extends SceneTree

# Lightweight behavior harness. It loads the real T-rex GLB and its animation
# player, but replaces vehicles, squads, terrain meshes, and plasma with small
# deterministic stand-ins.
class TestKit extends Node:
	var driving: Node3D
	func imported(path: String) -> Node3D:
		var doc=GLTFDocument.new();var state=GLTFState.new()
		assert(doc.append_from_file(path,state)==OK,"Could not load the real T-rex GLB")
		return doc.generate_scene(state) as Node3D
	func bounds(root: Node3D) -> AABB:
		var result=AABB();var found=false;var stack: Array=[[root,Transform3D.IDENTITY]]
		while not stack.is_empty():
			var entry: Array=stack.pop_back();var node: Node=entry[0];var transform: Transform3D=entry[1]
			if node is Node3D: transform=transform*node.transform
			if node is MeshInstance3D and node.mesh:
				var box: AABB=transform*node.mesh.get_aabb();result=result.merge(box) if found else box;found=true
			for child in node.get_children(): stack.append([child,transform])
		return result

class TestArena extends Node3D:
	var walker: CharacterBody3D
	var kit: TestKit
	var last_toss := Vector3.ZERO
	func height_at(_x: float,_z: float) -> float: return 0.0
	func toss_player(impulse: Vector3) -> void: last_toss=impulse

class TestRange extends Node:
	var health := 100
	var enemies: Array=[]
	var hits: Array[String]=[]
	func hurt(amount: int,source: String="PLASMA") -> void:
		hits.append(source);health-=amount

func _init() -> void: call_deferred("run")

func run() -> void:
	var arena=TestArena.new();arena.kit=TestKit.new();arena.add_child(arena.kit);root.add_child(arena)
	arena.walker=CharacterBody3D.new();arena.walker.name="Player";arena.add_child(arena.walker)
	var player_shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.34;capsule.height=1.8;player_shape.shape=capsule;player_shape.position.y=.9;arena.walker.add_child(player_shape)
	var range=TestRange.new();root.add_child(range)
	var predator=preload("res://trex.gd").new();predator.arena=arena;predator.manager=range;arena.add_child(predator)
	predator.set_physics_process(false)
	assert(predator.animator!=null and predator.animator.is_playing(),"Real T-rex animation did not start")
	assert(predator.animator.current_animation==predator.WALK_CLIP,"Live movement must use the same walk as manual control")
	assert(not predator.locomotion_profile.is_empty(),"Missing authored motion profile")
	assert(is_equal_approx(predator.animator.speed_scale,1.0),"Walk should be 25% faster than the old .8 rate")
	assert(predator.locomotion_weight(0.0)==0.0,"Opening planted pose should be stationary")
	assert(predator.locomotion_weight(11.0)>.95,"Late walking section should travel at full speed")
	for frame in range(420):
		var weight=predator.locomotion_weight(frame/30.0)
		assert(is_finite(weight) and weight>=0.0 and weight<=1.0,"Invalid motion envelope")
	predator.take_hit(250,Vector3.ZERO,Vector3.ZERO)
	assert(predator.health==3750 and "3750" in predator.health_label.text,"Gunfire did not reduce the 4,000-HP T-rex health bar")
	# The predator has a deliberate forward sensing cone; put the target ahead,
	# rather than behind its initial facing.
	arena.walker.global_position=predator.global_position+Vector3(0,0,-40)
	var before=predator.global_position
	var heading=predator.rotation.y
	predator.animator.seek(0.0,true)
	predator._physics_process(1.0)
	assert(predator.global_position.distance_to(before)>8.5,"T-rex did not approach its player target")
	var mouth=predator.mouth_point();arena.walker.global_position=Vector3(mouth.x,0,mouth.z)
	predator.cooldown=0
	predator._physics_process(.01)
	assert(predator.bite_target==arena.walker,"T-rex did not start a player grab")
	var attack_origin=predator.global_position
	predator._physics_process(.40)
	assert(predator.global_position.distance_to(attack_origin)<.01 and range.hits.is_empty(),"T-rex moved or damaged before the bite midpoint")
	predator._physics_process(.20)
	assert(range.hits==["T-REX BITE"] and range.health>=20 and range.health<=80,"Midpoint grab did not apply 20-80 player damage")
	assert((arena.walker.global_position+predator.grip_offset).distance_to(predator.mouth_point())<.01,"Grab did not clamp player's body centre to the mouth")
	predator._physics_process(.70)
	assert(predator.bite_target==null and range.hits.size()==1,"Grab did not release cleanly")
	assert(arena.last_toss.y==14.0,"First toss should launch upward")
	assert(predator.target()==null,"T-rex immediately reacquired the tossed target")
	predator._physics_process(.5) # Finish the new throw follow-through before patrol checks.
	# The full source remains a stationary preview, never the live walk loop.
	arena.walker.position=Vector3(10000,0,10000)
	predator.cached_prey=null
	var planted_frames=0
	var clip=predator.animator.get_animation("CINEMA_4D_Main")
	predator.set_preview(1)
	for frame in range(ceili(clip.length*30.0)):
		var phase=frame/30.0
		predator.animator.seek(phase,true)
		assert(predator.skeleton.get_bone_pose_position(predator.root_bone).length()<.001,"Animated root translation returned")
		if predator.locomotion_weight(phase)>0.0: continue
		planted_frames+=1
		before=predator.global_position;heading=predator.rotation.y
		predator._physics_process(1.0/60.0)
		assert(predator.global_position.distance_to(before)<.001 and predator.rotation.y==heading,"A planted section slid or pivoted")
		assert(predator.animator.speed_scale>0.0,"Planted animation deadlocked")
	assert(planted_frames>30,"Expected stationary sections across the imported take")
	print("Checked %d planted samples across %.2f seconds" % [planted_frames,clip.length])
	predator.set_preview(0)
	var walk=predator.animator.get_animation(predator.WALK_CLIP)
	assert(is_equal_approx(walk.length,101.0/30.0),"Wrong shortened stride length")
	for track in walk.get_track_count():
		var first=walk.track_get_key_value(track,0)
		var last=walk.track_get_key_value(track,walk.track_get_key_count(track)-1)
		assert(first.is_equal_approx(last),"Walk seam must return every bone to its own phase")
	# Identical requested direction must produce identical AI/manual motion.
	predator.position=Vector3(0,.05,0);predator.rotation=Vector3.ZERO
	predator.behavior_mode=1;predator.waypoint=0;predator.patrol=[Vector3(40,0,-40)];predator.path.clear()
	predator._physics_process(.1)
	var ai_position=predator.position;var ai_heading=predator.rotation.y
	predator.position=Vector3(0,.05,0);predator.rotation=Vector3.ZERO
	predator.behavior_mode=4;predator.manual_move=Vector3(1,0,-1).normalized()
	predator._physics_process(.1)
	assert(predator.position.is_equal_approx(ai_position) and is_equal_approx(predator.rotation.y,ai_heading),"AI/manual motors diverged")
	predator.behavior_mode=0;predator.clear_pending=0
	assert(not predator.update_clear_emote(3.0),"Quiet patrol alone must never trigger an emote")
	predator.clear_pending=8;predator.emote_cooldown=0
	assert(predator.update_clear_emote(2.1),"Confirmed kill plus clear front should allow the emote")
	assert(predator.animator.current_animation==predator.EMOTE_CLIP,"Wrong contextual animation")
	assert(not predator.update_clear_emote(2.0),"Emote must complete once")
	predator.clear_pending=8
	assert(not predator.update_clear_emote(2.1),"Repeated emote ignored its cooldown")
	predator.emote_cooldown=0;predator.clear_quiet=0;predator.clear_pending=8
	arena.walker.global_position=predator.global_position-predator.global_basis.z*20
	# This synchronous harness teleported Rexy without running its render update.
	predator.vision_frame=Transform3D(predator.global_basis,predator.global_position+Vector3.UP*4)
	predator.excluded_target=arena.walker
	assert(not predator.update_clear_emote(2.1),"A living tossed/excluded target must still block celebration")
	print("PASS: shortened seamless stride, identical AI/manual motor, contextual emotes, preview motion lock, timed grab, damage and toss")
	root.remove_child(range);range.free();root.remove_child(arena);arena.free();quit()
