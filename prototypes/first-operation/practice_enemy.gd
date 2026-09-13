extends CharacterBody3D
var kind := 0
var health := 50.0
var shield := 0.0
var arena: Node3D
var manager: Node3D
var origin: Vector3
var timer := 2.0
var charging := false
var aim := Vector3.ZERO
var phase := 0.0
var shield_mesh: MeshInstance3D
var eye: MeshInstance3D
var dead := false

func _ready() -> void:
	origin=position;floor_snap_length=1
	health=[50.0,90.0,180.0][kind];shield=70 if kind==1 else 0
	var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=[.35,.45,.65][kind];capsule.height=[1.3,1.9,2.3][kind];shape.shape=capsule;shape.position.y=capsule.height*.5;add_child(shape)
	var color=[Color(.65,.37,.1),Color(.12,.32,.48),Color(.36,.13,.12)][kind]
	var torso=arena.box(Vector3(0,capsule.height*.45,0),Vector3(capsule.radius*1.7,capsule.height*.65,.6),arena.material(color,.35,.5),self)
	arena.box(Vector3(0,capsule.height*.82,0),Vector3(.22,capsule.height*.25,.25),arena.material(color.darkened(.25)),self)
	eye=arena.box(Vector3(0,capsule.height-.2,-.22),Vector3(.28,.22,.18),arena.material(Color(1,.45,.1),0,.4,true),self)
	if kind==1:
		shield_mesh=arena.box(Vector3(0,1,-.48),Vector3(1.05,1.5,.12),arena.material(Color(.1,.48,.8),.25,.3),self)
	var label=Label3D.new();label.text=["SCOUT / MOVING","GUARD / FLANK SHIELD","HEAVY / AIM FOR EYE"][kind];label.position.y=capsule.height+.45;label.font_size=24;label.pixel_size=.008;add_child(label)

func take_hit(damage: float, source: Vector3, point: Vector3) -> String:
	if dead: return "DOWN"
	manager.active=true
	if shield>0 and (-global_basis.z).dot((source-global_position).normalized())>.4:
		shield=maxf(0,shield-damage);shield_mesh.visible=shield>0
		return "SHIELD BROKEN" if shield==0 else "SHIELD HIT / FLANK"
	if kind==2: damage*=2.0 if point.y-global_position.y>1.85 else .6
	health-=damage
	if health<=0: dead=true;hide();collision_layer=0;collision_mask=0;return "ENEMY DOWN"
	return "HIT / %d HP" % maxi(0,int(health))

func _physics_process(delta: float) -> void:
	if dead: return
	var target=arena.walker.global_position
	if not manager.active or arena.kit.driving or arena.kit.menu.opened: return
	phase+=delta
	var direction=target-global_position;direction.y=0
	if direction.length()>1: look_at(global_position+direction,Vector3.UP)
	velocity.x=0;velocity.z=0
	if kind==0:
		var desired=origin+Vector3(sin(phase*1.2)*4,0,0)-position;desired.y=0;desired=desired.limit_length(2.8);velocity.x=desired.x;velocity.z=desired.z
	elif kind==2 and direction.length()>12 and position.distance_to(origin)<18:
		var move=direction.normalized()*1.1;velocity.x=move.x;velocity.z=move.z
	velocity.y-=20*delta;move_and_slide()
	timer-=delta
	if timer>0: return
	if charging:
		charging=false;timer=[2.2,3.0,3.8][kind];eye.scale=Vector3.ONE
		var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,aim);ray.exclude=[get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		manager.tracer(ray.from,hit.position if not hit.is_empty() else aim)
		if not hit.is_empty() and hit.collider==arena.walker: manager.hurt([8,12,20][kind])
	elif direction.length()<55:
		var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,target+Vector3.UP);ray.exclude=[get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider==arena.walker:
			aim=target+Vector3.UP;charging=true;timer=.8;eye.scale=Vector3.ONE*1.8
		else: timer=.5
	else: timer=.5
