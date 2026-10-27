extends SceneTree
func _initialize():run.call_deferred()
func run():
	var assets=preload("res://world/tree_patch_assets.gd").new().load_meshes()
	for name in assets:
		for level in [2,3]:
			var mesh=assets[name][level]
			for s in mesh.get_surface_count():
				var mat=mesh.surface_get_material(s)
				if not mat is ShaderMaterial:continue
				var image=mat.get_shader_parameter("tex").get_image()
				image.save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/tree-edge-"+name+"-"+str(level)+".png")
				print("TREE_EDGE ",name," LOD",level," cut=",mat.get_shader_parameter("cut")," size=",image.get_size()," mips=",image.has_mipmaps())
	quit()
