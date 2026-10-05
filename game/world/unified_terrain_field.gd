extends RefCounted
## Sampling prototype only: workshop publication is deliberately not switched yet.
const Recipe=preload("res://world/sdf_recipe.gd")
const Frame=preload("res://world/ring_frame.gd")
const PROTECTED_EXTENT := 768.0
const TRANSITION_END := 1536.0
var elevation := PackedByteArray()
var metadata := {}
var features: Array=[]
var source_hash := ""

func setup(ordered_features: Array) -> bool:
	var meta: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://mocks/dem/millstreet.json"))
	if not meta is Dictionary: return false
	var data := FileAccess.get_file_as_bytes("res://mocks/dem/millstreet.r16")
	if data.size()!=int(meta.w)*int(meta.h)*2: return false
	metadata=meta; elevation=data; features=ordered_features.duplicate(true)
	var hashing := HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(data)
	source_hash=(hashing.finish().hex_encode()+JSON.stringify(metadata)+JSON.stringify(features)+FileAccess.get_file_as_string("res://world/unified_terrain_field.gd")+Recipe.cache_key([],Vector3.ZERO,Vector3i.ONE,1,3,0)).sha256_text()
	return true

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
	var coordinates := Frame.coordinates(p)
	var height := dem_height(coordinates.x,coordinates.z)
	if not is_finite(height): return local
	return lerpf(local,coordinates.y-height,smoothstep(PROTECTED_EXTENT,TRANSITION_END,distance))

func field(p: Vector3, radius: float, rough: float) -> float:
	# Authored operations are evaluated once, in their original tangent frame/order.
	return Recipe.compose(p,base_field(p,radius,rough),features)
