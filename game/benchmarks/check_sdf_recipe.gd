extends SceneTree
const Recipe=preload("res://world/sdf_recipe.gd")
const Workshop=preload("res://world/sdf_authoring.gd")

func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	var hill := Recipe.feature("hill",Vector3(-40,0,-40))
	assert(Recipe.field(Vector3(-40,8,-40),3.2,.35,[hill])<0)
	var lower := Recipe.feature("lower",Vector3(-40,0,-40))
	assert(Recipe.field(Vector3(-40,-5,-40),3.2,.35,[lower])>0)
	assert(Recipe.field(Vector3(-40,-15,-40),3.2,.35,[lower])<0)
	var flat := Recipe.feature("flatten",Vector3(-40,5,-40))
	assert(absf(Recipe.field(Vector3(-40,5,-40),3.2,.35,[flat]))<.001)
	var carve := Recipe.feature("carve",Vector3(-40,0,-40));carve.radius=4
	assert(Recipe.field(Vector3(-40,-2,-40),3.2,.35,[hill,carve])>0)
	var tunnel := Recipe.feature("tunnel",Vector3(-40,5,-40));tunnel.radius=3
	assert(Recipe.field(Vector3(-40,5,-40),3.2,.35,[hill,tunnel])>0)
	assert(Recipe.field(Vector3(-40,5,-40),3.2,.35,[tunnel,hill])<0)
	var ridge := Recipe.feature("ridge",Vector3(-40,10,-40));ridge.radius=3;ridge.bend=10
	assert(Recipe.field(Vector3(-40,10,-30),3.2,.35,[ridge])<0)
	var bridge := Recipe.feature("bridge",Vector3(-40,20,-40));bridge.height=20
	assert(Recipe.field(Vector3(-40,18,-40),3.2,.35,[bridge])<0)
	assert(Recipe.field(Vector3(-40,10,-40),3.2,.35,[bridge])>0)
	assert(Recipe.field(Vector3(-20,10,-40),3.2,.35,[bridge])<0)
	var all_features := [hill,lower,flat,carve,ridge,tunnel,bridge]
	assert(Recipe.validate(Recipe.document(all_features)))
	assert(not Recipe.validate({"schema":1,"frame":"wrong","features":[]}))
	assert(not Recipe.validate({"schema":1,"frame":"arena-ring-tangent-metres","features":[{}]}))
	var path := "user://sdf-recipe-regression.json"
	assert(Recipe.save_recipe(path,all_features)==OK)
	var loaded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(Recipe.validate(loaded))
	for p in [Vector3(-40,18,-40),Vector3(-32,3,-40),Vector3(-40,5,-30)]:
		assert(Recipe.field(p,3.2,.35,all_features)==Recipe.field(p,3.2,.35,loaded.features))
	var origin := Vector3(-64,-24,-64);var cells := Vector3i(16,44,16)
	var area := Rect2(-64,-64,32,32).grow(.1)
	var local := Recipe.relevant([hill],area)
	var before := Recipe.cache_key(local,origin,cells,2,3.2,.35)
	var distant := Recipe.feature("hill",Vector3(600,0,600))
	assert(before==Recipe.cache_key(Recipe.relevant([hill,distant],area),origin,cells,2,3.2,.35))
	var edited := hill.duplicate();edited.height=20
	assert(before!=Recipe.cache_key(Recipe.relevant([edited],area),origin,cells,2,3.2,.35))
	# Adjacent chunks evaluate the same source on their shared plane, including normals.
	var right := Recipe.relevant([hill],Rect2(-32,-64,32,32).grow(.1))
	for y in range(-5,16):
		var p := Vector3(-32,y,-40)
		assert(Recipe.field(p,3.2,.35,local)==Recipe.field(p,3.2,.35,right))
	var workshop := Workshop.new()
	DirAccess.make_dir_recursive_absolute(Workshop.CACHE_PATH)
	var a: Dictionary=workshop.generate(3.2,.35,origin,cells,2,Recipe.field.bind([hill]))
	var b: Dictionary=workshop.generate(3.2,.35,origin,cells,2,Recipe.field.bind([hill]))
	assert(b.cached and a.vertices==b.vertices and a.indices==b.indices and a.normals==b.normals)
	assert(FileAccess.file_exists(Workshop.CACHE_PATH+before+".bin"))
	workshop.generate(3.2,.35,origin,cells,2,Recipe.field.bind([edited]))
	assert(FileAccess.file_exists(Workshop.CACHE_PATH+before+".bin"),"Edit deleted old cache")
	for node in [workshop.terrain,workshop.collision,workshop.camera,workshop.player,workshop.hud,workshop.marker]: node.free()
	workshop.free()
	print("PASS: seven tools, composition order, recipe validation/roundtrip, chunk boundary field, local cache keys, cache reuse and retained old revisions")
	quit()
