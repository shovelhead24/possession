extends SceneTree
const Fast=preload("res://world/sky_cached_billboards.gd")
const Old=preload("res://benchmarks/performance_reference/sky_cached_billboards.gd")
func record() -> Dictionary:
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=QuadMesh.new();mm.instance_count=256
	var node=MultiMeshInstance3D.new();node.multimesh=mm;root.add_child(node)
	var r={"node":node,"base":[],"right":[],"up":[],"size":[]}
	for i in 256:
		var basis=Basis(Vector3.FORWARD,float(i)*.005);basis.x*=550+i;basis.y*=250+i
		var t=Transform3D(basis,Vector3((i%16)*250-2000,1000,(i/16)*250-2000))
		r.base.append(t);r.right.append(Vector3.ZERO);r.up.append(t.basis.y.normalized());r.size.append(Vector2(t.basis.x.length(),t.basis.y.length()))
	return r
func _initialize():run.call_deferred()
func run():
	var old=Old.new();var fast=Fast.new();var a=record();var b=record()
	for frame in 240:
		var camera=Vector3(sin(frame*.03)*1800,100+frame*6,cos(frame*.03)*1800)
		old.orient(a,camera,1.0/60);fast.orient(b,camera,1.0/60)
		for i in 256:assert(a.node.multimesh.get_instance_transform(i).is_equal_approx(b.node.multimesh.get_instance_transform(i)),"Cloud transform changed")
	var result={}
	for trial in 4:
		var start=Time.get_ticks_usec()
		for frame in 1000:
			var camera=Vector3(frame*.2,100,frame*.15)
			if trial%2==0:old.orient(a,camera,1.0/60)
			else:fast.orient(b,camera,1.0/60)
		result[("old_" if trial%2==0 else "cached_")+str(trial)]=(Time.get_ticks_usec()-start)/1000.0
	print("PASS 61440 cloud transforms including overhead passage ",JSON.stringify(result))
	FileAccess.open("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/cloud-orientation-check.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	old.free();fast.free();a.node.free();b.node.free();quit()
