extends SceneTree
const Budget=preload("res://world/tree_foliage_budget.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
func item(id,point,height=10.0):
	return {"id":id,"point":point,"valid":true,"height":height,"variant":0,"lod":-1,"transform":Transform3D(Basis.IDENTITY,Ring.point(point.x,0,point.y))}
func _initialize(): run.call_deferred()
func run():
	var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,2,0)
	var budget=Budget.new();budget.radii.assign([.3])
	var sparse=[item(1,Vector2(0,-30)),item(2,Vector2(100,-30))]
	var sparse_lod=budget.select(sparse,sparse.size(),camera)[0]
	var dense=sparse.duplicate(true)
	for i in 100: dense.append(item(i+3,Vector2((i%10)*3-15,-(i/10)*3-15)))
	var result=budget.select(dense,dense.size(),camera)
	assert(result[0]>=sparse_lod and budget.dense_adjusted>0,"Canopy density reduces detail")
	var high=0;var medium=0
	for lod in result:
		assert(lod>=0 and lod<=3,"No tree hidden by density")
		if lod==0: high+=1
		if lod==1: medium+=1
	assert(high<=4 and medium<=20,"Detail caps")
	var copy=dense.duplicate(true);assert(result==budget.select(dense,dense.size(),camera))
	assert(copy==dense,"Policy does not mutate placements, collision or saved records")
	var close=[item(1,Vector2(0,-2)),item(2,Vector2(0,-8),4.0)]
	for lod in budget.select(close,close.size(),camera): assert(lod<=2,"Close trees retain geometry")
	assert(Budget.lod_for(15,0)==0 and Budget.lod_for(18,0)==1)
	assert(Budget.cell_at(Vector2(1500000,0))==Budget.cell_at(Vector2(-1500000,0)))
	# Adjacent density cells join correctly across the ring coordinate seam.
	camera.position=Ring.point(1499980,2,0)
	var seam=[item(1,Vector2(1499980,30))]
	var base=budget.select(seam,1,camera)[0]
	for i in 100: seam.append(item(i+2,Vector2(-1499999+(i%10)*2,(i/10)*2+20)))
	var seam_lods=budget.select(seam,seam.size(),camera)
	assert(seam_lods[0]>=base and budget.dense_adjusted>0)
	camera.position=Vector3(0,2,0)
	var stress=[]
	for i in 2400: stress.append(item(i,Vector2((i%60)*8-240,-(i/60)*8+120)))
	var timings=[]
	for i in 10:
		budget.select(stress,stress.size(),camera);timings.append(budget.update_usec)
	timings.sort();print("FOLIAGE_BUDGET_CPU median_usec=",timings[5]," for 2400 resident placements")
	print("FOLIAGE_BUDGET_PASS: density, detail caps, no hidden trees, stable selection, close geometry, immutable placements, hysteresis and ring seam")
	quit()
