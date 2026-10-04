extends RefCounted
## Worker-only sampled-field/block cache. Mutex guards publication, never scene nodes.
const Recipe=preload("res://world/sdf_recipe.gd")
const Mesher=preload("res://world/tetra_mesher.gd")
const MAX_BYTES=32*1024*1024
var mutex := Mutex.new()
var entries := {}
var order: Array=[]
var bytes := 0

func pick_surface(start: Vector3, direction: Vector3, approximate_distance: float) -> Dictionary:
	# Picking the cached, edited surface does not wait for deferred physics shapes.
	mutex.lock();var snapshot := entries.values();mutex.unlock()
	var columns := {}
	for state in snapshot:
		if state.has("origin"): columns[Vector2i(floori(state.origin.x/32),floori(state.origin.z/32))]=state
	var last := maxf(0,approximate_distance-64)
	var previous := INF
	for distance in range(int(last),int(approximate_distance+96),2):
		var p := start+direction*distance
		var state: Dictionary=columns.get(Vector2i(floori(p.x/32),floori(p.z/32)),{})
		if state.is_empty() or p.y < -24 or p.y >64: previous=INF;last=distance;continue
		var dims: Vector3i=state.cells+Vector3i.ONE*3
		var grid_origin: Vector3=state.origin-Vector3.ONE*state.spacing
		var value := Recipe.Base.coarse_linear(p,grid_origin,state.values,dims.x,dims.y,state.spacing)
		if value<=0 and previous>0 and is_finite(previous):
			var lo: float=last;var hi: float=distance
			for i in 10:
				var mid := (lo+hi)*.5;var at := start+direction*mid
				var mid_state: Dictionary=columns.get(Vector2i(floori(at.x/32),floori(at.z/32)),state)
				var md: Vector3i=mid_state.cells+Vector3i.ONE*3
				var sample := Recipe.Base.coarse_linear(at,mid_state.origin-Vector3.ONE*mid_state.spacing,mid_state.values,md.x,md.y,mid_state.spacing)
				if sample>0: lo=mid
				else: hi=mid
			var hit := start+direction*(lo+hi)*.5
			return {"position":hit,"normal":normal(hit,state.values,grid_origin,dims,state.spacing)}
		previous=value;last=distance
	return {}

static func valid_state(state: Dictionary, cells: Vector3i) -> bool:
	if not state.get("origin") is Vector3 or state.get("cells")!=cells: return false
	if not state.get("spacing") is float or state.spacing<=0: return false
	var dims := cells+Vector3i.ONE*3
	for name in ["base","values"]:
		if not state.get(name) is PackedFloat32Array or state[name].size()!=dims.x*dims.y*dims.z: return false
	if not state.get("parts") is Dictionary or not state.get("kernels") is Dictionary: return false
	if not state.get("bytes") is int or state.bytes<0 or state.bytes>MAX_BYTES*4: return false
	if not state.get("features") is Array or not Recipe.validate(Recipe.document(state.features)): return false
	for part in state.parts.values():
		if not part is Dictionary: return false
		if not part.get("vertices") is PackedVector3Array or not part.get("normals") is PackedVector3Array or not part.get("indices") is PackedInt32Array: return false
		if part.vertices.size()!=part.normals.size() or part.indices.size()%3!=0: return false
		for index in part.indices:
			if index<0 or index>=part.vertices.size(): return false
	for kernel in state.kernels.values():
		if not kernel is PackedFloat32Array or kernel.size()!=dims.x*dims.z: return false
	return true

func restore(origin: Vector3, cells: Vector3i, spacing: float, radius: float, rough: float, state: Dictionary) -> void:
	var key := str(origin)+str(cells)+str(spacing)+str(radius)+str(rough)
	mutex.lock()
	# Undo/cache loads must replace a resident newer revision as well: picking
	# and the next incremental edit must see the restored, displayed field.
	if entries.has(key): bytes-=entries[key].bytes;order.erase(key)
	entries[key]=state;order.append(key);bytes+=state.bytes
	while bytes>MAX_BYTES and order.size()>1:
		var oldest: String=order.pop_front();bytes-=entries[oldest].bytes;entries.erase(oldest)
	mutex.unlock()

static func influence(f: Dictionary) -> Rect2:
	if f.has("amount") and f.kind in ["hill","lower"]:
		var radius: float=f.radius*maxf(1,float(f.get("aspect",1)))
		return Rect2(Vector2(f.x-radius,f.z-radius),Vector2.ONE*radius*2).grow(.1)
	return Recipe.bounds(f)

static func differences(old: Array, next: Array) -> Array:
	var areas := []
	for i in maxi(old.size(),next.size()):
		if i<old.size() and i<next.size() and old[i]==next[i]: continue
		if i<old.size(): areas.append(influence(old[i]))
		if i<next.size(): areas.append(influence(next[i]))
	return areas

static func normal(p: Vector3, values: PackedFloat32Array, origin: Vector3, dims: Vector3i, spacing: float) -> Vector3:
	var q := (p-origin)/spacing
	var c := Vector3i(floori(q.x),floori(q.y),floori(q.z))
	c=c.clamp(Vector3i.ZERO,dims-Vector3i.ONE*2)
	var f := q-Vector3(c)
	var i := (c.z*dims.y+c.y)*dims.x
	i+=c.x
	var row := dims.x;var slab := dims.x*dims.y
	var a:=values[i];var b:=values[i+1];var c0:=values[i+row];var d:=values[i+row+1]
	var e:=values[i+slab];var g:=values[i+slab+1];var h:=values[i+slab+row];var j:=values[i+slab+row+1]
	return Vector3(lerpf(lerpf(b-a,d-c0,f.y),lerpf(g-e,j-h,f.y),f.z),lerpf(lerpf(c0-a,d-b,f.x),lerpf(h-e,j-g,f.x),f.z),lerpf(lerpf(e-a,g-b,f.x),lerpf(h-c0,j-d,f.x),f.y)).normalized()

func build(origin: Vector3, cells: Vector3i, spacing: float, features: Array, radius: float, rough: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var key := str(origin)+str(cells)+str(spacing)+str(radius)+str(rough)
	mutex.lock()
	var cached: Dictionary=entries.get(key,{})
	# Packed arrays copy on write; immutable snapshots are safe for other jobs.
	var state := cached.duplicate()
	mutex.unlock()
	var warm := not state.is_empty()
	var dims := cells+Vector3i.ONE*3
	var grid_origin := origin-Vector3.ONE*spacing
	var count := dims.x*dims.y*dims.z
	var changed := differences(state.get("features",[]),features)
	var old_features: Array=state.get("features",[])
	var append_only := warm and features.size()>=old_features.size() and features.slice(0,old_features.size())==old_features
	# max(existing, sphere) is stable across float32 storage. Additive/blended
	# edits replay from base to avoid accumulating intermediate rounding error.
	for feature in features.slice(old_features.size()):
		if feature.kind!="carve" or feature.has("amount"): append_only=false;break
	var base: PackedFloat32Array=state.get("base",PackedFloat32Array())
	var values: PackedFloat32Array=state.get("values",PackedFloat32Array())
	var old_kernels: Dictionary=state.get("kernels",{})
	var kernels: Dictionary=old_kernels.duplicate() if append_only else {}
	var base_calls := 0;var touched := 0
	if not warm:
		base.resize(count);values.resize(count)
		for z in dims.z:
			for y in dims.y:
				for x in dims.x:
					var id := (z*dims.y+y)*dims.x+x
					base[id]=Recipe.Base.expanded_field(grid_origin+Vector3(x,y,z)*spacing,radius,rough)
		base_calls=count
	# Cache 2D brush kernels, reused across all vertical samples and dose changes.
	var compiled := []
	for feature in (features.slice(old_features.size()) if append_only else features):
		var item := {"feature":feature,"additive":feature.has("amount") and feature.kind in ["hill","lower"]}
		item.sphere=feature.kind=="carve" and not feature.has("amount")
		if item.sphere:
			item.center=Vector3(feature.x,feature.y,feature.z);item.area=Recipe.bounds(feature)
		if item.additive:
			var shape: Dictionary=feature.duplicate();shape.erase("amount");shape.erase("y");shape.erase("height")
			var kernel_key := JSON.stringify(shape)
			if old_kernels.has(kernel_key): kernels[kernel_key]=old_kernels[kernel_key]
			if not kernels.has(kernel_key):
				var weights := PackedFloat32Array();weights.resize(dims.x*dims.z)
				for z in dims.z:
					for x in dims.x:
						var p := (grid_origin+Vector3(x,0,z)*spacing-Vector3(feature.x,0,feature.z)).rotated(Vector3.UP,-deg_to_rad(feature.yaw))
						var q := Vector2(p.x,p.z/float(feature.get("aspect",1)))
						var distance := maxf(absf(q.x),absf(q.y)) if feature.get("shape","circle")=="square" else q.length()
						weights[z*dims.x+x]=1-smoothstep(0,feature.radius,distance)
				kernels[kernel_key]=weights
			item.weights=kernels[kernel_key]
		compiled.append(item)
	for z in dims.z:
		for x in dims.x:
			var point := Vector2(grid_origin.x+x*spacing,grid_origin.z+z*spacing)
			var dirty := not warm
			for area in changed:
				if area.has_point(point): dirty=true;break
			if not dirty: continue
			# Height strokes are constant down a column. Collapse consecutive
			# additions once, preserving ordering around non-additive operations.
			var column_ops := []
			var offset := 0.0
			for item in compiled:
				if item.additive:
					offset+=float(item.feature.amount)*item.weights[z*dims.x+x]*(-1 if item.feature.kind=="hill" else 1)
					continue
				if offset!=0: column_ops.append({"offset":offset});offset=0
				if not item.sphere or item.area.has_point(point): column_ops.append(item)
			if offset!=0: column_ops.append({"offset":offset})
			for y in dims.y:
				var id := (z*dims.y+y)*dims.x+x
				var p := grid_origin+Vector3(x,y,z)*spacing
				var value: float=values[id] if append_only else base[id]
				for item in column_ops:
					if item.has("offset"):
						value+=item.offset
					elif item.sphere:
						value=maxf(value,item.feature.radius-p.distance_to(item.center))
					else: value=Recipe.compose(p,value,[item.feature])
				values[id]=value;touched+=1
	var sampled_at := Time.get_ticks_usec()
	var parts: Dictionary=state.get("parts",{}).duplicate()
	var rebuilt := 0
	var dirty_blocks := []
	for z0 in range(0,cells.z,4):
		for x0 in range(0,cells.x,4):
			var block_key := Vector2i(x0,z0)
			var block_origin := origin+Vector3(x0,0,z0)*spacing
			var block_cells := Vector3i(mini(4,cells.x-x0),cells.y,mini(4,cells.z-z0))
			var area := Rect2(Vector2(block_origin.x,block_origin.z),Vector2(block_cells.x,block_cells.z)*spacing).grow(spacing+.1)
			var dirty := not parts.has(block_key)
			for edit in changed:
				if area.intersects(edit): dirty=true;break
			if not dirty: continue
			var samples := PackedFloat32Array()
			for z in block_cells.z+1:
				for y in block_cells.y+1:
					for x in block_cells.x+1: samples.append(values[((z0+z+1)*dims.y+y+1)*dims.x+x0+x+1])
			parts[block_key]=Mesher.build(Callable(),block_origin,block_cells,spacing,samples,normal.bind(values,grid_origin,dims,spacing))
			rebuilt+=1
			dirty_blocks.append(block_key)
	var vertices := PackedVector3Array();var normals := PackedVector3Array();var indices := PackedInt32Array()
	for part in parts.values():
		var offset := vertices.size();vertices.append_array(part.vertices);normals.append_array(part.normals)
		for index in part.indices: indices.append(offset+index)
	var footprint := base.size()*8+vertices.size()*24+indices.size()*4
	for kernel in kernels.values(): footprint+=kernel.size()*4
	state={"origin":origin,"cells":cells,"spacing":spacing,"base":base,"values":values,"features":features.duplicate(true),"parts":parts,"kernels":kernels,"bytes":footprint}
	mutex.lock()
	if entries.has(key): bytes-=entries[key].bytes;order.erase(key)
	entries[key]=state;bytes+=footprint;order.append(key)
	while bytes>MAX_BYTES and order.size()>1:
		var oldest: String=order.pop_front();bytes-=entries[oldest].bytes;entries.erase(oldest)
	mutex.unlock()
	return {"vertices":vertices,"normals":normals,"indices":indices,"dirty_blocks":dirty_blocks,"_field_state":state,"ms":(Time.get_ticks_usec()-started)/1000.0,"profile":{"warm_field":warm,"base_evaluations":base_calls,"updated_samples":touched,"rebuilt_blocks":rebuilt,"field_ms":(sampled_at-started)/1000.0,"field_cache_bytes":footprint}}
