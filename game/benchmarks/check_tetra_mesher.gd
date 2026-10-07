extends SceneTree
const Demo=preload("res://world/sdf_demo.gd")
const Arena=preload("res://world/sdf_arena_expanded.gd")
const Indexed=preload("res://world/tetra_mesher.gd")

func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	var reference := Demo.new()
	var reports := []
	for origin in [Vector3(-32,-24,0),Vector3(-384,-24,128),Vector3(-192,-24,-96)]:
		var sample: Callable=Arena.expanded_field
		var legacy: Dictionary=reference.generate_legacy(3.2,.35,origin,Vector3i(16,44,16),2.0,sample)
		var indexed: Dictionary=Indexed.build(sample.bind(3.2,.35),origin,Vector3i(16,44,16),2.0)
		reports.append(compare(str(origin),legacy,indexed))
	# Exercise the actual coarse-border interpolation used by streamed chunks.
	var origin := Vector3(-192,-24,-96)
	var coarse_origin := origin-Vector3.ONE*8
	var values := PackedFloat32Array();values.resize(7*14*7)
	for z in 7:
		for y in 14:
			for x in 7: values[(z*14+y)*7+x]=Arena.mid_field(coarse_origin+Vector3(x,y,z)*8,3.2,.35)
	var seam := Arena.border_field.bind(origin,coarse_origin,values,7,14,8.0)
	reports.append(compare("overpass seam",reference.generate_legacy(3.2,.35,origin,Vector3i(16,44,16),2.0,seam),Indexed.build(seam.bind(3.2,.35),origin,Vector3i(16,44,16),2.0)))
	var empty_sample := func(_p: Vector3) -> float: return 1.0
	var empty := Indexed.build(empty_sample,Vector3.ZERO,Vector3i(2,2,2),1)
	assert(empty.vertices.is_empty() and empty.indices.is_empty())
	var file := FileAccess.open("user://tetra-mesher-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"));file.close()
	for node in [reference.terrain,reference.collision,reference.camera,reference.player,reference.hud]: node.free()
	reference.free()
	print("PASS: triangle order/winding, positions, normals, seam sampling and empty volume")
	quit()

func compare(label: String, legacy: Dictionary, indexed: Dictionary) -> Dictionary:
	assert(legacy.vertices.size()==indexed.indices.size(),"Triangle count changed: "+label)
	var position_error := 0.0
	var normal_error := 0.0
	for i in legacy.vertices.size():
		var id: int=indexed.indices[i]
		position_error=maxf(position_error,legacy.vertices[i].distance_to(indexed.vertices[id]))
		normal_error=maxf(normal_error,legacy.normals[i].distance_to(indexed.normals[id]))
	assert(position_error<.0001,"Geometry changed: "+label)
	assert(normal_error<.005,"Normals changed: "+label)
	var result := {"region":label,"legacy":legacy.profile,"indexed":indexed.profile,"legacy_ms":legacy.ms,"indexed_ms":indexed.ms,"position_error":position_error,"normal_error":normal_error,"legacy_array_bytes":legacy.vertices.size()*24,"indexed_array_bytes":indexed.vertices.size()*24+indexed.indices.size()*4}
	print("MESHER_PROFILE ",JSON.stringify(result))
	return result
