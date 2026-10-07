extends Node
## Bounded home-imagery page set; PNG decode/filter/cache work stays off the UI thread.
const Frame=preload("res://world/ring_frame.gd")
const SOURCE := "res://mocks/dem/millstreet_sat.dat"
const FOLDER := "user://sdf-authoring-meshes/satellite-pages/"
const PAGE := 256
const SLOTS := 9
var arena: Node
var worker: Thread
var uploads: Array=[]
var layers: Array[Texture2DArray]=[]
var materials: Array[WeakRef]=[]
var pages := {}
var requests: Array=[]
var last_key := ""
var source_hash := ""
var camera_pixels := Vector2.ZERO
var span := Vector2.ONE
var image_size := 8192
var countdown := 0.0
var last_preview: Texture2D
var cache_hits := 0

func setup(owner_arena: Node) -> void:
	arena=owner_arena
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var metadata: Dictionary=arena.terrain_source.metadata
	camera_pixels=Vector2(metadata.camera_px[0],metadata.camera_px[1])/Vector2(metadata.w,metadata.h)
	span=Vector2(metadata.w,metadata.h)*float(metadata.m_per_px)
	for level in 3:
		var size: int=PAGE/(1<<level)+2
		var images: Array[Image]=[]
		for slot in SLOTS:
			var img := Image.create(size,size,false,Image.FORMAT_RGB8);img.fill(Color(.3,.4,.2));img.generate_mipmaps();images.append(img)
		var array := Texture2DArray.new();array.create_from_images(images);layers.append(array)
	bind_material(arena.terrain.material_override)
	bind_material(arena.far_terrain.material)

func bind_material(material: ShaderMaterial) -> void:
	for reference in materials:
		if reference.get_ref()==material: return
	materials.append(weakref(material))
	material.set_shader_parameter("satellite_enabled",true)
	material.set_shader_parameter("satellite_origin",camera_pixels)
	material.set_shader_parameter("satellite_span",span)
	for level in 3: material.set_shader_parameter("satellite_pages_"+str(level),layers[level])
	update_material(material)

func refresh_materials() -> void:
	for index in range(materials.size()-1,-1,-1):
		var material: ShaderMaterial=materials[index].get_ref()
		if material: update_material(material)
		else: materials.remove_at(index)

func update_material(material: ShaderMaterial) -> void:
	var rects := PackedVector4Array();var levels := PackedInt32Array()
	rects.resize(SLOTS);levels.resize(SLOTS);levels.fill(-1)
	for key in pages:
		var entry: Dictionary=pages[key]
		rects[entry.slot]=Vector4(key.x*PAGE,key.y*PAGE,PAGE,PAGE)
		levels[entry.slot]=entry.level
	material.set_shader_parameter("satellite_rects",rects);material.set_shader_parameter("satellite_levels",levels)
	if last_preview: material.set_shader_parameter("satellite_preview",last_preview);material.set_shader_parameter("satellite_preview_ready",true)

func _exit_tree() -> void:
	if worker: worker.wait_to_finish();worker=null

func _process(delta: float) -> void:
	if not arena: return
	if arena.ring_background.background_ready:
		var preview: Texture2D=arena.ring_background._mat.get_shader_parameter("sat_tex")
		if preview and preview!=last_preview:
			last_preview=preview
			refresh_materials()
	if worker and not worker.is_alive():
		var result: Dictionary=worker.wait_to_finish();worker=null
		source_hash=result.get("source_hash",source_hash);uploads=result.get("pages",[])
		cache_hits+=int(result.get("cache_hits",0))
	if not uploads.is_empty():
		var page: Dictionary=uploads.pop_front()
		var key: Vector2i=page.key
		var slot := -1
		if pages.has(key): slot=pages[key].slot
		else:
			for candidate in SLOTS:
				var owner: Variant=null
				for current in pages:
					if pages[current].slot==candidate: owner=current;break
				if owner==null: slot=candidate;break
				var needed := false
				for request in requests:
					if request.key==owner: needed=true;break
				if not needed: pages.erase(owner);slot=candidate;break
		if slot>=0:
			layers[page.level].update_layer(page.image,slot)
			pages[key]={"slot":slot,"level":page.level}
			refresh_materials()
	countdown-=delta
	if worker or not uploads.is_empty() or countdown>0: return
	countdown=.75
	var coordinates := Frame.coordinates(arena.camera.position)
	var uv := camera_pixels+Vector2(coordinates.x,-coordinates.z)/span
	var centre := Vector2i((uv*image_size/PAGE).floor())
	var focal: float=arena.get_viewport().get_visible_rect().size.y/(2*tan(deg_to_rad(arena.camera.fov)*.5))
	requests=[]
	var needed: Array=[]
	for z in range(-1,2):
		for x in range(-1,2):
			var key := centre+Vector2i(x,z)
			if key.x<0 or key.y<0 or key.x>=image_size/PAGE or key.y>=image_size/PAGE: continue
			var patch_centre := ((Vector2(key)*PAGE+Vector2.ONE*PAGE*.5)/image_size-camera_pixels)*span
			patch_centre.y=-patch_centre.y
			var d := (Vector2(coordinates.x,coordinates.z)-patch_centre).abs()-span/image_size*PAGE*.5
			var distance := maxf(1,maxf(Vector2(maxf(0,d.x),maxf(0,d.y)).length(),absf(coordinates.y)))
			var projected := span.x/image_size*focal/distance
			var level := 0 if projected>1.5 else (1 if projected>.65 else 2)
			var request := {"key":key,"level":level}
			requests.append(request)
			if not pages.has(key) or pages[key].level!=level: needed.append(request)
	if needed.is_empty() or arena.stream_jobs.size()>=2 or (arena.terrain_lod and arena.terrain_lod.worker) or arena.far_terrain.worker or arena.brushing: return
	worker=Thread.new()
	if worker.start(load_pages.bind(needed,source_hash))!=OK: worker=null;push_error("Satellite worker could not start")

static func load_pages(needed: Array, known_hash: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var tag := known_hash
	if tag.is_empty(): tag=FileAccess.get_sha256(SOURCE)
	var source: Image
	var output: Array=[];var hits := 0
	for request in needed:
		var path := FOLDER+(tag+str(request.key)+str(request.level)+"gutter-box-v1").sha256_text()+".png"
		var image := Image.new()
		if FileAccess.file_exists(path) and image.load(path)==OK: hits+=1
		else:
			if source==null:
				source=Image.new()
				if source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE))!=OK: return {"pages":[],"source_hash":tag}
				source.convert(Image.FORMAT_RGB8)
			var factor: int=1<<int(request.level)
			var origin: Vector2i=request.key*PAGE
			# A real source-pixel gutter prevents bilinear/mipmap tile-edge seams.
			var rect := Rect2i(origin-Vector2i.ONE*factor,Vector2i.ONE*(PAGE+2*factor))
			var clipped := rect.intersection(Rect2i(Vector2i.ZERO,source.get_size()))
			image=Image.create(rect.size.x,rect.size.y,false,Image.FORMAT_RGB8)
			image.blit_rect(source,clipped,clipped.position-rect.position)
			image.resize(PAGE/factor+2,PAGE/factor+2,Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8);image.save_png(path)
		image.generate_mipmaps()
		output.append({"key":request.key,"level":request.level,"image":image})
	return {"pages":output,"source_hash":tag,"cache_hits":hits}
