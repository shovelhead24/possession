extends RefCounted
const Parts=preload("res://world/forge_parts.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
var records: Array=[]
var next_id := 1
var undo_stack: Array=[]
var redo_stack: Array=[]
var saved := "[]"
var current := "[]"
var path := ""
var base := ""
var notice := "Choose a part to start building."
var revision := 0

static func pose(record: Dictionary) -> Transform3D:
	var p := Ring.point(record.p[0],record.p[1],record.p[2])
	var b: Array=record.b
	return Transform3D(Ring.tangent_basis(p,0)*Basis(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5]),Vector3(b[6],b[7],b[8])),p)

static func set_pose(record: Dictionary, transform: Transform3D) -> void:
	var coord := Ring.coordinates(transform.origin)
	var b := Ring.tangent_basis(transform.origin,0).inverse()*transform.basis.orthonormalized()
	record.p=[coord.x,coord.y,coord.z];record.b=[b.x.x,b.x.y,b.x.z,b.y.x,b.y.y,b.y.z,b.z.x,b.z.y,b.z.z]

func make(kind: String, transform: Transform3D, finish := 0) -> Dictionary:
	var record := {"id":next_id,"kind":kind,"finish":finish,"group":0};next_id+=1;set_pose(record,transform);return record

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
	redo_stack.append(snapshot());records=undo_stack.pop_back();revision+=1;current=signature();notice="Construction undone."
func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(snapshot());records=redo_stack.pop_back();revision+=1;current=signature();notice="Construction redone."
func find(id: int) -> Dictionary:
	for record in records:
		if record.id==id: return record
	return {}
func expanded(ids: Array) -> Array:
	var groups := {};var result := ids.duplicate()
	for record in records:
		if record.id in ids and record.group>0: groups[record.group]=true
	for record in records:
		if groups.has(record.group) and record.id not in result: result.append(record.id)
	return result
func transform_selection(ids: Array, delta: Transform3D) -> void:
	var before := snapshot()
	for record in records:
		if record.id in ids: set_pose(record,delta*pose(record))
	commit(before)
func join(ids: Array) -> void:
	if ids.size()<2: notice="Shift-click at least two parts to join.";return
	var before := snapshot();var group := next_id;next_id+=1
	for record in records:
		if record.id in ids: record.group=group
	commit(before);notice="Joined %d parts. Move or rotate any member as one group." % ids.size()
func unjoin(ids: Array) -> void:
	var before := snapshot()
	for record in records:
		if record.id in ids: record.group=0
	commit(before);notice="Group separated."
func erase(ids: Array) -> void:
	var before := snapshot();records=records.filter(func(r): return r.id not in ids);commit(before)
func save() -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	if not file: notice="Construction save failed: cannot write file.";return false
	file.store_string(JSON.stringify({"schema":1,"base":base,"frame":"terrain-drive-ring-metres","parts":records},"\t",true,true));file.flush()
	var error := file.get_error();file.close()
	if error!=OK: notice="Construction save failed while writing.";return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK: notice="Construction save failed: backup unavailable.";return false
	if DirAccess.rename_absolute(path+".pending",path)!=OK: notice="Construction save failed: replacement unavailable.";return false
	current=signature();saved=current;notice="Saved %d construction parts." % records.size();return true
func load_saved(initial := false) -> bool:
	if not FileAccess.file_exists(path): notice="No saved construction yet.";return false
	var doc: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or doc.get("schema")!=1 or doc.get("base")!=base or doc.get("frame")!="terrain-drive-ring-metres" or not doc.get("parts") is Array:
		notice="Invalid construction save; current layout retained.";return false
	var ids := {};var loaded := [];var high := next_id
	for r in doc.parts:
		if not valid_record(r) or ids.has(int(r.id)):
			notice="Invalid construction part; current layout retained.";return false
		ids[int(r.id)]=true;r.id=int(r.id);r.group=int(r.group);r.finish=int(r.finish)
		high=maxi(high,maxi(r.id,r.group)+1);loaded.append(r)
	var before := snapshot();records=loaded;next_id=high
	if not initial: commit(before)
	else: revision+=1
	current=signature();saved=current;notice="Loaded %d construction parts." % records.size();return true
static func valid_record(r: Variant) -> bool:
	if not r is Dictionary or not Parts.NAMES.has(r.get("kind")): return false
	for key in ["id","group","finish"]:
		if not (r.get(key) is int or r.get(key) is float) or not is_finite(float(r[key])) or float(int(r[key]))!=float(r[key]): return false
	if r.id<1 or r.group<0 or r.finish<0 or r.finish>=Parts.COLORS.size(): return false
	if not r.get("p") is Array or r.p.size()!=3 or not r.get("b") is Array or r.b.size()!=9: return false
	for value in r.p+r.b:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if absf(r.p[0])>1500001 or absf(r.p[1])>100000 or absf(r.p[2])>50000: return false
	var b := Basis(Vector3(r.b[0],r.b[1],r.b[2]),Vector3(r.b[3],r.b[4],r.b[5]),Vector3(r.b[6],r.b[7],r.b[8]))
	return absf(b.determinant()-1)<.001 and (b.transposed()*b).is_equal_approx(Basis.IDENTITY)


