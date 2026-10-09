extends RefCounted
var records: Array=[]
var undo_stack: Array=[]
var redo_stack: Array=[]
var next_id := 1
var saved := "[]"
var current := "[]"
var path := "user://painted-trees.json"
var base := ""
var notice := "Ready to paint trees."
var before: Array=[]
var active := false

func signature() -> String:
	# JSON parsing can shift a double by one ULP. Compare placement at sub-mm
	# precision instead of treating that harmless reload noise as an edit.
	var canonical := []
	for record in records:
		canonical.append([record.id,roundi(record.x*1000000),roundi(record.z*1000000),roundi(record.height*1000000),roundi(record.yaw*1000000),record.species])
	return JSON.stringify(canonical)

func unsaved() -> bool:
	return active or current!=saved

func begin() -> void:
	before=records.duplicate(true);active=true

func finish() -> void:
	if not active: return
	active=false
	if before!=records:
		undo_stack.append(before);redo_stack.clear()
		if undo_stack.size()>32: undo_stack.pop_front()
	before=[];current=signature()

func undo() -> void:
	finish()
	if undo_stack.is_empty(): notice="No tree stroke to undo.";return
	redo_stack.append(records.duplicate(true));records=undo_stack.pop_back()
	current=signature()
	notice="Undid tree stroke."

func redo() -> void:
	if redo_stack.is_empty(): notice="No tree stroke to redo.";return
	undo_stack.append(records.duplicate(true));records=redo_stack.pop_back()
	current=signature()
	notice="Redid tree stroke."

func save() -> bool:
	if active: notice="Finish painting before saving.";return false
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	if not file: notice="Tree save failed: cannot write file.";return false
	file.store_string(JSON.stringify({"schema":1,"base":base,"frame":"terrain-drive-ring-metres","trees":records},"\t",true,true));file.flush()
	var error := file.get_error();file.close()
	if error!=OK: notice="Tree save failed while writing.";return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK:
		notice="Tree save failed: cannot create backup.";return false
	if DirAccess.rename_absolute(path+".pending",path)!=OK: notice="Tree save failed: cannot install file.";return false
	current=signature();saved=current;notice="Saved %d painted trees." % records.size();return true

func load_saved(species: Array, initial := false) -> bool:
	if not FileAccess.file_exists(path): notice="No saved painted trees yet.";return false
	var doc: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or doc.get("schema")!=1 or doc.get("base")!=base or doc.get("frame")!="terrain-drive-ring-metres" or not doc.get("trees") is Array:
		notice="Invalid tree save; current trees retained.";return false
	var ids := {};var loaded := []
	for entry in doc.trees:
		if not entry is Dictionary or entry.get("species") not in species:
			notice="Invalid tree species; current trees retained.";return false
		for field in ["id","x","z","height","yaw"]:
			if not (entry.get(field) is float or entry.get(field) is int) or not is_finite(float(entry[field])):
				notice="Invalid tree value; current trees retained.";return false
		var id := int(entry.id)
		if id<1 or float(id)!=float(entry.id) or ids.has(id) or absf(entry.x)>2000000 or absf(entry.z)>50000 or entry.height<.5 or entry.height>40 or absf(entry.yaw)>TAU:
			notice="Invalid tree placement; current trees retained.";return false
		ids[id]=true
		loaded.append({"id":id,"x":float(entry.x),"z":float(entry.z),"height":float(entry.height),"yaw":float(entry.yaw),"species":entry.species})
	if not initial: begin()
	records=loaded
	for entry in records: next_id=maxi(next_id,entry.id+1)
	if not initial: finish()
	current=signature();saved=current;notice="Loaded %d painted trees." % records.size();return true
