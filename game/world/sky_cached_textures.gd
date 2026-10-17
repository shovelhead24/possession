extends RefCounted
static var atlas: ImageTexture
static var upper: ImageTexture
static func get_atlas() -> ImageTexture:
	if atlas==null: atlas=read_texture("res://world/cloud_cache/billboards-v1.png")
	return atlas
static func get_upper() -> ImageTexture:
	if upper==null: upper=read_texture("res://world/cloud_cache/painterly-v1.png")
	return upper
static func read_texture(path: String) -> ImageTexture:
	var image=Image.load_from_file(path)
	assert(image!=null,"Missing prebaked cloud texture: "+path)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
