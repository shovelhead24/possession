extends RefCounted
## Vertical-slice rendering budget. Density changes detail, never visibility/collision.
const CELL=24.0
const HALF_RING=1500000.0
var enabled := true
var radii: Array[float]=[]
var dense_adjusted := 0
var budget_adjusted := 0
var update_usec := 0
var indexed_count := -1
var indexed_items: Array=[]
var multipliers := {}
var valid_indices := PackedInt32Array()
var positions := PackedVector3Array()
var heights := PackedFloat32Array()
var density := PackedFloat32Array()
var distances := PackedFloat32Array()
var authored_field: RefCounted
var field_revision := -1
func configure(variants: Dictionary, names: Array) -> void:
	radii.clear()
	for species in names:
		var box: AABB=variants[species][0].get_aabb()
		radii.append(maxf(box.size.x,box.size.z)*.5)
static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(wrapf(point.x,-HALF_RING,HALF_RING)/CELL),floori(point.y/CELL))
static func lod_for(distance: float, previous: int) -> int:
	var boundaries=[14.0,38.0,95.0]
	var desired=0 if distance<14 else (1 if distance<38 else (2 if distance<95 else 3))
	if previous>=0 and absi(previous-desired)==1 and absf(distance-boundaries[mini(previous,desired)])<3: return previous
	return desired
func invalidate() -> void:
	indexed_count=-1
func index_density(items: Array, count: int) -> void:
	var cells={};multipliers.clear();valid_indices.clear()
	positions.resize(count);heights.resize(count);density.resize(count)
	for i in count:
		var item: Dictionary=items[i]
		if not item.valid: continue
		valid_indices.append(i);positions[i]=item.transform.origin;heights[i]=item.height
		if authored_field: continue
		var cell=cell_at(item.point)
		var radius: float=radii[item.variant]*item.height
		cells[cell]=cells.get(cell,0.0)+PI*radius*radius
	for cell in cells:
		var coverage=0.0
		for x in range(-1,2):
			for y in range(-1,2):
				var c: Vector2i=cell+Vector2i(x,y);c.x=wrapi(c.x,-62500,62500)
				coverage+=cells.get(c,0.0)
		coverage/=9.0*CELL*CELL
		multipliers[cell]=1.0+clampf((coverage-.5)*.45,0.0,.65)
	for i in valid_indices: density[i]=authored_field.multiplier(items[i].point) if authored_field else multipliers.get(cell_at(items[i].point),1.0)
	if authored_field: field_revision=authored_field.revision
	indexed_count=count;indexed_items=items
func select(items: Array, count: int, camera: Camera3D) -> PackedInt32Array:
	var began=Time.get_ticks_usec();dense_adjusted=0;budget_adjusted=0
	if indexed_count!=count or not is_same(indexed_items,items) or (authored_field and field_revision!=authored_field.revision): index_density(items,count)
	var result=PackedInt32Array();result.resize(count);result.fill(-1)
	distances.resize(count);distances.fill(INF)
	var detail=[];var position=camera.global_position;var forward=-camera.global_basis.z
	for i in valid_indices:
		var origin: Vector3=positions[i]
		var distance_squared: float=origin.distance_squared_to(position)
		distances[i]=distance_squared
		if distance_squared>650.0*650.0: continue
		var height: float=heights[i]
		# Most resident trees are distant impostors. Avoid density/ranking work for them.
		if distance_squared>96.04*height*height and distance_squared>=18.0*18.0: result[i]=3;continue
		var distance=sqrt(distance_squared);var scaled=distance*10.0/height
		var item: Dictionary=items[i]
		var base=lod_for(scaled,item.lod)
		var multiplier: float=density[i]
		var effective=scaled*(1.0 if distance<10 else multiplier)
		var desired=lod_for(effective,item.lod)
		if distance<18: desired=mini(desired,2)
		if desired>base: dense_adjusted+=1
		result[i]=desired
		if desired<=1:
			var view_weight=1.0 if (origin-position).dot(forward)>=0 else 1.5
			var score=effective*view_weight*(.9 if item.lod<=1 and item.lod>=0 else 1.0)
			detail.append({"index":i,"score":score,"id":item.get("id",i)})
	detail.sort_custom(func(a,b): return a.score<b.score if a.score!=b.score else a.id<b.id)
	var high=0;var medium=0
	for entry in detail:
		var desired=result[entry.index];var original=desired
		if desired==0:
			if high<4: high+=1
			else: desired=1
		if desired==1:
			if medium<20: medium+=1
			else: desired=2
		if desired!=original: budget_adjusted+=1
		result[entry.index]=desired
	update_usec=Time.get_ticks_usec()-began
	return result
