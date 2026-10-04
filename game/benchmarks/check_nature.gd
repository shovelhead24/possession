extends SceneTree
const Recipe=preload("res://world/sdf_recipe.gd")
const Cache=preload("res://world/sdf_field_cache.gd")
const Trees=preload("res://world/painted_trees.gd")

func _initialize() -> void:
	assert(load("res://world/sdf_authoring.gd")!=null)
	var f := Recipe.feature("mountain",Vector3(-32,0,-32));f.radius=24;f.height=16;f.erosion_steps=12
	var start := Time.get_ticks_usec()
	var a := Recipe.Mountain.generate(f);var b := Recipe.Mountain.generate(f)
	assert(a==b,"Erosion must regenerate deterministically")
	var dry := f.duplicate();dry.water=0;dry.wind=0
	assert(a!=Recipe.Mountain.generate(dry),"Erosion controls must change the terrain")
	var water := dry.duplicate();water.water=1
	var wind := dry.duplicate();wind.wind=1
	assert(Recipe.Mountain.generate(water)!=Recipe.Mountain.generate(dry))
	assert(Recipe.Mountain.generate(wind)!=Recipe.Mountain.generate(dry))
	for v in a: assert(is_finite(v) and v>=0)
	for i in Recipe.Mountain.SIZE:
		assert(a[i]==0 and a[(Recipe.Mountain.SIZE-1)*Recipe.Mountain.SIZE+i]==0)
	var cache := Cache.new();var origin := Vector3(-32,-24,-32);var cells := Vector3i(16,44,16)
	var result := cache.build(origin,cells,2,[f],5,1)
	var baseline := Cache.new().build(origin,cells,2,[f],5,1,false)
	assert(result.vertices==baseline.vertices and result.indices==baseline.indices and result.normals==baseline.normals)
	# Compare actual cached samples against recipe composition, including a seam.
	var neighbour := cache.build(origin-Vector3(32,0,0),cells,2,[f],5,1)
	var state: Dictionary=result._field_state;var other: Dictionary=neighbour._field_state
	var dims := cells+Vector3i.ONE*3
	for z in dims.z:
		for y in dims.y:
			var i := (z*dims.y+y)*dims.x+1
			var j := (z*dims.y+y)*dims.x+17
			assert(state.values[i]==other.values[j],"Mountain seam samples differ")
			var p := origin-Vector3.ONE*2+Vector3(1,y,z)*2
			assert(absf(state.values[i]-Recipe.field(p,5,1,[f]))<.00002)
	var source := Recipe.document([f,Recipe.feature("trees",Vector3.ZERO)])
	assert(Recipe.validate(JSON.parse_string(JSON.stringify(source))))
	source.features[0].erosion_steps=INF;assert(not Recipe.validate(source))
	var trees := [Recipe.feature("trees",Vector3.ZERO)]
	assert(Trees.scatter(trees)==Trees.scatter(trees))
	assert(Recipe.compose(Vector3.ZERO,3,trees)==3)
	assert(Recipe.relevant(trees,Rect2(-100,-100,200,200)).is_empty())
	print("PASS: deterministic mountain + independent water/wind erosion, finite compact field, exact mesh A/B, tree scatter, validation. ms=",(Time.get_ticks_usec()-start)/1000.0)
	quit()
