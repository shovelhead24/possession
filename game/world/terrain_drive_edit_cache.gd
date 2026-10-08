extends RefCounted
## One terrain worker at a time owns these entries. Immutable primitive arrays only.
const Cuts = preload("res://world/terrain_drive_cuts.gd")
var fields := preload("res://world/sdf_field_cache.gd").new()
var entries := {}
var order: Array=[]
const LIMIT := 24

func build(source: RefCounted, key: Vector2i, features: Array, supplied := {}) -> Dictionary:
	var identity: String=source.identity+str(key)
	if not entries.has(identity):
		var builder := Cuts.new();builder.source=source;builder.field_cache=fields
		entries[identity]={"base":source.build_tile(key) if supplied.is_empty() else supplied,"builder":builder}
	order.erase(identity);order.append(identity)
	while order.size()>LIMIT: entries.erase(order.pop_front())
	var entry: Dictionary=entries[identity]
	entry.builder.cuts=features
	return entry.builder.rebuild(entry.base,key)
