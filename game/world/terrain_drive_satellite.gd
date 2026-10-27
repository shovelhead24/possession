extends RefCounted
## Full-resolution home imagery, decoded/compressed before entry; no terrain cache changes.
const SOURCE := "res://mocks/dem/millstreet_sat.dat"

static func load_image(source: String=SOURCE) -> Image:
	var source_file := FileAccess.open(source,FileAccess.READ)
	if not source_file: return null
	var identity := (source+str(FileAccess.get_modified_time(source))+str(source_file.get_length())+"rgb8-mips-s3tc-v1").sha256_text()
	source_file.close()
	var directory := "user://terrain-satellite/"
	var path := directory+identity+".bin"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		var data: Variant=file.get_var(false) if file else null
		if data is Dictionary and data.get("identity")==identity:
			var cached := Image.create_from_data(data.width,data.height,true,data.format,data.bytes)
			if cached and not cached.is_empty():
				print("DRIVE_SATELLITE cache width=",cached.get_width()," bytes=",cached.get_data().size())
				return cached
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(source))!=OK: return null
	image.convert(Image.FORMAT_RGB8)
	image.generate_mipmaps()
	if image.compress(Image.COMPRESS_S3TC,Image.COMPRESS_SOURCE_SRGB)!=OK:
		push_error("Satellite compression failed");return null
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_var({"identity":identity,"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"bytes":image.get_data()},false)
		file.close();DirAccess.rename_absolute(path+".tmp",path)
	print("DRIVE_SATELLITE built width=",image.get_width()," bytes=",image.get_data().size())
	return image

static func create_material(texture: Texture2D, metadata: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader=preload("res://world/terrain_drive_satellite.gdshader")
	result.set_shader_parameter("satellite",texture)
	result.set_shader_parameter("home_origin",Vector2(metadata.camera_px[0],metadata.camera_px[1])/Vector2(metadata.w,metadata.h))
	result.set_shader_parameter("home_span",Vector2(metadata.w,metadata.h)*float(metadata.m_per_px))
	result.set_shader_parameter("ring_radius",3000000.0/TAU)
	return result
