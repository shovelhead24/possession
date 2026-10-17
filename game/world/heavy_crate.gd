extends RigidBody3D
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var paused_velocity := Vector3.ZERO
var paused_angular := Vector3.ZERO
var suspended := false
var last_blast := 0.0
var navigation_anchor := Vector3.ZERO
func _ready() -> void:
	navigation_anchor=global_position
	add_to_group("blast_props");mass=160.0;gravity_scale=0;collision_layer=2;collision_mask=7
	linear_damp=.18;angular_damp=.7;can_sleep=true;continuous_cd=true
	var material=PhysicsMaterial.new();material.friction=.75;material.bounce=.04;physics_material_override=material
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1.8,1.8,1.8);shape.shape=box;add_child(shape)
	build_visuals()
func build_visuals() -> void:
	var wood=StandardMaterial3D.new();wood.albedo_color=Color(.31,.22,.12);wood.roughness=.9
	var steel=StandardMaterial3D.new();steel.albedo_color=Color(.14,.17,.18);steel.metallic=.65;steel.roughness=.65
	add_box(Vector3(1.8,1.8,1.8),Vector3.ZERO,wood)
	for x in [-.59,.59]: add_box(Vector3(.12,1.84,1.84),Vector3(x,0,0),steel)
	for y in [-.75,.75]: add_box(Vector3(1.84,.12,1.84),Vector3(0,y,0),steel)
func add_box(size: Vector3, offset: Vector3, material: Material) -> void:
	var visual=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size;visual.mesh=mesh;visual.material_override=material;visual.position=offset;add_child(visual)
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not suspended: state.linear_velocity-=Ring.up_at(state.transform.origin)*9.8*state.step
func _physics_process(_delta: float) -> void:
	if not arena: return
	var pause=arena.aliens.paused() or not arena.aliens.resident(global_position)
	if not pause and sleeping and global_position.distance_to(navigation_anchor)>2:
		navigation_anchor=global_position;arena.aliens.navigation.invalidate()
	if pause==suspended: return
	suspended=pause
	if pause: paused_velocity=linear_velocity;paused_angular=angular_velocity;freeze=true
	else: freeze=false;linear_velocity=paused_velocity;angular_velocity=paused_angular
func blast_impulse(origin: Vector3, radius: float, strength: float) -> void:
	if suspended or freeze: return
	var offset=global_position-origin;var distance=offset.length()
	if distance>=radius: return
	var up=Ring.up_at(global_position);var outward=offset.slide(up).normalized()
	if outward.length_squared()<.01: outward=global_basis.x
	var impulse=(outward+up*.55).normalized()*strength*pow(1-distance/radius,1.3)
	last_blast=impulse.length();sleeping=false
	apply_impulse(impulse,-up*.5)
func telemetry() -> Dictionary:
	return {"mass_kg":mass,"speed":linear_velocity.length(),"sleeping":sleeping,"suspended":suspended,"last_blast_impulse":last_blast}
