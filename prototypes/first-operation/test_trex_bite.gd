extends SceneTree

# Isolated bite harness: no terrain, AI squads, vehicles, animation asset, or
# plasma projectiles. It exercises the same timed T-rex/player damage route
# that runs in the tactical arena.
class TestArena extends Node3D:
	var walker: CharacterBody3D
	var kit: TestKit
	func height_at(_x: float,_z: float) -> float: return 0.0

class TestKit extends Node:
	var driving: Node3D
	func imported(_path: String) -> Node3D: return Node3D.new()
	func bounds(_root: Node3D) -> AABB: return AABB(Vector3.ZERO,Vector3.ONE)

class TestRange extends Node:
	var health := 100
	var enemies: Array=[]
	var hits: Array[String]=[]
	func hurt(amount: int,source: String="PLASMA") -> void:
		hits.append("%s:%d" % [source,amount]);health-=amount

func _init() -> void: call_deferred("run")

func run() -> void:
	var arena=TestArena.new();root.add_child(arena)
	arena.kit=TestKit.new();arena.add_child(arena.kit)
	arena.walker=CharacterBody3D.new();arena.walker.name="Player";arena.add_child(arena.walker)
	var player_shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.34;capsule.height=1.8;player_shape.shape=capsule;player_shape.position.y=.9;arena.walker.add_child(player_shape)
	var range=TestRange.new();root.add_child(range)
	var predator=preload("res://trex.gd").new();predator.arena=arena;predator.manager=range
	# It needs to be in the scene tree for global transforms and the timed toss
	# cleanup.  The lightweight kit lets its normal _ready path complete.
	arena.add_child(predator)
	await process_frame
	# This unit test intentionally avoids loading the imported model; give it a
	# fixed damage roll and exercise only the timed gameplay route.
	predator.bite_debug=MeshInstance3D.new();predator.add_child(predator.bite_debug)
	predator.begin_bite(arena.walker);predator.bite_damage=60.0
	predator._physics_process(.59)
	assert(range.hits.is_empty(),"Bite damaged before its grab frame")
	predator._physics_process(.02)
	assert(range.hits==["T-REX BITE:60"],"Bite did not use the player damage route exactly once")
	assert(range.health==40,"Bite damage was not applied to player health")
	predator._physics_process(.70)
	assert(range.hits.size()==1,"Bite damaged more than once during one grab")
	assert(predator.bite_target==null,"Bite did not release its target")
	print("PASS: isolated T-rex grab hits Player once for fixed 60 damage and releases")
	root.remove_child(range);range.free();root.remove_child(arena);arena.free()
	quit()
