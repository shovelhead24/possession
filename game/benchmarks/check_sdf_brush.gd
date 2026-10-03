extends SceneTree
const Recipe=preload("res://world/sdf_recipe.gd")
const Brush=preload("res://world/sdf_brush.gd")
const Mesher=preload("res://world/tetra_mesher.gd")

func _initialize() -> void:
	var tool := Recipe.feature("lower",Vector3.ZERO);tool.radius=8
	var brush := Brush.new();brush.begin([],tool)
	brush.dab(Vector3(-32,0,-40),2)
	var first: Array=brush.draft.duplicate(true)
	var value := Recipe.field(Vector3(-32,-1,-40),3.2,.35,first)
	brush.dab(Vector3(-32,0,-40),2)
	assert(Recipe.field(Vector3(-32,-1,-40),3.2,.35,brush.draft)>value+1.9)
	brush.begin(brush.draft,tool);brush.dab(Vector3(-8,0,-40),2)
	assert(Recipe.field(Vector3(-32,-1,-40),3.2,.35,brush.draft)>value+1.9,"Later ravine erased first cut")
	var a := Brush.new();a.begin([],tool)
	var b := Brush.new();b.begin([],tool)
	for i in 10: a.dab(Vector3(-32,0,-40),.4)
	for i in 20: b.dab(Vector3(-32,0,-40),.2)
	assert(absf(a.draft[0].amount-b.draft[0].amount)<.00001)
	var square: Dictionary=first[0].duplicate();square.shape="square"
	var ellipse: Dictionary=first[0].duplicate();ellipse.shape="ellipse";ellipse.aspect=2
	assert(Recipe.field(Vector3(-32,-1,-28),3.2,.35,[ellipse])>Recipe.field(Vector3(-32,-1,-28),3.2,.35,first))
	assert(Recipe.field(Vector3(-26,-1,-34),3.2,.35,[square])>Recipe.field(Vector3(-26,-1,-34),3.2,.35,first))
	var tunnel := Recipe.feature("tunnel",Vector3(-50,5,-40));tunnel.radius=3;tunnel.end_x=-10;tunnel.end_y=10;tunnel.end_z=-40
	var hill := Recipe.feature("hill",Vector3(-30,0,-40));hill.radius=30;hill.height=20
	assert(Recipe.field(Vector3(-30,7.5,-40),3.2,.35,[hill,tunnel])>0)
	assert(Recipe.validate(Recipe.document([square,ellipse,tunnel])))
	var parsed: Dictionary=JSON.parse_string(JSON.stringify(Recipe.document(brush.draft)))
	assert(Recipe.validate(parsed))
	assert(Recipe.field(Vector3(-32,-1,-40),3.2,.35,brush.draft)==Recipe.field(Vector3(-32,-1,-40),3.2,.35,parsed.features))
	# Actual adjacent meshes: the ravine spans x=-32, not just analytic samples.
	var left := Mesher.build(Recipe.field.bind(3.2,.35,a.draft),Vector3(-64,-24,-64),Vector3i(16,44,16),2)
	var right := Mesher.build(Recipe.field.bind(3.2,.35,a.draft),Vector3(-32,-24,-64),Vector3i(16,44,16),2)
	var boundary_a := {};var boundary_b := {}
	for vertex in left.vertices:
		if absf(vertex.x+32)<.0001: boundary_a[str(vertex.snapped(Vector3.ONE*.0001))]=true
	for vertex in right.vertices:
		if absf(vertex.x+32)<.0001: boundary_b[str(vertex.snapped(Vector3.ONE*.0001))]=true
	assert(not boundary_a.is_empty() and boundary_a==boundary_b,"Ravine mesh boundary mismatch")
	print("PASS: accumulating/repeated ravine strokes, time-based strength, square/ellipse, endpoint cylinder, persistence and matching adjacent mesh edges")
	quit()
