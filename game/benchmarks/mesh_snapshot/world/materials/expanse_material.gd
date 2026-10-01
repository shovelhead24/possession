extends RefCounted
## Local-demo image loading matches authored_patch.gd. Exported builds must
## explicitly include these raw PNG/JPG files, or switch to imported resources.
const MAPS := ["grass_albedo", "grass_normal", "rock_albedo", "rock_normal", "rock_roughness", "limestone"]

static func create() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://benchmarks/mesh_snapshot/world/materials/expanse.gdshader")
	for map in MAPS:
		var extension := ".jpg" if map == "limestone" else ".png"
		var image := Image.load_from_file("res://benchmarks/mesh_snapshot/world/materials/" + map + extension)
		assert(image != null and not image.is_empty(), "Missing demo material: " + map)
		# Preserve full source files but cap runtime textures for integrated GPUs.
		var largest := maxi(image.get_width(), image.get_height())
		if largest > 1024:
			var ratio := 1024.0 / largest
			image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		material.set_shader_parameter(map, ImageTexture.create_from_image(image))
	return material
