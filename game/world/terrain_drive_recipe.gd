extends RefCounted
## Exact consolidation of additive brushes, with barriers at every CSG operation.
static func compact(features: Array) -> Array:
	var output := []
	var slots := {}
	for original in features:
		var f: Dictionary=original.duplicate(true);f.erase("_stroke_id")
		if f.kind not in ["hill","lower"] or not f.has("amount"):
			slots.clear();output.append(f);continue
		# Additive height kernels ignore Y. Keep different footprint shapes and
		# opposite signs separate; never combine across a tunnel/sphere/mountain.
		f.y=0.0
		var shape := f.duplicate();shape.erase("amount")
		var key := JSON.stringify(shape,"",true,true)
		if slots.has(key) and output[slots[key]].amount+f.amount<=100000:
			output[slots[key]].amount+=f.amount
		else:
			slots[key]=output.size();output.append(f)
	return output
