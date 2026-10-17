extends Node3D
## First bounded content slice. Visual batching never substitutes collision.
const Ring = preload("res://world/terrain_drive_ring.gd")
const Compounds = preload("res://world/arena_compounds.gd")
var arena: Node3D
var anchor := Vector2(130,260)
var building: Node3D
var batches: Array[MultiMeshInstance3D]=[]
var resident_ids := []
var clock := 0.0
var status := "Building: waiting for resident terrain at 130 / 260"
var enabled := true
var placement_attempt := 0
var placed_once := false
var entrance_rise := 0.0

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF

static func batch_boxes(source: Node3D) -> Array[MultiMeshInstance3D]:
	var groups := {}
	for child in source.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh: continue
		var material: Material=child.material_override
		if not groups.has(material): groups[material]=[]
		groups[material].append(child.transform*Transform3D(Basis.IDENTITY.scaled(child.mesh.size),Vector3.ZERO))
		# Keep original analytic collision at its exact authored transform.
		for body in child.get_children():
			var pose: Transform3D=child.transform*body.transform
			child.remove_child(body);source.add_child(body);body.transform=pose
		source.remove_child(child);child.free()
	var result: Array[MultiMeshInstance3D]=[]
	for material in groups:
		var draw := MultiMeshInstance3D.new();draw.name="BuildingMaterialBatch"
		draw.multimesh=MultiMesh.new();draw.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new();box.size=Vector3.ONE
		draw.multimesh.mesh=box;draw.material_override=material
		draw.multimesh.instance_count=groups[material].size()
		for i in groups[material].size(): draw.multimesh.set_instance_transform(i,groups[material][i])
		source.add_child(draw);result.append(draw)
	return result

func _physics_process(delta: float) -> void:
	if not arena or not arena.ready_to_play: return
	clock-=delta
	if clock>0: return
	clock=.25
	var centre := Ring.point(anchor.x,arena.source.surface_height(anchor),anchor.y)
	var distance: float=arena.camera.global_position.distance_to(centre)
	var supported: bool=arena.vehicle_kit.car.global_position.distance_to(centre)<100
	if arena.on_foot and arena.on_foot.active: supported=supported or arena.on_foot.global_position.distance_to(centre)<100
	if not enabled or (distance>750 and not supported):
		retire();return
	var ids := []
	for offset in [Vector2(-8,-10),Vector2(8,-10),Vector2(-8,10),Vector2(8,10)]:
		var key := Vector2i(((anchor+offset)/200.0).floor())
		var entry: Dictionary=arena.tile_entries.get(key,{})
		if entry.is_empty(): retire();status="Building: waiting for resident terrain";return
		ids.append(entry.body.get_instance_id())
	if not building or ids!=resident_ids:
		if not ground_building():
			if not placed_once:
				placement_attempt+=1
				anchor=Vector2(70+(placement_attempt%7)*20,240+(placement_attempt/7%5)*20)
			return
		placed_once=true
		resident_ids=ids
	var hidden_edit: bool=arena.edited_render_lods and arena.edited_render_lods.is_edit_hidden(Vector2i((anchor/200.0).floor()))
	for draw in batches:
		draw.visible=distance<650 and not hidden_edit
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if distance<140 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	status="Restored building: 2 material batches | arc %.0f / lateral %.0f | %.0f m" % [anchor.x,anchor.y,distance]

func ground_building() -> bool:
	var points: Array[Vector3]=[]
	var basis: Basis=Ring.tangent_basis(Ring.point(anchor.x,0,anchor.y),0)
	var origin := Ring.point(anchor.x,arena.source.surface_height(anchor),anchor.y)
	var up := Ring.up_at(origin)
	# Sample the entire footprint so a central terrain mound cannot pierce the interior.
	var offsets: Array[Vector3]=[Vector3(0,0,11)]
	for x in range(-6,7,2):
		for z in range(-7,8,2): offsets.append(Vector3(x,0,z))
	for offset in offsets:
		var p: Vector3=origin+basis*offset
		var query := PhysicsRayQueryParameters3D.create(p+up*250,p-up*250,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return false
		points.append(hit.position)
	var top := -INF;var bottom := INF
	for p in points:
		var height := (p-origin).dot(up);top=maxf(top,height);bottom=minf(bottom,height)
	# A deep cut should not create an enormous floating foundation.
	if top-bottom>(4.0 if placed_once else 1.5):
		retire();status="Building: seeking suitable ground";print("REBUILD_GROUND_REJECT ",anchor," relief=",top-bottom);return false
	retire()
	building=Node3D.new();building.name="RestoredBuilding"
	var kit := Compounds.new();kit.building(building,Vector3.ZERO)
	var depth := maxf(.25,top-bottom+.3)
	kit.solid(building,Vector3(0,-depth*.5-.2,0),Vector3(12,depth,14),kit.stone)
	# A continuous ramp supports CharacterBody walking without step-up tricks.
	var rise := top-(points[0]-origin).dot(up)+.08
	entrance_rise=rise
	kit.solid(building,Vector3(0,-rise*.5-.06,9),Vector3(2,.12,sqrt(16+rise*rise)),kit.stone)
	var ramp: MeshInstance3D=building.get_child(building.get_child_count()-1)
	ramp.rotation.x=atan2(rise,4.0)
	batches=batch_boxes(building)
	add_child(building);building.transform=Transform3D(basis,origin+up*(top+.08))
	print("REBUILD_BUILDING_READY batches=",batches.size()," collision_parts=",building.get_child_count()-batches.size()," relief=",top-bottom)
	return true

func retire() -> void:
	if is_instance_valid(building):
		remove_child(building);building.queue_free()
	building=null;batches.clear();resident_ids=[]



