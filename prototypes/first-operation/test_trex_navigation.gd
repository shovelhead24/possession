extends SceneTree

# T-rex collision explicitly ignores trunks.  Its route map must preserve that
# physical rule while ordinary squad routes continue to avoid tree cells.
class TestArena extends Node3D:
	func height_at(_x: float,_z: float) -> float: return 0.0
class TestCover extends Node:
	var rocks: Array=[]
class TestTrees extends Node:
	var trees: Array=[{"position":Vector3(0,0,-20)}]

func _init() -> void:
	var arena=TestArena.new();root.add_child(arena)
	var trees=TestTrees.new();trees.name="ArenaTrees";arena.add_child(trees)
	var navigation=preload("res://squad_navigation.gd").new();navigation.setup(arena,TestCover.new())
	var trunk=Vector3(0,0,-20)
	assert(navigation.is_blocked(trunk),"Squad grid must keep tree cover solid")
	assert(not navigation.is_blocked(trunk,true),"T-rex grid must honour its tree collision exception")
	assert(navigation.path(Vector3.ZERO,Vector3(0,0,-40),true).size()>2,"T-rex route should cross a passable tree lane")
	print("PASS: squad tree blocking and T-rex tree-passable routes remain distinct")
	root.remove_child(arena);arena.free();quit()
