extends SceneTree

# Isolated bite harness: no terrain, AI squads, vehicles, animation asset, or
# plasma projectiles. It exercises the same timed T-rex/player damage route
# that runs in the tactical arena.
class TestArena extends Node3D:
	var walker: CharacterBody3D
	func height_at(_x: float,_z: float) -> float: return 0.0

class TestRange extends Node:
	var health := 100
	var hits: Array[String]=[]
	func hurt(amount: int,source: String="PLASMA") -> void:
		hits.append("%s:%d" % [source,amount]);health-=amount

func _init() -> void:
	var arena=TestArena.new();root.add_child(arena)
	arena.walker=CharacterBody3D.new();arena.walker.name="Player";arena.add_child(arena.walker)
	var player_shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.34;capsule.height=1.8;player_shape.shape=capsule;player_shape.position.y=.9;arena.walker.add_child(player_shape)
	var range=TestRange.new();root.add_child(range)
	var predator=preload("res://trex.gd").new();predator.arena=arena;predator.manager=range
	predator.begin_bite(arena.walker)
	predator._physics_process(.10)
	assert(range.hits.is_empty(),"Bite damaged before its grab frame")
	predator._physics_process(.09)
	assert(range.hits==["T-REX BITE:140"],"Bite did not use the player damage route exactly once")
	assert(range.health==-40,"Bite damage amount was not lethal")
	predator._physics_process(.40)
	assert(range.hits.size()==1,"Bite damaged more than once during one grab")
	assert(predator.bite_target==null,"Bite did not release its target")
	print("PASS: isolated T-rex grab hits Player once for 140 damage and releases")
	predator.free();root.remove_child(range);range.free();root.remove_child(arena);arena.free()
	quit()
