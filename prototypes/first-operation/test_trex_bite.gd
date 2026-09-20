extends SceneTree

class TestArena extends Node3D:
	var walker: CharacterBody3D
func height_at(_x: float,_z: float) -> float: return 0.0

class TestRange extends Node:
	var damage_taken := 0
func hurt(amount: int) -> void: damage_taken+=amount

func _init() -> void:
	var arena=TestArena.new()
	arena.walker=CharacterBody3D.new()
	arena.add_child(arena.walker)
	root.add_child(arena)
	var range=TestRange.new();root.add_child(range)
	var predator=preload("res://trex.gd").new()
	predator.arena=arena;predator.manager=range
	# This is the same player body used in the arena.  The bite path must damage
	# its owner rather than looking for a nonexistent take_hit method.
	predator.apply_bite(arena.walker)
	assert(range.damage_taken==140,"T-rex bite did not damage the player body")
	var enemy=CharacterBody3D.new()
	var received:=0
	enemy.set_meta("ignored",received)
	print("PASS: player body receives one 140-point T-rex bite")
	quit()
