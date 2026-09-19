extends RigidBody3D
var manager: Node
var resting := 0.0
var exploded := false
const BLAST_RADIUS := 9.0
func _ready() -> void:
	add_to_group("frag_grenades");mass=.4;contact_monitor=true;max_contacts_reported=8;linear_damp=.25;angular_damp=1.2
	var physics=PhysicsMaterial.new();physics.friction=1;physics.bounce=.25;physics_material_override=physics
	var collision=CollisionShape3D.new();var sphere=SphereShape3D.new();sphere.radius=.12;collision.shape=sphere;add_child(collision)
	var visual=MeshInstance3D.new();var ball=SphereMesh.new();ball.radius=.12;ball.height=.24;visual.mesh=ball
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.16,.22,.09);mat.metallic=.5;mat.roughness=.5;visual.material_override=mat;add_child(visual)
	var band=MeshInstance3D.new();var ring=CylinderMesh.new();ring.top_radius=.125;ring.bottom_radius=.125;ring.height=.04;band.mesh=ring;var glow=StandardMaterial3D.new();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.albedo_color=Color(1,.65,.1);band.material_override=glow;add_child(band)
func update_fuse(delta: float,contact: bool,speed: float,spin: float) -> bool:
	# A continuous second of supported rest, never a fuse measured from the throw.
	resting=resting+delta if contact and speed<.12 and spin<.7 else 0.0
	return resting>=1.0
func _physics_process(delta: float) -> void:
	if exploded: return
	if update_fuse(delta,get_contact_count()>0 or sleeping,linear_velocity.length(),angular_velocity.length()): detonate()
	if global_position.y< -60: queue_free()
func detonate() -> void:
	if exploded: return
	exploded=true
	var center=global_position
	for enemy in manager.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			var point=enemy.global_position+Vector3.UP*.6;var d=center.distance_to(point)
			if d<BLAST_RADIUS and clear_blast(point,enemy): enemy.take_hit(150.0*(1.0-d/BLAST_RADIUS),center,point)
	var walker=manager.arena.walker;var point=walker.global_position+Vector3.UP*.7;var distance=center.distance_to(point)
	if distance<BLAST_RADIUS and clear_blast(point,walker): manager.hurt(int(100*(1-distance/BLAST_RADIUS)))
	manager.alert_shot(center)
	var flash=manager.arena.box(center,Vector3.ONE*.5,manager.arena.material(Color(1,.55,.12),0,.5,true))
	var tween=flash.create_tween();tween.tween_property(flash,"scale",Vector3.ONE*7,.09);tween.tween_property(flash,"scale",Vector3.ZERO,.3);tween.tween_callback(flash.queue_free)
	var sound=AudioStreamPlayer3D.new();sound.stream=preload("res://mechanical_audio.gd").make_sound(true);sound.unit_size=20;sound.volume_db=-5;manager.arena.add_child(sound);sound.global_position=center;sound.finished.connect(sound.queue_free);sound.play()
	queue_free()
func clear_blast(point: Vector3,target: Node) -> bool:
	var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.08,point);ray.exclude=[get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider==target
