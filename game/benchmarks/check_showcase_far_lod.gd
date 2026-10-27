extends SceneTree
class TestArena extends Node3D:
	var camera: Camera3D
func _initialize():run.call_deferred()
func run():
	var arena=TestArena.new();root.add_child(arena)
	arena.camera=Camera3D.new();arena.add_child(arena.camera)
	var manager=preload("res://world/performance_showcases.gd").new();manager.arena=arena
	var meshes=[]
	for i in 5:meshes.append(QuadMesh.new())
	manager.wind_variants=[meshes]
	var visual=MultiMeshInstance3D.new();visual.multimesh=MultiMesh.new();visual.multimesh.mesh=meshes[3];arena.add_child(visual)
	manager.tree_batches=[{"node":visual,"species":0,"lod":3}]
	for sample in [[100,2],[600,3],[2200,4],[600,3],[100,2]]:
		arena.camera.position=Vector3(sample[0],0,0);manager._process(1.0)
		assert(manager.tree_batches[0].lod==sample[1])
		assert(visual.multimesh.mesh==meshes[sample[1]])
	manager.free();print("FAR_BILLBOARD_LOD_PASS mesh / curved / static / curved / mesh");quit()
