extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await process_frame
	var editor=arena.terrain_editor
	editor.save_path="user://terrain_editor_test.res"
	var p=Vector3(270,0,-1270);var before=arena.height_at(p.x,p.z)
	editor.sculpt(p,18,2)
	assert(arena.height_at(p.x,p.z)>before+1.9)
	assert(editor.dirty)
	await physics_frame;await physics_frame
	var hit=arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*150,p-Vector3.UP*40))
	assert(not hit.is_empty() and absf(hit.position.y-arena.height_at(p.x,p.z))<.1,"Collider did not follow brush")
	editor.save_terrain();assert(not editor.dirty)
	var saved=ResourceLoader.load(editor.save_path,"",ResourceLoader.CACHE_MODE_IGNORE)
	assert(absf(saved.height_at(p.x,p.z)-arena.height_at(p.x,p.z))<.001)
	var terrain=saved.terrain.instantiate();assert(terrain.get_child_count()==16);terrain.free()
	editor.sculpt(p,18,-.5);editor.save_terrain();assert(not editor.dirty,"Second save failed")
	arena.rex_menu.set_indicators(true);await process_frame
	assert(root.get_tree().get_nodes_in_group("combat_viewcones").size()>0)
	print("PASS: terrain brush height, collision, disk roundtrip, repeated save and indicator toggle")
	quit()
