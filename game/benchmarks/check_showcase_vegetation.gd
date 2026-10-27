extends SceneTree
func _initialize():run.call_deferred()
func run():
	for id in ["autumn","alpine","pass","lake"]:
		var scene=load("res://assets/showcases/"+id+".scn").instantiate()
		var total=0;var cards=0;var low=INF;var high=0.0;var ratio_low=INF;var ratio_high=0.0
		for child in scene.get_children():
			if not child is MultiMeshInstance3D:continue
			var mm=child.multimesh
			if mm.mesh.get_aabb().size.y>5:
				assert(child.has_meta("tree_visual_height_v2"))
				var body=scene.get_child(child.get_index()+1)
				for i in mm.instance_count:
					var xf=mm.get_instance_transform(i)
					assert(absf(xf.basis.determinant())>.01,"Saved tree transform must remain valid")
					if body is StaticBody3D and body.is_in_group("trex_passable_tree"):assert(body.get_child(i).basis.is_equal_approx(xf.basis),"Tree visual/collision scales must agree")
					ratio_low=minf(ratio_low,xf.basis.y.length()/xf.basis.x.length());ratio_high=maxf(ratio_high,xf.basis.y.length()/xf.basis.x.length())
					low=minf(low,xf.basis.y.length());high=maxf(high,xf.basis.y.length());total+=1
			elif mm.mesh.surface_get_material(0) is ShaderMaterial:
				if mm.mesh.surface_get_material(0).shader.resource_path.ends_with("showcase_grass_cards.gdshader"):
					cards+=1
					for j in mm.instance_count:assert(absf(mm.get_instance_transform(j).basis.determinant())>.001,"Saved grass transform must remain valid")
		assert(total>0 and cards>0 and high>low*1.5)
		print("VEGETATION_ASSET_PASS ",id," trees=",total," height scale=",low,"..",high," card batches=",cards," y/x=",ratio_low,"..",ratio_high)
		scene.free()
	quit()
