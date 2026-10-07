extends SceneTree
const Mesher=preload("res://world/tetra_mesher.gd")
const Recipe=preload("res://world/sdf_recipe.gd")

func _initialize() -> void:
	var reports := []
	for origin in [Vector3(-48,-24,-48),Vector3(-8,-24,8),Vector3(-192,-24,-96)]:
		var cells := Vector3i(4,44,4)
		var samples := PackedFloat32Array()
		var sampler := Recipe.field.bind(3.2,.35,[])
		for z in 5:
			for y in 45:
				for x in 5: samples.append(sampler.call(origin+Vector3(x,y,z)*2))
		var baseline := [];var optimised := [];var skipped := 0
		for trial in 12:
			# Alternate execution order to limit warmup/order bias.
			var results := {}
			for enabled in ([false,true] if trial%2==0 else [true,false]):
				results[enabled]=Mesher.build(sampler,origin,cells,2,samples,Callable(),enabled)
			assert(results[true].vertices==results[false].vertices and results[true].indices==results[false].indices and results[true].normals==results[false].normals,"Layer skip altered mesh")
			if trial>1:
				baseline.append(results[false].ms);optimised.append(results[true].ms)
			skipped=results[true].profile.skipped_cells
		baseline.sort();optimised.sort()
		reports.append({"origin":str(origin),"baseline_median_ms":baseline[5],"optimised_median_ms":optimised[5],"skipped_cells":skipped,"total_cells":704})
	# Zero is outside, as in the original mesher; test exact-zero planes too.
	for height in [0.0,1.0,2.0]:
		var sample := func(p: Vector3) -> float: return p.y-height
		var a := Mesher.build(sample,Vector3.ZERO,Vector3i(3,4,3),1,PackedFloat32Array(),Callable(),false)
		var b := Mesher.build(sample,Vector3.ZERO,Vector3i(3,4,3),1)
		assert(a.vertices==b.vertices and a.indices==b.indices and a.normals==b.normals)
	print("LAYER_SKIP_PROFILE ",JSON.stringify(reports))
	print("PASS: uniform layer skipping preserves exact mesh arrays and zero-plane topology")
	quit()
