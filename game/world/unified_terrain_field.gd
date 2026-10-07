extends RefCounted
## Immutable source snapshot shared by collision, distant meshes and normal caches.
const Recipe=preload("res://world/sdf_recipe.gd")
const Frame=preload("res://world/ring_frame.gd")
const PROTECTED_EXTENT := 768.0
const TRANSITION_END := 1536.0
var elevation := PackedByteArray()
var metadata := {}
var features: Array=[]
var source_hash := ""
var base_hash := ""

func setup(ordered_features: Array) -> bool:
	var meta: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://mocks/dem/millstreet.json"))
	if not meta is Dictionary: return false
	var data := FileAccess.get_file_as_bytes("res://mocks/dem/millstreet.r16")
	if data.size()!=int(meta.w)*int(meta.h)*2: return false
	metadata=meta; elevation=data; features=ordered_features.duplicate(true)
	var hashing := HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(data)
	base_hash=(hashing.finish().hex_encode()+JSON.stringify(metadata)+FileAccess.get_file_as_string("res://world/unified_terrain_field.gd")+Recipe.cache_key([],Vector3.ZERO,Vector3i.ONE,1,3,0)).sha256_text()
	source_hash=(base_hash+JSON.stringify(features)).sha256_text()
	return true

func snapshot(ordered_features: Array) -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy.elevation=elevation;copy.metadata=metadata;copy.base_hash=base_hash
	copy.features=ordered_features.duplicate(true)
	copy.source_hash=(base_hash+JSON.stringify(copy.features)).sha256_text()
	return copy

func filtered_height(arc: float, lateral: float, spacing: float) -> float:
	# A box-footprint approximation for distant elevation caches. Fine collision
	# always uses native bilinear samples. The full home source is only 28 MiB.
	if spacing<=float(metadata.m_per_px): return dem_height(arc,lateral)
	var offset := spacing*.25
	return (dem_height(arc-offset,lateral-offset)+dem_height(arc+offset,lateral-offset)+dem_height(arc-offset,lateral+offset)+dem_height(arc+offset,lateral+offset))*.25

func surface_height(point: Vector2, spacing := 0.0) -> float:
	var distance := maxf(absf(point.x),absf(point.y))
	var original := Recipe.Base.expanded_height(point)
	if distance<=PROTECTED_EXTENT: return original
	var weight := smoothstep(PROTECTED_EXTENT,TRANSITION_END,distance)
	var height := original
	var radius := Frame.CIRCUMFERENCE/TAU
	# Solve the radial DEM in the existing physical/tangent coordinates. All
	# consumers use this same mapping; models and saved edits are never moved.
	for iteration in 4:
		var arc := atan2(point.x,radius-height)*radius
		var dem := filtered_height(arc,point.y,spacing)
		if not is_finite(dem): return original
		var radial := radius-dem
		# Stable equivalent of radius-sqrt(radial^2-x^2).
		var bent := dem+point.x*point.x/(radial+sqrt(maxf(1,radial*radial-point.x*point.x)))
		height=lerpf(original,bent,weight)
	return height

func surface_normal(point: Vector2, footprint := 2.0) -> Vector3:
	var e := maxf(1,footprint*.5)
	return Vector3(surface_height(point-Vector2(e,0),footprint)-surface_height(point+Vector2(e,0),footprint),2*e,surface_height(point-Vector2(0,e),footprint)-surface_height(point+Vector2(0,e),footprint)).normalized()

func dem_height(arc: float, lateral: float) -> float:
	arc=wrapf(arc,-Frame.CIRCUMFERENCE*.5,Frame.CIRCUMFERENCE*.5)
	var x: float=float(metadata.camera_px[0])+arc/float(metadata.m_per_px)
	var z: float=float(metadata.camera_px[1])-lateral/float(metadata.m_per_px)
	if x<0 or z<0 or x>=int(metadata.w)-1 or z>=int(metadata.h)-1: return NAN
	var ix := floori(x);var iz := floori(z);var width := int(metadata.w)
	var a := float(elevation.decode_u16((iz*width+ix)*2))
	var b := float(elevation.decode_u16((iz*width+ix+1)*2))
	var c := float(elevation.decode_u16(((iz+1)*width+ix)*2))
	var d := float(elevation.decode_u16(((iz+1)*width+ix+1)*2))
	return lerpf(lerpf(a,b,x-ix),lerpf(c,d,x-ix),z-iz)/float(metadata.h_scale)

func base_field(p: Vector3, radius: float, rough: float) -> float:
	var local := Recipe.Base.expanded_field(p,radius,rough)
	var distance := maxf(absf(p.x),absf(p.z))
	# Exact early return preserves the complete 3D field, including cavities.
	if distance<=PROTECTED_EXTENT: return local
	return p.y-surface_height(Vector2(p.x,p.z))

func field(p: Vector3, radius: float, rough: float) -> float:
	# Authored operations are evaluated once, in their original tangent frame/order.
	return Recipe.compose(p,base_field(p,radius,rough),features)
