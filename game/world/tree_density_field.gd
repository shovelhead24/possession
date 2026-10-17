extends RefCounted
## Authored planar canopy field. Independent of camera, grounding and streaming.
const Budget=preload("res://world/tree_foliage_budget.gd")
const VERSION=1
var radii := {}
var entries := {}
var areas := {}
var coverage := {}
var pending := {}
var revision := 0
var last_cells := 0
var loaded_cache := false
func configure(names: Array, values: Array) -> void:
	for i in names.size(): radii[names[i]]=values[i]
func neighbours(cell: Vector2i) -> Array:
	var result=[]
	for x in range(-1,2):
		for y in range(-1,2):
			var c=cell+Vector2i(x,y);c.x=wrapi(c.x,-62500,62500);result.append(c)
	return result
func mark(cell: Vector2i) -> void:
	for c in neighbours(cell): pending[c]=true
func upsert(record: Dictionary) -> void:
	var cell=Budget.cell_at(Vector2(record.x,record.z))
	var radius: float=radii.get(record.species,0.0)*record.height
	var entry={"cell":cell,"area":PI*radius*radius}
	if entries.get(record.id)==entry: return
	remove(record.id)
	entries[record.id]=entry;areas[cell]=areas.get(cell,0.0)+entry.area;mark(cell)
func remove(id: int) -> void:
	if not entries.has(id): return
	var old: Dictionary=entries[id];var cell: Vector2i=old.cell
	areas[cell]=maxf(0,areas.get(cell,0.0)-old.area)
	if areas[cell]<0.000001: areas.erase(cell)
	entries.erase(id);mark(cell)
func sync(records: Array, flush_now := true) -> void:
	var seen={}
	for record in records: seen[record.id]=true;upsert(record)
	for id in entries.keys():
		if not seen.has(id): remove(id)
	if flush_now: flush()
func flush() -> void:
	last_cells=pending.size()
	if pending.is_empty(): return
	for cell in pending:
		var total=0.0
		for c in neighbours(cell): total+=areas.get(c,0.0)
		if total>0: coverage[cell]=total/(9.0*Budget.CELL*Budget.CELL)
		else: coverage.erase(cell)
	pending.clear();revision+=1;loaded_cache=false
func multiplier(point: Vector2) -> float:
	return 1.0+clampf((coverage.get(Budget.cell_at(point),0.0)-.5)*.45,0.0,.65)
func fingerprint() -> String:
	var values=[];var ids=entries.keys();ids.sort()
	for id in ids:
		var e: Dictionary=entries[id];values.append([id,e.cell.x,e.cell.y,roundi(e.area*1000000)])
	return (JSON.stringify([VERSION,Budget.CELL,radii,values])).sha256_text()
func save_cache(path: String) -> bool:
	flush()
	var rows=[]
	for cell in coverage: rows.append([cell.x,cell.y,coverage[cell]])
	var f=FileAccess.open(path+".pending",FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify({"version":VERSION,"fingerprint":fingerprint(),"payload":JSON.stringify(rows),"checksum":JSON.stringify(rows).sha256_text()}));f.flush()
	var error=f.get_error();f.close()
	return error==OK and DirAccess.rename_absolute(path+".pending",path)==OK
func load_cache(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var doc=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or doc.get("version")!=VERSION or doc.get("fingerprint")!=fingerprint() or not doc.get("payload") is String: return false
	if doc.get("checksum")!=doc.payload.sha256_text(): return false
	var rows=JSON.parse_string(doc.payload)
	if not rows is Array: return false
	var loaded={}
	for row in rows:
		if not row is Array or row.size()!=3: return false
		for value in row:
			if not (value is float or value is int) or not is_finite(value): return false
		if row[2]<0: return false
		loaded[Vector2i(row[0],row[1])]=float(row[2])
	coverage=loaded;pending.clear();last_cells=0;revision+=1;loaded_cache=true;return true
func report() -> Dictionary:
	flush()
	var hotspots=[]
	for cell in areas:
		var overlap: float=coverage.get(cell,0.0)
		if overlap>.5: hotspots.append({"arc_m":(cell.x+.5)*Budget.CELL,"lateral_m":(cell.y+.5)*Budget.CELL,"canopy_coverage":overlap,"status":"Needs measured view / route check"})
	hotspots.sort_custom(func(a,b): return a.canopy_coverage>b.canopy_coverage)
	return {"trees":entries.size(),"occupied_cells":areas.size(),"dense_cells":hotspots.size(),"hotspots":hotspots.slice(0,32),"target_ms":1000.0/120.0,"note":"Density is a screening estimate, not occlusion or a frame-rate result. Inspect hot spots from gameplay height with shadows and combat active."}
