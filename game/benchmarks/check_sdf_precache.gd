extends SceneTree
const Cache=preload("res://world/sdf_field_cache.gd")
const Recipe=preload("res://world/sdf_recipe.gd")

func _initialize() -> void:
	var cache := Cache.new()
	var origin := Vector3(-64,-24,-64);var cells := Vector3i(16,44,16)
	var first := cache.build(origin,cells,2,[],3.2,.35)
	var f := Recipe.feature("lower",Vector3(-48,0,-48));f.radius=4;f.amount=1.0
	var warm := cache.build(origin,cells,2,[f],3.2,.35)
	assert(warm.profile.base_evaluations==0 and warm.profile.rebuilt_blocks<16)
	assert(warm.profile.updated_samples<first.profile.updated_samples)
	var full := Cache.new().build(origin,cells,2,[f],3.2,.35)
	assert(warm.vertices==full.vertices and warm.indices==full.indices and warm.normals==full.normals,"Incremental/cold mismatch")
	f.amount=3
	var deeper := cache.build(origin,cells,2,[f],3.2,.35)
	var independent := Cache.new().build(origin,cells,2,[f],3.2,.35)
	assert(deeper.vertices==independent.vertices and deeper.normals==independent.normals)
	var undo := cache.build(origin,cells,2,[],3.2,.35)
	assert(undo.vertices==first.vertices and undo.normals==first.normals)
	# Ordered non-additive operation after a brush must also match a cold replay.
	var flat := Recipe.feature("flatten",Vector3(-48,2,-48));flat.radius=8
	var mixed := cache.build(origin,cells,2,[f,flat],3.2,.35)
	var cold_mixed := Cache.new().build(origin,cells,2,[f,flat],3.2,.35)
	assert(mixed.vertices==cold_mixed.vertices and mixed.normals==cold_mixed.normals)
	# Sample values agree with the authored evaluator, up to float32 storage error.
	var state: Dictionary=mixed._field_state;var dims := cells+Vector3i.ONE*3
	var error := 0.0
	for z in dims.z:
		for y in dims.y:
			for x in dims.x:
				var p := origin-Vector3.ONE*2+Vector3(x,y,z)*2
				error=maxf(error,absf(state.values[(z*dims.y+y)*dims.x+x]-Recipe.field(p,3.2,.35,[f,flat])))
	assert(error<.00002)
	var path := "user://sdf-field-cache-regression.bin"
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_var(mixed,false);file.close()
	file=FileAccess.open(path,FileAccess.READ);var read: Dictionary=file.get_var(false);file.close()
	var restored := Cache.new();restored.restore(origin,cells,2,3.2,.35,read._field_state)
	var reused := restored.build(origin,cells,2,[f,flat],3.2,.35)
	assert(reused.profile.base_evaluations==0 and reused.profile.rebuilt_blocks==0 and reused.vertices==mixed.vertices)
	restored.restore(origin,cells,2,3.2,.35,first._field_state)
	var restored_undo := restored.build(origin,cells,2,[],3.2,.35)
	assert(restored_undo.profile.rebuilt_blocks==0 and restored_undo.vertices==first.vertices,"Disk undo did not replace resident field")
	var crater_cache := Cache.new()
	crater_cache.build(origin,cells,2,[],3.2,.35)
	var craters := []
	for i in 6:
		var crater := Recipe.feature("carve",Vector3(-48+i*.5,1,-48));crater.radius=2;crater.localized=true
		craters.append(crater)
		var incremental := crater_cache.build(origin,cells,2,craters,3.2,.35)
		var replay := Cache.new().build(origin,cells,2,craters,3.2,.35)
		assert(incremental.vertices==replay.vertices and incremental.normals==replay.normals,"Overlapping crater differs from full replay")
		assert(incremental.profile.base_evaluations==0)
	var seam := Recipe.feature("carve",Vector3(-32,1,-48));seam.radius=2;seam.localized=true
	var left := Cache.new().build(origin,cells,2,[seam],3.2,.35)
	var right := Cache.new().build(origin+Vector3(32,0,0),cells,2,[seam],3.2,.35)
	var a := {};var b := {}
	for i in left.vertices.size():
		if absf(left.vertices[i].x+32)<.0001: a[str(left.vertices[i].snapped(Vector3.ONE*.0001))]=left.normals[i]
	for i in right.vertices.size():
		if absf(right.vertices[i].x+32)<.0001: b[str(right.vertices[i].snapped(Vector3.ONE*.0001))]=right.normals[i]
	assert(a.size()>0 and a.size()==b.size())
	for key in a: assert(b.has(key) and a[key].distance_to(b[key])<.0001,"Crater seam position/normal mismatch")
	var report := {"cold_ms":first.ms,"warm_small_brush_ms":warm.ms,"warm_dose_change_ms":deeper.ms,"warm_profile":warm.profile,"field_error":error,"disk_restored_ms":reused.ms}
	file=FileAccess.open("user://sdf-precache-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PRECACHE_PROFILE ",JSON.stringify(report))
	print("PASS: local remesh, zero warm base evaluations, cached kernels, dose changes, undo, ordered edits, float32 field fidelity, disk-restored warm cache")
	quit()
