extends Node3D
const Ring=preload("res://world/terrain_drive_ring.gd")
const LIMIT=64
var manager: Node
var bolts: Array=[]
var batch: MultiMeshInstance3D
func origin_shifted(delta: Vector3):
	for bolt in bolts:bolt.point-=delta
	batch.position=Vector3.ZERO
	for i in bolts.size():batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,bolts[i].point))
func _ready() -> void:
	batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_colors=true
	var quad=QuadMesh.new();quad.size=Vector2.ONE*.22;batch.multimesh.mesh=quad;batch.multimesh.instance_count=LIMIT;batch.multimesh.visible_instance_count=0
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.vertex_color_use_as_albedo=true;mat.albedo_texture=load("res://effects/plasma/plasma rifle contrail.png");batch.material_override=mat
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(batch);set_physics_process(false)
func launch(unit: Node, start: Vector3, direction: Vector3, damage: float, color: Color) -> bool:
	if bolts.size()>=LIMIT: return false
	bolts.append({"point":start,"velocity":direction.normalized()*(40 if unit.elite else 28),"range":110.0,"damage":damage,"color":color,"excluded":unit.friendly_rids()});set_physics_process(true);return true
func _physics_process(delta: float) -> void:
	if manager.paused(): return
	var live: Array=[]
	for bolt in bolts:
		var end: Vector3=bolt.point+bolt.velocity*delta
		var query=PhysicsRayQueryParameters3D.create(bolt.point,end,7);query.exclude=bolt.excluded;query.hit_from_inside=true
		var hit=get_world_3d().direct_space_state.intersect_ray(query)
		var static_hit=preload("res://world/weapon_obstruction.gd").cast(manager.arena,bolt.point,hit.position if not hit.is_empty() else end)
		if not static_hit.is_empty(): hit=static_hit
		if not hit.is_empty():
			if manager.is_target(hit.collider): manager.hurt(bolt.damage)
			elif hit.collider==manager.trex: hit.collider.take_hit(bolt.damage,bolt.point,hit.position)
			continue
		bolt.range-=bolt.point.distance_to(end);bolt.point=end
		if bolt.range>0: live.append(bolt)
	bolts=live;batch.multimesh.visible_instance_count=bolts.size()
	for i in bolts.size():
		batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,bolts[i].point));batch.multimesh.set_instance_color(i,bolts[i].color)
	if bolts.is_empty(): set_physics_process(false)
