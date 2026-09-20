extends SceneTree

class TestArena extends Node3D:
	var walker: CharacterBody3D
func height_at(_x: float,_z: float) -> float: return 0.0

class TestRange extends Node:
	var health := 1000
	var damage_taken := 0
func hurt(amount: int,_source: String="") -> void: damage_taken+=amount;health-=amount

func _init() -> void:
	var arena=TestArena.new()
	arena.walker=CharacterBody3D.new()
	arena.add_child(arena.walker)
	root.add_child(arena)
	var range=TestRange.new();root.add_child(range)
	var predator=preload("res://trex.gd").new()
	predator.arena=arena;predator.manager=range
	# This is the same player body used in the arena. Run the timed bite frame,
	# rather than calling the damage helper directly, to test the live path.
	predator.begin_bite(arena.walker)
	predator._physics_process(.2)
	assert(range.damage_taken==140,"T-rex bite did not damage the player body")
	print("PASS: player body receives one 140-point T-rex bite")
	quit()
