extends RefCounted
## One terrain worker at a time owns these entries. Immutable primitive arrays only.
const Cuts = preload("res://world/terrain_drive_cuts.gd")
var fields := preload("res://world/sdf_field_cache.gd").new()
var entries := {}
var order: Array=[]
const LIMIT := 24
var protected := {}

func protect(keys: Array) -> void:
	# Called only between terrain jobs; the worker is the sole cache writer.
	protected.clear()
	for key in keys: protected[key]=true

func needs_warm(source: RefCounted, key: Vector2i) -> bool:
	var entry: Dictionary=entries.get(source.identity+str(key),{})
	return not entry.get("warm",false)

func warm(source: RefCounted, key: Vector2i, features: Array) -> void:
	var identity: String=source.identity+str(key)
	if not entries.has(identity): build(source,key,features)
	var entry: Dictionary=entries[identity]
	if entry.get("warm",false): return
	entry.builder.prepare_base(entry.base)
	# Prime the coarse lattice surrounding every base surface in this tile,
	# including bridges/overhangs. Exact crater geometry is still generated later.
	for column in entry.builder.base_extents:
		var extent: Vector2=entry.builder.base_extents[column]
		for y in range(floori(extent.x/8)-1,ceili(extent.y/8)+2):
			for z in range(column.y,column.y+2):
				for x in range(column.x,column.x+2): entry.builder.lattice(Vector3(x,y,z)*8)
	entry.warm=true

func build(source: RefCounted, key: Vector2i, features: Array, supplied := {}) -> Dictionary:
	var identity: String=source.identity+str(key)
	if not entries.has(identity):
		var builder := Cuts.new();builder.source=source;builder.field_cache=fields
		entries[identity]={"base":source.build_tile(key) if supplied.is_empty() else supplied,"builder":builder,"key":key}
	order.erase(identity);order.append(identity)
	for old in order.duplicate():
		if order.size()<=LIMIT: break
		if protected.has(entries[old].key) or old==identity: continue
		entries.erase(old);order.erase(old)
	var entry: Dictionary=entries[identity]
	entry.builder.cuts=features
	# Unedited tiles return entry.base directly. Publication adds mutable Node and
	# collision-cursor fields, so give each caller its own dictionary. Packed mesh
	# arrays remain shared (copy-on-write); cached geometry stays primitive-only.
	return entry.builder.rebuild(entry.base,key).duplicate()
