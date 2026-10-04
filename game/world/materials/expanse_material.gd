extends RefCounted
## Local-demo image loading matches authored_patch.gd. Exported builds must
## explicitly include these raw PNG/JPG files, or switch to imported resources.
const MAPS := ["grass_albedo", "grass_normal", "rock_albedo", "rock_normal", "rock_roughness", "limestone"]

static func create() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://world/materials/expanse.gdshader")
	for map in MAPS:
		var extension := ".jpg" if map == "limestone" else ".png"
		var image := Image.load_from_file("res://world/materials/" + map + extension)
		assert(image != null and not image.is_empty(), "Missing demo material: " + map)
		# Preserve full source files but cap runtime textures for integrated GPUs.
		var largest := maxi(image.get_width(), image.get_height())
		if largest > 1024:
			var ratio := 1024.0 / largest
			image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		material.set_shader_parameter(map, ImageTexture.create_from_image(image))
	return material

static func apply_nature(material: ShaderMaterial) -> void:
	# Workshop only: retain original user-provided assets and older demo defaults.
	for spec in [["grass_ground","grass"],["sparse_grass","sparse"],["rock_boulder_dry","rock"]]:
		for map in [["diffuse.jpg","albedo"],["nor_gl.png","normal"],["rough.jpg","roughness"]]:
			var image := Image.load_from_file("res://world/materials/nature/"+spec[0]+"_"+map[0])
			assert(image!=null and not image.is_empty(),"Missing nature PBR map")
			if image.get_width()>1024 or image.get_height()>1024: image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8);image.generate_mipmaps()
			material.set_shader_parameter(spec[1]+"_"+map[1],ImageTexture.create_from_image(image))
	material.set_shader_parameter("grass_metres",2.51)
	material.set_shader_parameter("rock_metres",1.8)
	material.set_shader_parameter("nature_surface",true)
