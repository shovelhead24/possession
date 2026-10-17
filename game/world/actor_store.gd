extends RefCounted
const KINDS := ["squad","grunt","captain","trex","warthog","tank","crate"]
const Ring=preload("res://world/terrain_drive_ring.gd")
var records: Array=[]
var next_id := 1
var undo_stack: Array=[]
var redo_stack: Array=[]
var saved := "[]"
var current := "[]"
var path := ""
var base := ""
var notice := "Choose an actor to place."
var revision := 0

func make(kind: String, point: Vector3) -> Dictionary:
	var c=Ring.coordinates(point)
	var r={"id":next_id,"kind":kind,"p":[c.x,c.y,c.z],"yaw":0.0,"mode":0,"speed":9.0 if kind=="trex" else (8.0 if kind in ["warthog","tank"] else 1.25),"wait":0.0,"loop":true,"route":[],"enabled":true}
	next_id+=1;return r
static func point(p: Array) -> Vector3: return Ring.point(p[0],p[1],p[2])
static func coordinate(p: Vector3) -> Array:
	var c=Ring.coordinates(p);return [c.x,c.y,c.z]
static func modes(kind: String) -> Array:
	if kind=="crate": return ["Heavy physics crate (160 kg)"]
	if kind=="trex": return ["Auto: patrol + hunt","Patrol only","Hunt","Hold position"]
	if kind in ["warthog","tank"]: return ["Parked / drivable","Patrol / drivable"]
	return ["Patrol + combat response","Guard + combat response","Patrol only (no firing)"]

func snapshot() -> Array: return records.duplicate(true)
func signature() -> String: return JSON.stringify(records,"",true,true)
func unsaved() -> bool: return current!=saved
func commit(before: Array) -> void:
	if before==records: return
	undo_stack.append(before)
	if undo_stack.size()>64: undo_stack.pop_front()
	redo_stack.clear();revision+=1;current=signature()
func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(snapshot());records=undo_stack.pop_back();revision+=1;current=signature();notice="Actors undone."
func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(snapshot());records=redo_stack.pop_back();revision+=1;current=signature();notice="Actors redone."
func find(id: int) -> Dictionary:
	for record in records:
		if record.id==id: return record
	return {}
func erase(ids: Array) -> void:
	var before := snapshot();records=records.filter(func(r): return r.id not in ids);commit(before)
func save() -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	if not file: notice="Actors save failed: cannot write file.";return false
	file.store_string(JSON.stringify({"schema":1,"base":base,"frame":"terrain-drive-ring-metres","actors":records},"\t",true,true));file.flush()
	var error := file.get_error();file.close()
	if error!=OK: notice="Actors save failed while writing.";return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK: notice="Actors save failed: backup unavailable.";return false
	if DirAccess.rename_absolute(path+".pending",path)!=OK: notice="Actors save failed: replacement unavailable.";return false
	current=signature();saved=current;notice="Saved %d actors." % records.size();return true
func load_saved(initial := false) -> bool:
	if not FileAccess.file_exists(path): notice="No saved actor yet.";return false
	var doc: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or doc.get("schema")!=1 or doc.get("base")!=base or doc.get("frame")!="terrain-drive-ring-metres" or not doc.get("actors") is Array:
		notice="Invalid actor save; current layout retained.";return false
	var ids := {};var loaded := [];var high := next_id
	for r in doc.actors:
		if not valid_record(r) or ids.has(int(r.id)):
			notice="Invalid actor record; current layout retained.";return false
		ids[int(r.id)]=true;r.id=int(r.id);r.mode=int(r.mode)
		high=maxi(high,int(r.id)+1);loaded.append(r)
	var before := snapshot();records=loaded;next_id=high
	if not initial: commit(before)
	else: revision+=1
	current=signature();saved=current;notice="Loaded %d actors." % records.size();return true
static func vector_valid(p: Variant) -> bool:
	if not p is Array or p.size()!=3: return false
	for v in p:
		if not (v is int or v is float) or not is_finite(float(v)): return false
	return absf(p[0])<=1500001 and absf(p[1])<=100000 and absf(p[2])<=50000
static func valid_record(r: Variant) -> bool:
	if not r is Dictionary or r.get("kind") not in KINDS or not vector_valid(r.get("p")): return false
	for key in ["id","mode","yaw","speed","wait"]:
		var v=r.get(key)
		if not (v is int or v is float) or not is_finite(float(v)): return false
	if r.id<1 or r.id!=int(r.id) or r.mode!=int(r.mode) or r.mode<0 or r.mode>=modes(r.kind).size(): return false
	if absf(r.yaw)>360 or r.speed<.1 or r.speed>24 or r.wait<0 or r.wait>300: return false
	if not r.get("enabled") is bool or not r.get("loop") is bool or not r.get("route") is Array: return false
	for p in r.route:
		if not vector_valid(p): return false
	return true
