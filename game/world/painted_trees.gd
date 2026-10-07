extends Node3D
## Scatter recipes persist; instances are disposable, resident-chunk derivatives.
var workshop: Node
var items := {}
var candidates: Array=[]
var cursor := 0
var signature := ""
var clock := 0.0
var epoch := 0
var batches := {}
var lod_clock := 0.0
var uploaded := {}
const LIMIT := 600

static func scatter(features: Array) -> Array:
	var result := [];var occupied := {}
	for f in features:
		if f.kind!="trees": continue
		var rng := RandomNumberGenerator.new();rng.seed=int(f.seed)^hash(Vector2(f.x,f.z))
		var count := mini(64,ceili(PI*f.radius*f.radius*f.density/100.0))
		for i in count:
			var angle := rng.randf()*TAU;var r: float=sqrt(rng.randf())*f.radius
			var p: Vector2=Vector2(f.x,f.z)+Vector2(cos(angle),sin(angle))*r
			var cell := Vector2i(floori(p.x/3),floori(p.y/3))
			var height := float(f.tree_height)*rng.randf_range(.8,1.2);var yaw := rng.randf()*TAU;var variant := rng.randi()
			if occupied.has(cell): continue
			occupied[cell]=true
			result.append({"id":cell,"point":p,"height":height,"yaw":yaw,"variant":variant,"slope":f.slope_limit})
			if result.size()>=4096: return result # Bounded candidate work even on dense recipes.
	return result

func _process(delta: float) -> void:
	if not is_instance_valid(workshop.arena_content) or workshop.arena_content.tree_batches.is_empty(): return
	lod_clock-=delta
	if lod_clock<=0: update_lods();lod_clock=.25
	clock-=delta
	if clock>0: return
	clock=.05
	var keys: Array=workshop.chunks.keys();keys.sort()
	var next_signature := str(workshop.revision)+str(keys)
	if signature!=next_signature:
		signature=next_signature;epoch+=1;cursor=0
		var local := []
		for f in workshop.features:
			if f.kind!="trees": continue
			for key in keys:
				if Rect2(Vector2(key)*32,Vector2.ONE*32).intersects(Rect2(Vector2(f.x-f.radius,f.z-f.radius),Vector2.ONE*f.radius*2)):
					local.append(f);break
		candidates=scatter(local)
		candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.point.distance_squared_to(Vector2(workshop.camera.position.x,workshop.camera.position.z))<b.point.distance_squared_to(Vector2(workshop.camera.position.x,workshop.camera.position.z)))
		if candidates.size()>LIMIT: candidates.resize(LIMIT)
		var wanted := {}
		for c in candidates: wanted[c.id]=true
		for id in items.keys():
			if not wanted.has(id): items[id].body.queue_free();items.erase(id)
	# Bounded ray/instance work. Revisit unready chunks instead of pinning them.
	for n in mini(8,candidates.size()):
		var c: Dictionary=candidates[cursor%candidates.size()];cursor+=1
		var key: Vector2i=workshop.key_at(Vector3(c.point.x,0,c.point.y))
		if not workshop.chunks.has(key):
			if items.has(c.id): items[c.id].body.queue_free();items.erase(c.id)
			continue
		if workshop.preview_expected.has(key) or workshop.collision_pending.has(key) or workshop.chunks[key].revision!=workshop.revision: continue
		if not items.has(c.id) or items[c.id].epoch!=epoch:
			var query := PhysicsRayQueryParameters3D.create(Vector3(c.point.x,63,c.point.y),Vector3(c.point.x,-24,c.point.y),1)
			query.exclude=[workshop.player.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.normal.y<cos(deg_to_rad(c.slope)):
				if items.has(c.id): items[c.id].body.queue_free();items.erase(c.id)
				continue
			if not items.has(c.id):
				var body := StaticBody3D.new();body.collision_layer=2;add_child(body)
				var shape := CollisionShape3D.new();shape.shape=CylinderShape3D.new();body.add_child(shape)
				items[c.id]={"body":body,"shape":shape,"epoch":-1,"transform":Transform3D.IDENTITY,"variant":0}
			var item: Dictionary=items[c.id];item.epoch=epoch;item.body.position=hit.position
			item.transform=Transform3D(Basis(Vector3.UP,c.yaw).scaled(Vector3.ONE*c.height),hit.position)
			item.variant=int(c.variant)%workshop.arena_content.tree_batches.size()
			item.shape.shape.radius=c.height*.025;item.shape.shape.height=c.height*.45;item.shape.position.y=c.height*.225

func update_lods() -> void:
	if not visible: return
	var buckets := {}
	for item in items.values():
		var distance: float=workshop.camera.position.distance_to(item.body.position)
		if distance>200: continue
		var key := Vector2i(item.variant,workshop.arena_content.tree_lod(distance))
		if not buckets.has(key): buckets[key]=[]
		buckets[key].append(item.transform)
	for key in buckets:
		if not batches.has(key):
			var node := MultiMeshInstance3D.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if key.y==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			node.multimesh.mesh=workshop.arena_content.tree_batches[key.x].batches[key.y].multimesh.mesh
			add_child(node);batches[key]=node
	for key in batches:
		var transforms: Array=buckets.get(key,[]);var mm: MultiMesh=batches[key].multimesh
		if uploaded.get(key,[])==transforms: continue
		uploaded[key]=transforms
		mm.instance_count=transforms.size()
		for i in transforms.size(): mm.set_instance_transform(i,transforms[i])
