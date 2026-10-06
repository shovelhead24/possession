extends RefCounted
static var texture: ImageTexture

static func get_texture() -> ImageTexture:
	if texture: return texture
	var path := "user://cloud-noise-lattice-v1.png"
	var image := Image.new()
	if not FileAccess.file_exists(path) or image.load(path)!=OK or image.get_size()!=Vector2i(512,512):
		image=Image.create(512,512,false,Image.FORMAT_R8)
		for y in 512:
			for x in 512:
				var p := Vector2(fposmod(x*.1031,1.0),fposmod(y*.1030,1.0))
				p+=Vector2.ONE*p.dot(Vector2(p.y,p.x)+Vector2.ONE*33.33)
				image.set_pixel(x,y,Color(fposmod((p.x+p.y)*p.x,1.0),0,0))
		image.save_png(path)
	texture=ImageTexture.create_from_image(image)
	return texture
