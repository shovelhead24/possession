extends SceneTree

# Lightweight behavior harness. It loads the real T-rex GLB and its animation
# player, but replaces vehicles, squads, terrain meshes, and plasma with small
# deterministic stand-ins.
class TestKit extends Node:
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
	assert(predator.animator.current_animation=="CINEMA_4D_Main","Unexpected T-rex animation")
	predator.take_hit(250,Vector3.ZERO,Vector3.ZERO)
	assert(predator.health==750 and "750" in predator.health_label.text,"Gunfire did not reduce the 1,000-HP T-rex health bar")
	arena.walker.global_position=predator.global_position+Vector3(0,0,40)
	var before=predator.global_position
	predator._physics_process(1.0)
	assert(predator.global_position.distance_to(before)>8.5,"T-rex did not approach its player target")
	arena.walker.global_position=predator.global_position+Vector3(0,0,2)
	predator.cooldown=0
	predator._physics_process(.01)
	assert(predator.bite_target==arena.walker,"T-rex did not start a player grab")
	var attack_origin=predator.global_position
	predator._physics_process(.40)
	assert(predator.global_position.distance_to(attack_origin)<.01 and range.hits.is_empty(),"T-rex moved or damaged before the bite midpoint")
	predator._physics_process(.20)
	assert(range.hits==["T-REX BITE"] and range.health>=20 and range.health<=80,"Midpoint grab did not apply 20-80 player damage")
	assert(arena.walker.global_position.distance_to(predator.mouth_point())<.01,"Grab did not clamp player to the mouth")
	predator._physics_process(.70)
	assert(predator.bite_target==null and range.hits.size()==1,"Grab did not release cleanly")
	assert(arena.last_toss.length()>0 and (arena.last_toss.y<=2.6 or arena.last_toss.y>=6),"Toss did not use the expected low-or-rare-high arc")
	assert(predator.target()==null,"T-rex immediately reacquired the tossed target")
	print("PASS: real T-rex animation, stationary timed grab, damage, and toss")
	root.remove_child(range);range.free();root.remove_child(arena);arena.free();quit()
