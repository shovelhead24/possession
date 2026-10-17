extends RigidBody3D
const Ring=preload("res://world/terrain_drive_ring.gd")
var manager: Node
var resting := 0.0
var age := 0.0
var stopped := false
func _ready() -> void:
	add_to_group("frag_grenades");add_to_group("dive_grenades");add_to_group("rebuild_frags");mass=.4;gravity_scale=0;contact_monitor=true;max_contacts_reported=8;linear_damp=.25;angular_damp=1.2;collision_layer=8;collision_mask=7
	var material=PhysicsMaterial.new();material.friction=1;material.bounce=.25;physics_material_override=material
	var collision=CollisionShape3D.new();var shape=SphereShape3D.new();shape.radius=.12;collision.shape=shape;add_child(collision)
	var visual=MeshInstance3D.new();var ball=SphereMesh.new();ball.radius=.12;ball.height=.24;ball.radial_segments=12;ball.rings=6;visual.mesh=ball
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.25,.35,.1);visual.material_override=mat;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity-=Ring.up_at(state.transform.origin)*20*state.step
func _physics_process(delta: float) -> void:
	if manager.paused(): return
	age+=delta
	if age>20: queue_free();return
	if not stopped and (get_contact_count()>0 or sleeping) and linear_velocity.length()<.85:
		stopped=true;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO;freeze=true
	if stopped:
		resting+=delta
		if resting>=2: detonate()
func detonate() -> void:
	preload("res://world/prop_blast.gd").apply(self,global_position)
	var targets=manager.enemies.duplicate()
	for rex in get_tree().get_nodes_in_group("tyrants"): targets.append(rex)
	if manager.target(): targets.append(manager.target())
	for unit in targets:
		if not is_instance_valid(unit): continue
		var point=unit.global_position+Ring.up_at(unit.global_position)*.6;var distance=point.distance_to(global_position)
		if distance>=9: continue
		var ray=PhysicsRayQueryParameters3D.create(global_position+Ring.up_at(global_position)*.15,point,7);ray.exclude=[get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=unit: continue
		if manager.is_target(unit): manager.hurt(100*(1-distance/9))
		elif unit.has_method("take_hit") and unit.get("dead")!=true: unit.take_hit(150*(1-distance/9),global_position,point)
	manager.alert_shot(global_position)
	var flash=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.4;sphere.height=.8;sphere.radial_segments=12;sphere.rings=6;flash.mesh=sphere
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,.55,.1);flash.material_override=mat;flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	manager.add_child(flash);flash.global_position=global_position
	var tween=flash.create_tween();tween.tween_property(flash,"scale",Vector3.ONE*6,.1);tween.tween_property(flash,"scale",Vector3.ZERO,.25);tween.tween_callback(flash.queue_free)
	queue_free()
