extends SceneTree
const Field=preload("res://world/tree_density_field.gd")
func record(id,x,z,height=10.0): return {"id":id,"x":float(x),"z":float(z),"height":height,"species":"fir"}
func fresh(records):
	var f=Field.new();f.configure(["fir"],[.3]);f.sync(records);return f
func _initialize(): run.call_deferred()
func run():
	var records=[]
	for i in 2400: records.append(record(i,(i%60)*8-240,(i/60)*8))
	var field=fresh(records);var revision=field.revision
	field.sync(records);assert(field.revision==revision,"Unchanged records do not rebuild field")
	var original=field.coverage.duplicate()
	var extra=record(9999,0,0,20);field.upsert(extra);field.flush()
	assert(field.last_cells==9,"Single tree dirties only a 3x3 neighbourhood")
	records.append(extra);assert(field.coverage==fresh(records).coverage)
	field.remove(9999);field.flush();records.pop_back()
	for cell in original: assert(is_equal_approx(field.coverage[cell],original[cell]))
	# Move and resize a tree; old and new neighbourhoods both refresh.
	records[0]=record(0,30000,30000,30);field.sync(records)
	assert(field.last_cells<=18)
	var rebuilt=fresh(records)
	for cell in rebuilt.coverage: assert(is_equal_approx(field.coverage[cell],rebuilt.coverage[cell]))
	var path="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/work/density-field-test.json"
	assert(field.save_cache(path))
	var cached=Field.new();cached.configure(["fir"],[.3]);cached.sync(records,false)
	assert(cached.load_cache(path) and cached.loaded_cache and cached.pending.is_empty())
	assert(cached.multiplier(Vector2.ZERO)==field.multiplier(Vector2.ZERO))
	cached.upsert(record(8888,0,0));assert(not cached.load_cache(path),"Stale placement cache rejected")
	var changed_asset=Field.new();changed_asset.configure(["fir"],[.4]);changed_asset.sync(records,false)
	assert(not changed_asset.load_cache(path),"Canopy asset changes invalidate cache")
	var seam=fresh([record(1,1499999,0),record(2,-1499999,0)])
	assert(is_equal_approx(seam.coverage[Vector2i(62499,0)],seam.coverage[Vector2i(-62500,0)]))
	var budget=load("res://world/tree_foliage_budget.gd").new();budget.radii.assign([.3]);budget.authored_field=field
	var camera=Camera3D.new();root.add_child(camera)
	var items=[{"id":1,"point":Vector2.ZERO,"height":10.0,"variant":0,"valid":true,"lod":-1,"transform":Transform3D.IDENTITY}]
	budget.select(items,1,camera);var before=budget.field_revision
	field.upsert(record(8888,0,0));field.flush();budget.select(items,1,camera)
	assert(budget.field_revision>before and budget.density[0]==field.multiplier(Vector2.ZERO))
	items[0].transform.origin=Vector3(100,2,0);budget.invalidate();budget.select(items,1,camera)
	assert(budget.positions[0]==Vector3(100,2,0),"Grounding refreshes position without density rebuild")
	print("DENSITY_FIELD_PASS: local add/remove/move/resize, unchanged sync, full rebuild equivalence, persisted cache, stale cache rejection, asset invalidation, seam and renderer refresh")
	quit()
