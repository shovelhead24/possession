extends RefCounted
## Ordered, serialisable features in metres in the arena's ring-tangent frame.
const Base = preload("res://world/sdf_arena_expanded.gd")
const TYPES = ["hill", "lower", "flatten", "carve", "ridge", "tunnel", "bridge"]

static func feature(kind: String, p: Vector3) -> Dictionary:
	return {"kind":kind,"x":p.x,"y":p.y,"z":p.z,"radius":16.0,"height":12.0,"length":48.0,"width":12.0,"thickness":4.0,"yaw":0.0,"bend":0.0}

static func bounds(f: Dictionary) -> Rect2:
	var reach: float = f.length*.5+absf(f.bend)+maxf(f.radius,f.width)+2.0
	return Rect2(Vector2(f.x-reach,f.z-reach),Vector2.ONE*reach*2)

static func relevant(features: Array, area: Rect2) -> Array:
	var result := []
	for f in features:
		if bounds(f).intersects(area): result.append(f.duplicate(true))
	return result

static func field(p: Vector3, radius: float, rough: float, features: Array) -> float:
	var d := Base.expanded_field(p,radius,rough)
	for f in features:
		if not bounds(f).has_point(Vector2(p.x,p.z)): continue
		var q := (p-Vector3(f.x,f.y,f.z)).rotated(Vector3.UP,-deg_to_rad(f.yaw))
		var radial := Vector2(q.x,q.z).length()
		var weight := 1.0-smoothstep(0.0,f.radius,radial)
		match f.kind:
			"hill":
				d=minf(d,maxf(p.y-(f.y+f.height*weight),radial-f.radius))
			"lower":
				d=maxf(d,-maxf(f.y-f.height*weight-p.y,radial-f.radius))
			"flatten":
				d=lerpf(d,p.y-f.y,weight)
			"carve":
				d=maxf(d,-(q.length()-f.radius))
			"ridge", "tunnel":
				# Quadratic spline, tessellated deterministically into eight capsules.
				var curve := INF
				var a := Vector3(-f.length*.5,0,0)
				for i in range(1,9):
					var t := i/8.0
					var b := Vector3(lerpf(-f.length*.5,f.length*.5,t),0,4*t*(1-t)*f.bend)
					var ab := b-a
					curve=minf(curve,(q-a-ab*clampf((q-a).dot(ab)/ab.length_squared(),0,1)).length()-f.radius)
					a=b
				d=minf(d,curve) if f.kind=="ridge" else maxf(d,-curve)
			"bridge":
				var deck := Base.box(q+Vector3(0,f.thickness*.5,0),Vector3(f.length*.5,f.thickness*.5,f.width*.5))
				for sign_value in [-1.0,1.0]:
					var support := Base.box(q-Vector3(sign_value*(f.length*.5-f.thickness),-f.height*.5,0),Vector3(f.thickness*.5,f.height*.5,f.width*.5))
					deck=minf(deck,support)
				d=minf(d,deck)
	return d

static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or data.get("frame")!="arena-ring-tangent-metres" or not data.get("features") is Array: return false
	if data.features.size()>2048: return false
	for f in data.features:
		if not f is Dictionary or f.get("kind") not in TYPES: return false
		for key in ["x","y","z","radius","height","length","width","thickness","yaw","bend"]:
			if not f.get(key) is float and not f.get(key) is int: return false
			if not is_finite(float(f[key])) or absf(f[key])>100000: return false
		for key in ["radius","height","length","width","thickness"]:
			if f[key]<1: return false
	return true

static func document(features: Array) -> Dictionary:
	return {"schema":1,"frame":"arena-ring-tangent-metres","features":features.duplicate(true)}

static func save_recipe(path: String, features: Array) -> Error:
	var data := document(features)
	if not validate(data): return ERR_INVALID_DATA
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t"));file.close()
	return DirAccess.rename_absolute(path+".tmp",path)

static func cache_key(features: Array, origin: Vector3, cells: Vector3i, spacing: float, radius: float, rough: float) -> String:
	var source := FileAccess.get_file_as_string("res://world/sdf_recipe.gd")+FileAccess.get_file_as_string("res://world/sdf_arena_expanded.gd")+FileAccess.get_file_as_string("res://world/sdf_demo.gd")+FileAccess.get_file_as_string("res://world/tetra_mesher.gd")
	return (source+str(Engine.get_version_info())+JSON.stringify(features)+str(origin)+str(cells)+str(spacing)+str(radius)+str(rough)).sha256_text()
