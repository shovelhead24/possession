extends SceneTree
const Background=preload("res://world/arena_ring_background.gd")

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var bg := Background.new();root.add_child(bg)
	bg.arena_extent=768;bg._noise.frequency=1.0/9000.0;bg._load_dem();bg._load_patches()
	var circumference: float=bg.CIRCUMFERENCES[bg.c_idx]
	for arc in [-8000.0,-3500.0,-1200.0,-100.0,0.0,100.0,3500.0,8000.0]:
		for lat in [-4000.0,0.0,4000.0]:
			var h: float=bg._far_terrain_h(arc,lat)
			assert(absf(h-bg._far_terrain_h(arc+circumference,lat))<.00001,"Wrapped DEM height differs")
			assert(absf(h-bg._far_terrain_h(arc-circumference,lat))<.00001)
	for lat in [-4000.0,0.0,4000.0]:
		assert(absf(bg._far_terrain_h(-.01,lat)-bg._far_terrain_h(.01,lat))<.1,"Height cliff at zero")
	bg._mat=ShaderMaterial.new();bg._build_arena_band()
	for node in [bg._band,bg.near_band]:
		var arrays: Array=node.mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var uv := (uvs[indices[i]]+uvs[indices[i+1]]+uvs[indices[i+2]])/3
			assert(maxf(absf(bg.canonical_arc(uv.x)),absf(uv.y))>=bg.arena_extent,"Backdrop triangle covers playable arena")
	var samples: Array[float]=[-8000,-3500,0,3500,8000]
	var a: Vector3=bg.boundary_vertex(8000,0,samples,false)
	var b: Vector3=bg.boundary_vertex(8000,3500,samples,false)
	assert(bg.boundary_vertex(8000,1750,samples,false).distance_to(a.lerp(b,.5))<.001)
	assert(absf(bg.canonical_arc(circumference*.5-1))>bg.arena_extent,"Opposite ring must remain visible")
	# Exercise the formerly broken fallback explicitly: patch lookup already
	# wrapped, so tests using only covered splice locations could miss this bug.
	bg._patch_rects.clear()
	for arc in [-3500.0,-8000.0]:
		assert(absf(bg._far_terrain_h(arc,1000)-bg._far_terrain_h(arc+circumference,1000))<.00001)
	bg._dem_w=0
	assert(absf(bg._far_terrain_h(-3500,1000)-bg._far_terrain_h(circumference-3500,1000))<.00001)
	print("PASS: wrapped heights, continuous zero seam, no backdrop faces over playable volume, matching coarse/fine boundary")
	bg.queue_free();quit()
