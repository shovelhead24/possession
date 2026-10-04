extends RefCounted
## Derived, bounded height displacement; recipes (not this grid) are authoritative.
## Run on terrain workers. Same feature-domain grid is shared by all chunks.
const SIZE := 49
static var mutex := Mutex.new()
static var cache := {}

static func grid(f: Dictionary) -> PackedFloat32Array:
	var settings := f.duplicate();settings.erase("x");settings.erase("y");settings.erase("z")
	var key := JSON.stringify(settings)
	mutex.lock();var found: PackedFloat32Array=cache.get(key,PackedFloat32Array());mutex.unlock()
	if not found.is_empty(): return found
	var result := generate(f)
	mutex.lock()
	if cache.size()>=24: cache.erase(cache.keys()[0]) # RAM only; never purge disk meshes.
	cache[key]=result;mutex.unlock()
	return result

static func generate(f: Dictionary) -> PackedFloat32Array:
	var noise := FastNoiseLite.new();noise.seed=int(f.get("seed",1))
	noise.noise_type=FastNoiseLite.TYPE_PERLIN if f.get("noise","ridged")=="perlin" else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency=1.0/float(f.get("wavelength",24.0))
	noise.fractal_type=FastNoiseLite.FRACTAL_RIDGED if f.get("noise","ridged")=="ridged" else FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves=int(f.get("octaves",4));noise.fractal_gain=float(f.get("roughness",.5))
	var h := PackedFloat32Array();h.resize(SIZE*SIZE)
	var cell: float=2.0*f.radius/(SIZE-1)
	for z in SIZE:
		for x in SIZE:
			var p: Vector2=Vector2(x,z)*cell-Vector2.ONE*f.radius
			var envelope := pow(maxf(0,1-p.length()/f.radius),.7)
			var n := clampf(noise.get_noise_2d(p.x,p.y)*.5+.5,0,1)
			h[z*SIZE+x]=f.height*envelope*(.25+.75*n)
	var water := PackedFloat32Array();water.resize(h.size())
	var sediment := PackedFloat32Array();sediment.resize(h.size())
	var rain := float(f.get("water",.4));var wind := float(f.get("wind",.2))
	var angle := deg_to_rad(float(f.get("wind_direction",0)))
	var direction := Vector2i(roundi(cos(angle)),roundi(sin(angle)))
	# Explicit conservative flux updates: do not read neighbours already updated
	# this iteration. Sediment is transported with water and deposited on slowdown.
	for iteration in int(f.get("erosion_steps",20)):
		var next_h := h.duplicate();var next_water := water.duplicate();var next_sediment := sediment.duplicate()
		for z in range(1,SIZE-1):
			for x in range(1,SIZE-1):
				var i := z*SIZE+x
				if Vector2(x-(SIZE-1)*.5,z-(SIZE-1)*.5).length()>(SIZE-1)*.5-1: continue
				var available := water[i]+rain*.08
				next_water[i]+=rain*.08
				var target := i;var drop := 0.0
				for j in [i-1,i+1,i-SIZE,i+SIZE]:
					var slope := h[i]+water[i]-h[j]-water[j]
					if slope>drop: drop=slope;target=j
				var flow := minf(available*.5,drop*.25)
				var carried := sediment[i]*flow/maxf(available,.0001)
				var capacity := flow*drop*.6
				var eroded := minf(maxf(0,capacity-sediment[i])*.2,h[i]*.03)*rain
				var deposited := maxf(0,sediment[i]-capacity)*.2
				next_h[i]+=deposited-eroded
				next_sediment[i]+=eroded-deposited-carried;next_sediment[target]+=carried
				next_water[i]-=flow;next_water[target]+=flow
				var downwind := (z+direction.y)*SIZE+x+direction.x
				# Directional talus transport: wind removes exposed slopes and
				# deposits material downwind. This is a stylised erosion model.
				var blown := minf(maxf(0,h[i]-h[downwind]-cell*.15)*.03*wind,h[i]*.02)
				next_h[i]-=blown;next_h[downwind]+=blown
		for i in h.size():
			next_water[i]=maxf(0,next_water[i])*.92
			next_sediment[i]=maxf(0,next_sediment[i])
		h=next_h;water=next_water;sediment=next_sediment
	for z in SIZE:
		for x in SIZE:
			var i := z*SIZE+x
			# Compact, smooth support; no chunk-local simulation boundaries.
			var r := Vector2(x-(SIZE-1)*.5,z-(SIZE-1)*.5).length()/((SIZE-1)*.5)
			h[i]=maxf(0,h[i]+sediment[i])*(1-smoothstep(.8,1,r))
	return h

static func sample(f: Dictionary, p: Vector2, heights: PackedFloat32Array) -> float:
	var q: Vector2=(p-Vector2(f.x,f.z)+Vector2.ONE*f.radius)/(2*f.radius)*(SIZE-1)
	if q.x<0 or q.y<0 or q.x>=SIZE-1 or q.y>=SIZE-1: return 0
	var x := floori(q.x);var z := floori(q.y);var i := z*SIZE+x
	return lerpf(lerpf(heights[i],heights[i+1],q.x-x),lerpf(heights[i+SIZE],heights[i+SIZE+1],q.x-x),q.y-z)
