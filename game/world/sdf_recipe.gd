extends RefCounted
## Ordered, serialisable features in metres in the arena's ring-tangent frame.
const Base = preload("res://world/sdf_arena_expanded.gd")
const TYPES = ["hill", "lower", "flatten", "carve", "ridge", "tunnel", "bridge"]

static func feature(kind: String, p: Vector3) -> Dictionary:
	return {"kind":kind,"x":p.x,"y":p.y,"z":p.z,"radius":16.0,"height":12.0,"length":48.0,"width":12.0,"thickness":4.0,"yaw":0.0,"bend":0.0}

static func bounds(f: Dictionary) -> Rect2:
	if f.has("end_x"):
		return Rect2(Vector2(f.x,f.z),Vector2.ZERO).expand(Vector2(f.end_x,f.end_z)).grow(f.radius+2)
	var reach: float = f.length*.5+absf(f.bend)+maxf(f.radius,f.width)+2.0
	reach=maxf(reach,f.radius*float(f.get("aspect",1))+2)
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
		var before := d
		var q := (p-Vector3(f.x,f.y,f.z)).rotated(Vector3.UP,-deg_to_rad(f.yaw))
		var brush_q := Vector2(q.x,q.z/float(f.get("aspect",1)))
		var radial := maxf(absf(brush_q.x),absf(brush_q.y)) if f.get("shape","circle")=="square" else brush_q.length()
		var weight := 1.0-smoothstep(0.0,f.radius,radial)
		# Brush height deltas compose additively; later strokes never move an old cut.
		if f.has("amount") and f.kind in ["hill","lower"]:
			d += float(f.amount)*weight*(-1.0 if f.kind=="hill" else 1.0)
			continue
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
				if f.has("end_x"):
					var a := Vector3(f.x,f.y,f.z);var b := Vector3(f.end_x,f.end_y,f.end_z)
					var axis := b-a;var length := maxf(axis.length(),.01);axis/=length
					var relative := p-(a+b)*.5
					var axial := relative.dot(axis)
					var distance := Vector2((relative-axis*axial).length()-f.radius,absf(axial)-length*.5)
					var cylinder := distance.max(Vector2.ZERO).length()+minf(maxf(distance.x,distance.y),0)
					d=maxf(d,-cylinder) if f.kind=="tunnel" else minf(d,cylinder)
					continue
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
		if f.has("amount"): d=lerpf(before,d,1.0-exp(-float(f.amount)))
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
		if f.has("amount"):
			if not f.amount is float and not f.amount is int: return false
			if not is_finite(float(f.amount)) or f.amount<0 or f.amount>100000: return false
		if f.get("shape","circle") not in ["circle","square","ellipse"]: return false
		if not f.get("aspect",1) is float and not f.get("aspect",1) is int: return false
		if not is_finite(float(f.get("aspect",1))) or f.get("aspect",1)<.1 or f.get("aspect",1)>10: return false
		if f.has("end_x") or f.has("end_y") or f.has("end_z"):
			for key in ["end_x","end_y","end_z"]:
				if not f.get(key) is float and not f.get(key) is int: return false
				if not is_finite(float(f[key])) or absf(f[key])>100000: return false
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
