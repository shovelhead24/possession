extends CharacterBody3D
var arena: Node
var manager: Node
var model: Node3D
var health := 900.0
var patrol=[Vector3(-40,0,-60),Vector3(90,0,-130),Vector3(120,0,-290),Vector3(-100,0,-250)]
var waypoint := 0
var cooldown := 0.0
func _ready():
	floor_snap_length=.9;floor_max_angle=deg_to_rad(48)
	model=arena.kit.imported("C:/Games/possession/assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb");add_child(model)
	var a=arena.kit.bounds(model);model.scale*=6.0/maxf(a.size.y,.01);a=arena.kit.bounds(model);model.position-=Vector3(a.get_center().x,a.position.y,a.get_center().z)
	var collision=CollisionShape3D.new();var shape=CapsuleShape3D.new();shape.radius=1.25;shape.height=4.5;collision.shape=shape;collision.position.y=2.2;add_child(collision)
	var label=Label3D.new();label.text="TYRANT / INDISCRIMINATE";label.position.y=5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.pixel_size=.004;add_child(label)
	position=patrol[0];position.y=arena.height_at(position.x,position.z)+.1
func take_hit(damage: float,_source: Vector3,_point: Vector3) -> String:
	health-=damage
	if health<=0: queue_free();return "TYRANT DOWN"
	return "TYRANT / %d HP" % health
func target() -> Node3D:
	var best: Node3D=arena.walker;var best_distance=position.distance_to(best.position)
	for enemy in manager.enemies:
		if not enemy.dead and position.distance_to(enemy.position)<best_distance: best=enemy;best_distance=position.distance_to(enemy.position)
	return best
func _physics_process(delta):
	cooldown-=delta;var prey=target();var target_point=prey.position
	if position.distance_to(prey.position)>45: target_point=patrol[waypoint]
	var move=target_point-position;move.y=0
	if move.length()<3 and position.distance_to(prey.position)>45: waypoint=(waypoint+1)%patrol.size()
	if move.length()>.1: rotation.y=lerp_angle(rotation.y,atan2(-move.x,-move.z),minf(1,delta*4));velocity.x=move.normalized().x*5;velocity.z=move.normalized().z*5
	else: velocity.x=0;velocity.z=0
	if not is_on_floor(): velocity.y-=20*delta
	move_and_slide()
	if position.distance_to(prey.position)<4 and cooldown<=0:
		cooldown=.8
		if prey.has_method("take_hit"): prey.take_hit(90,position,prey.position+Vector3.UP)
		elif prey==arena.walker: manager.hurt(35)
