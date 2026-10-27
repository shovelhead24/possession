extends SceneTree
class Weapon extends Node:
	var selected=0
	var view_active=false
	var hits=0
	var collision=false
	var arena={"camera":Camera3D.new()}
	func trace_segment(_start,end):return {"position":end} if collision else {}
	func apply_hit(_hit,_damage,_origin):hits+=1
func _initialize():run.call_deferred()
func run():
	var p=load("res://world/plasma_billboards.gd").new();root.add_child(p)
	var w=Weapon.new();root.add_child(w);root.add_child(w.arena.camera);p.weapon=w
	p.muzzle=Sprite2D.new();root.add_child(p.muzzle)
	p.batch=MultiMeshInstance3D.new();p.add_child(p.batch)
	p.batch.multimesh=MultiMesh.new();p.batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	p.batch.multimesh.use_colors=true;p.batch.multimesh.mesh=QuadMesh.new();p.batch.multimesh.instance_count=152
	assert(p.launch(Vector3(100,2,3),Vector3.RIGHT,100,12,Vector3(99,2,3)))
	p._physics_process(.01)
	for delta in [Vector3(64,0,64),Vector3(-2048,128,4096),Vector3(800,0,-300)]:
		var before=p.bolts[0].point
		p.batch.global_position-=delta
		p.origin_shifted(delta)
		assert(p.bolts[0].point.is_equal_approx(before-delta))
		assert(p.batch.global_transform==Transform3D.IDENTITY)
		var visual=p.batch.multimesh.get_instance_transform(0).origin
		print("PLASMA_VISUAL ",visual," point=",p.bolts[0].point," fraction=",Engine.get_physics_interpolation_fraction())
		assert(visual.distance_to(p.bolts[0].point)<1.0)
	assert(p.launch(Vector3(2,3,4),Vector3.RIGHT,100,12,Vector3(1,3,4)))
	p._process(0)
	assert(p.batch.multimesh.get_instance_transform(4).origin.is_equal_approx(Vector3(2,3,4)))
	w.collision=true;p._physics_process(.01);assert(w.hits==2 and p.bolts.is_empty())
	var before=p.bursts[0].point;p.origin_shifted(Vector3(64,0,0))
	assert(p.bursts[0].point.is_equal_approx(before-Vector3(64,0,0)))
	print("PLASMA_ORIGIN_PASS existing bolts, new bolts, swept hits, impact bursts across repeated shifts")
	quit()
