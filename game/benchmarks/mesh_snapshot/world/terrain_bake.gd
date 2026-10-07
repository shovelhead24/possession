extends RefCounted
## Disposable single-tile runtime cache. Editable JSON remains authoritative.
const VERSION := 2
const KEY_PRECISION_METRES := 0.000001

static func revision(heights: PackedFloat64Array, n: int, step: float, center: Vector2, radius: float, uv_repeat: float) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes([VERSION,n,step,center,radius,uv_repeat]))
	# JSON float round-trips can differ around 1e-14 m. Cache identity uses
	# micrometre quantization, far below the mesh/physics precision here.
	var quantized := PackedInt64Array()
	quantized.resize(heights.size())
	for i in heights.size():
		quantized[i] = roundi(heights[i]/KEY_PRECISION_METRES)
	hash.update(quantized.to_byte_array())
	return hash.finish().hex_encode()

static func levels(heights: PackedFloat64Array, n: int, step: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stride := 1
	while stride <= n-1:
		var width := (n-1)/stride+1
		var field := PackedFloat32Array()
		field.resize(width*width)
		for z in width:
			for x in width:
				var sx := x*stride
				var sz := z*stride
				# Preserve boundary samples; box-filter interiors from the full
				# source (never cascade rounding between levels).
				var total := 0.0
				var count := 0
				var reach := stride/2 if x > 0 and z > 0 and x < width-1 and z < width-1 else 0
				for dz in range(-reach,reach+1):
					for dx in range(-reach,reach+1):
						total += heights[(sz+dz)*n+sx+dx]
						count += 1
				field[z*width+x] = total/count
		var error := 0.0
		for z in n:
			for x in n:
				var px := minf(float(x)/stride,width-1.000001)
				var pz := minf(float(z)/stride,width-1.000001)
				var ix := floori(px)
				var iz := floori(pz)
				var u := px-ix
				var v := pz-iz
				var i := iz*width+ix
				var h: float
				if u+v <= 1:
					h = field[i]*(1-u-v)+field[i+1]*u+field[i+width]*v
				else:
					h = field[i+width+1]*(u+v-1)+field[i+width]*(1-u)+field[i+1]*(1-v)
				error = maxf(error,absf(h-heights[z*n+x]))
		result.append({"width":width,"spacing_m":step*stride,"heights":field,"height_error_m":error})
		stride *= 2
	return result

static func read_cache(path: String, key: String, n: int) -> Resource:
	if not FileAccess.file_exists(path):
		return null
	var data := ResourceLoader.load(path,"Resource",ResourceLoader.CACHE_MODE_IGNORE)
	if data == null or data.get_meta("revision","") != key:
		return null
	for field in ["mesh","collision","vertices","levels"]:
		if not data.has_meta(field):
			return null
	if not data.get_meta("mesh",null) is ArrayMesh or not data.get_meta("collision",null) is ConcavePolygonShape3D:
		return null
	var vertices = data.get_meta("vertices",null)
	var pyramid = data.get_meta("levels",null)
	if not vertices is PackedVector3Array or vertices.size() != n*n or not pyramid is Array or pyramid.is_empty():
		return null
	var width := n
	for level in pyramid:
		if not level is Dictionary or level.get("width",0) != width:
			return null
		var field = level.get("heights",null)
		if not field is PackedFloat32Array or field.size() != width*width:
			return null
		width = (width-1)/2+1
	if pyramid[-1].width != 2:
		return null
	return data

static func write_cache(path: String, key: String, heights: PackedFloat64Array, n: int, step: float,
		vertices: PackedVector3Array, mesh: ArrayMesh, collision: ConcavePolygonShape3D) -> bool:
	var data := Resource.new()
	data.set_meta("revision",key)
	data.set_meta("version",VERSION)
	data.set_meta("levels",levels(heights,n,step))
	data.set_meta("vertices",vertices)
	data.set_meta("mesh",mesh)
	data.set_meta("collision",collision)
	data.set_meta("bounds",mesh.get_aabb())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var pending := path.get_basename()+".pending.res"
	if ResourceSaver.save(data,pending,ResourceSaver.FLAG_COMPRESS) != OK:
		return false
	# Validate before installing. A failed bake never changes source JSON.
	if read_cache(pending,key,n) == null:
		return false
	return DirAccess.rename_absolute(pending,path) == OK
