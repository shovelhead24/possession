extends SceneTree
const Cache=preload("res://world/sdf_field_cache.gd")
const Recipe=preload("res://world/sdf_recipe.gd")

func _initialize() -> void:
	var origin := Vector3(-64,-24,-64);var cells := Vector3i(16,44,16)
	var caches := {false:Cache.new(),true:Cache.new()}
	for enabled in caches: caches[enabled].build(origin,cells,2,[],3.2,.35,enabled)
	for kind in ["lower","carve","tunnel"]:
		var times := {false:[],true:[]};var fields := {false:[],true:[]}
		for trial in 12:
			var features := []
			for i in (20 if kind=="lower" else 1):
				var feature := Recipe.feature(kind,Vector3(-48,0,-48))
				feature.radius=16 if kind=="lower" else 4
				if kind=="lower": feature.amount=.05+trial*.001
				else: feature.y=trial*.05
				features.append(feature)
			var results := {}
			for enabled in ([false,true] if trial%2==0 else [true,false]):
				results[enabled]=caches[enabled].build(origin,cells,2,features,3.2,.35,enabled)
				if trial>1:
					times[enabled].append(results[enabled].ms)
					fields[enabled].append(results[enabled].profile.field_ms)
			assert(results[true].vertices==results[false].vertices and results[true].normals==results[false].normals and results[true].indices==results[false].indices,"Optimisation changed mesh")
			assert(results[true]._field_state.values==results[false]._field_state.values,"Optimisation changed sampled field")
		for enabled in times: times[enabled].sort();fields[enabled].sort()
		print("EDIT_CPU_AB ",JSON.stringify({"kind":kind,"baseline_median_ms":times[false][5],"optimised_median_ms":times[true][5],"baseline_field_ms":fields[false][5],"optimised_field_ms":fields[true][5]}))
	# Curved/yawed/blended ridges and tunnels must preserve source ordering too.
	var mixed := []
	for kind in ["ridge","tunnel","flatten"]:
		var feature := Recipe.feature(kind,Vector3(-48,2,-48))
		feature.bend=7;feature.yaw=37;feature.amount=.7;feature.radius=5
		mixed.append(feature)
	var old: Dictionary=caches[false].build(origin,cells,2,mixed,3.2,.35,false)
	var next: Dictionary=caches[true].build(origin,cells,2,mixed,3.2,.35,true)
	assert(old._field_state.values==next._field_state.values and old.vertices==next.vertices and old.normals==next.normals and old.indices==next.indices,"Curved/blended ordered edit changed")
	var noop_cache := Cache.new();noop_cache.build(origin,cells,2,[],3.2,.35)
	var edge := Recipe.feature("lower",Vector3(-28,0,-48));edge.radius=2;edge.amount=1
	var unchanged := noop_cache.build(origin,cells,2,[edge],3.2,.35)
	assert(unchanged.profile.rebuilt_blocks==0,"Zero-effect brush rebuilt unchanged geometry")
	print("PASS: alternating warm-edit A/B trials preserve exact field and mesh arrays")
	quit()
