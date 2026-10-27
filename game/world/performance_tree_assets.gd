extends "res://world/tree_patch_assets.gd"
const PINE_SOURCE="res://assets/performance_trees/pine_lods.glb"
const MAPPING={"Christmas tree":"Pine_medium_3","Christmas tree_2":"Pine_small_2","Christmas tree_3":"Pine_sapling_1"}
func load_meshes() -> Dictionary:
	var identity=FileAccess.get_sha256(PINE_SOURCE)+FileAccess.get_sha256(get_script().resource_path)+FileAccess.get_sha256("res://world/tree_patch_assets.gd")+FileAccess.get_sha256(FOLIAGE.resource_path)+str(Engine.get_version_info().hex)
	var cache="user://performance-pines-"+identity.sha256_text()+".res"
	if FileAccess.file_exists(cache):
		var resource=ResourceLoader.load(cache)
		if resource and resource.has_meta("variants"):return resource.get_meta("variants")
	var doc=GLTFDocument.new();var state=GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(PINE_SOURCE),state)==OK)
	var source=doc.generate_scene(state)
	for node in source.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var material=node.mesh.surface_get_material(surface)
			if not material is BaseMaterial3D:continue
			var id=material.get_instance_id()
			if not materials.has(id):
				if "Clusters" in material.resource_name or "Billboard" in material.resource_name:
					var texture: Texture2D=material.albedo_texture
					assert(texture!=null,"Pine foliage texture missing")
					var cutout=ShaderMaterial.new();cutout.shader=FOLIAGE
					cutout.set_shader_parameter("tex",ImageTexture.create_from_image(prepare_foliage_image(texture.get_image())))
					cutout.set_shader_parameter("cut",.5);materials[id]=cutout
				else:
					var bark=material.duplicate();bark.roughness=1.0;bark.metallic=0.0;bark.normal_enabled=false;bark.ao_enabled=false
					materials[id]=bark
			node.mesh.surface_set_material(surface,materials[id])
	var raw={};var regex=RegEx.new();regex.compile("^(Pine_.+?)(?:_Billboard)?_LOD(\\d)")
	walk(source,source,regex,raw);source.free()
	var result={}
	for old_name in MAPPING:
		var name=MAPPING[old_name];assert(raw.has(name))
		var reference: AABB=raw[name][0].get_aabb()
		var factor=1.0/reference.size.y
		var base=trunk_base(raw[name][0])
		var lods: Array[Mesh]=[]
		for level in 4:
			assert(raw[name].has(level))
			var mesh: ArrayMesh=raw[name][level];var box=mesh.get_aabb()
			print("PINE_BOUNDS ",name," ",level," ",box)
			var normalized=ArrayMesh.new()
			# Source meshes bake successive LOD rows 20 metres apart. Keep one
			# trunk origin and scale, rather than recentering each changing canopy.
			var pivot=base+Vector3(0,0,-20.0*level)
			if level<3:
				assert((trunk_base(mesh)-pivot).length()*factor<.025,"Pine trunk LOD alignment")
			append(normalized,mesh,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),-pivot*factor))
			lods.append(normalized)
		result[old_name]=lods
	var resource=Resource.new();resource.set_meta("variants",result);assert(ResourceSaver.save(resource,cache)==OK)
	return result

func trunk_base(mesh: Mesh) -> Vector3:
	var low=Vector3(INF,INF,INF);var high=Vector3(-INF,-INF,-INF)
	var floor_y=mesh.get_aabb().position.y
	for surface in mesh.get_surface_count():
		if mesh.surface_get_material(surface) is ShaderMaterial:continue
		for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if vertex.y<floor_y+.02:
				low=low.min(vertex);high=high.max(vertex)
	assert(is_finite(low.x),"Pine bark base missing")
	return Vector3((low.x+high.x)*.5,floor_y,(low.z+high.z)*.5)
