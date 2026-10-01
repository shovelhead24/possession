extends Node3D
var sides: Array=[]
var wheels: Array=[]
var phase := Vector2.ZERO
var half_width := 1.235
# Eight suspension points per side: seven road wheels plus the leading run.
var probe_z: Array[float]=[-1.72,-1.249,-.540,.160,.861,1.562,2.281,3.0]

func probe_patch(index: int) -> Dictionary:
	# Each road-wheel station owns the belt from the midpoint before it to the
	# midpoint after it. The end stations extend by half their nearest spacing.
	var z=probe_z[index]
	var before=(probe_z[index-1]+z)*.5 if index>0 else z-(probe_z[1]-z)*.5
	var after=(z+probe_z[index+1])*.5 if index<probe_z.size()-1 else z+(z-probe_z[index-1])*.5
	return {"from":before,"center":z,"to":after}

func setup(model: Node3D, tank: Node3D) -> void:
	var links: Array=[[],[]];var stack=[model]
	while not stack.is_empty():
		var node=stack.pop_back()
		if node is MeshInstance3D:
			var local=tank.global_transform.affine_inverse()*node.global_transform
			var box: AABB=local*node.mesh.get_aabb();var center=box.get_center();var label=String(node.name).to_lower()
			var side=0 if center.x<0 else 1
			if label.begins_with("palette_"):
				links[side].append({"index":label.get_slice("_",1).to_int(),"mesh":node,"transform":local,"center":center})
			elif "wheel" in label:
				var pivot=Node3D.new();add_child(pivot);pivot.position=center;node.reparent(pivot,true)
				wheels.append({"pivot":pivot,"side":side,"radius":.368 if "engine" in label else maxf(box.size.y,box.size.z)*.5})
		for child in node.get_children(): stack.append(child)
	for side in range(2):
		var list: Array=links[side];list.sort_custom(func(a,b): return a.index<b.index)
		var points: Array[Vector3]=[];var distances: Array[float]=[0.0]
		for link in list: points.append(link.center);link.mesh.hide()
		for i in range(points.size()): distances.append(distances[-1]+points[i].distance_to(points[(i+1)%points.size()]))
		var draw=MultiMeshInstance3D.new();var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=list[0].mesh.mesh;multi.instance_count=list.size();draw.multimesh=multi
		draw.material_override=list[0].mesh.material_override;add_child(draw)
		var first=(points[1]-points[-1]).normalized()
		sides.append({"points":points,"distances":distances,"length":distances[-1],"mesh":multi,"base":list[0].transform,"center":points[0],"angle":atan2(-first.y,first.z)})
	animate(0,0,0)
	print("TRACKS_READY: ",links[0].size()," + ",links[1].size()," links / ",wheels.size()," wheel parts")

func sample(side: Dictionary, distance: float) -> Dictionary:
	var points: Array=side.points;var distances: Array=side.distances
	var d=fposmod(distance,side.length);var index=0
	while index<points.size()-1 and distances[index+1]<=d: index+=1
	var next=(index+1)%points.size();var t=(d-distances[index])/(distances[index+1]-distances[index])
	var before=(index-1+points.size())%points.size();var after=(index+2)%points.size()
	var tangent=(points[next]-points[before]).normalized().lerp((points[after]-points[index]).normalized(),t).normalized()
	return {"point":points[index].lerp(points[next],t),"angle":atan2(-tangent.y,tangent.z)}

func animate(delta: float,left_speed: float,right_speed: float) -> void:
	if sides.size()!=2: return
	var speeds=[left_speed,right_speed]
	for side_index in range(2):
		var side: Dictionary=sides[side_index]
		# Increasing source link order moves forwards on the lower run; the belt runs backwards there.
		phase[side_index]=fposmod(phase[side_index]-speeds[side_index]*delta,side.length)
		for i in range(side.points.size()):
			var pose=sample(side,side.distances[i]+phase[side_index])
			var rotate=Basis(Vector3.RIGHT,pose.angle-side.angle)
			side.mesh.set_instance_transform(i,Transform3D(rotate,pose.point-rotate*side.center)*side.base)
	for wheel in wheels: wheel.pivot.rotate_x(-speeds[wheel.side]*delta/maxf(.1,wheel.radius))
