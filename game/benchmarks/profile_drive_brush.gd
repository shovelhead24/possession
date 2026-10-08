extends SceneTree
const Source=preload("res://world/terrain_baseline_source.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
const Recipe=preload("res://world/sdf_recipe.gd")
const Cache=preload("res://world/terrain_drive_edit_cache.gd")
const Reference=preload("res://benchmarks/drive_brush_reference.gd")
const Compact=preload("res://world/terrain_drive_recipe.gd")

func _initialize() -> void:
	var source:=Source.new();source.curve_to_ring=true;assert(source.initialize())
	var key:=Vector2i(1,1);var cache:=Cache.new()
	var base:Dictionary=source.build_tile(key)
	var original_count:int=base.vertices.size()
	var features:=[];var before_times:=[];var after_times:=[]
	for i in 10:
		var f:=Recipe.feature("hill",Vector3(224+i*2,source.surface_height(Vector2(224+i*2,300)),300));f.radius=12;f.amount=.8;features.append(f)
		var reference:=Reference.new();reference.source=source;reference.cuts=features
		var copy:=base.duplicate();copy.vertices=base.vertices.duplicate();copy.normals=base.normals.duplicate()
		var started:=Time.get_ticks_usec();var old:Dictionary=reference.rebuild(copy,key)
		before_times.append((Time.get_ticks_usec()-started)/1000.0)
		started=Time.get_ticks_usec();var result:Dictionary=cache.build(source,key,features,base)
		after_times.append((Time.get_ticks_usec()-started)/1000.0)
		assert(base.vertices.size()==original_count,"Cached base mesh mutated")
		# Independent cold replay must produce exactly the same final geometry.
		var fresh:=Cache.new();var replay:Dictionary=fresh.build(source,key,features,base)
		assert(result.vertices==replay.vertices and result.indices==replay.indices,"Warm mesh differs from fresh replay")
		assert(old.indices.size()==result.indices.size(),"Optimisation changed triangle count")
		var max_error:=0.0
		assert(old.vertices.size()==result.vertices.size(),"Optimisation changed vertex count")
		for j in old.vertices.size(): max_error=maxf(max_error,old.vertices[j].distance_to(result.vertices[j]))
		assert(max_error<.005,"Optimisation moved the sampled surface")
		print("BRUSH_AB ",JSON.stringify({"step":i,"before_ms":before_times.back(),"after_ms":after_times.back(),"max_vertex_error_m":max_error,"profile":result.profile}))
	var repeated:=[]
	for i in 600:
		var f:=Recipe.feature("hill",Vector3(200,float(i),300));f.radius=12;f.amount=4.0/60;repeated.append(f)
	var compact:=Compact.compact(repeated)
	assert(compact.size()==1 and absf(compact[0].amount-40)<.000001)
	var tunnel:=Recipe.feature("tunnel",Vector3(200,0,300));tunnel.end_x=230;tunnel.end_y=0;tunnel.end_z=300
	var mixed:=repeated.slice(0,300)+[tunnel]+repeated.slice(300)
	var compact_mixed:=Compact.compact(mixed);assert(compact_mixed.size()==3,"Compaction crossed a CSG barrier")
	var error:=0.0
	for x in range(190,220,2):
		for y in range(-6,42,2):
			var p:=Vector3(x,y,300)
			error=maxf(error,absf(Recipe.compose(p,p.y,mixed)-Recipe.compose(p,p.y,compact_mixed)))
	assert(error<.000001,"Compaction changed ordered field")
	print("BRUSH_COMPACTION ",JSON.stringify({"before_features":repeated.size(),"after_features":compact.size(),"before_json_bytes":JSON.stringify(repeated).length(),"after_json_bytes":JSON.stringify(compact).length(),"max_field_error":error}))
	print("BRUSH_PROFILE_PASS ",JSON.stringify({"before_ms":before_times,"after_ms":after_times}));quit()
