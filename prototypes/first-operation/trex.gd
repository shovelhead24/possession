extends CharacterBody3D
var arena: Node
var manager: Node
var model: Node3D
var health := 3600.0
const SCALE_HEIGHT := 24.0
const BITE_REACH := 16.0
var patrol=[Vector3(-40,0,-60),Vector3(90,0,-130),Vector3(120,0,-290),Vector3(-100,0,-250)]
var waypoint := 0
var cooldown := 0.0
var bite_target: Node3D
var bite_time := 0.0
var bite_applied := false
var bite_number := 0
var animator: AnimationPlayer
var skeleton: Skeleton3D
var root_bone := -1
var telemetry_clock := 0.0
func _ready():
	floor_snap_length=.9;floor_max_angle=deg_to_rad(48)
	model=arena.kit.imported("C:/Games/possession/assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb");add_child(model)
	var a=arena.kit.bounds(model);model.scale*=SCALE_HEIGHT/maxf(a.size.y,.01);a=arena.kit.bounds(model);model.position.x-=a.get_center().x;model.position.z-=a.get_center().z
	# The asset faces +Z; gameplay movement and the bite point face -Z.
	model.rotate_y(PI)
	animator=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton: root_bone=skeleton.find_bone("ScarfaceGiant_01")
	if animator:
		animator.get_animation("CINEMA_4D_Main").loop_mode=Animation.LOOP_LINEAR
		animator.play("CINEMA_4D_Main")
	var collision=CollisionShape3D.new();var shape=CapsuleShape3D.new();shape.radius=5.0;shape.height=18.0;collision.shape=shape;collision.position.y=9.0;add_child(collision)
	var label=Label3D.new();label.text="TYRANT / INDISCRIMINATE";label.position.y=20;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.pixel_size=.01;add_child(label)
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
func begin_bite(prey: Node3D) -> void:
	# Lock one victim for a short attack.  Chasing while the timeline is playing
	# made the mouth appear to clamp on indefinitely, and let target selection
	# silently swap victims before damage was delivered.
	bite_number+=1;bite_target=prey;bite_time=.34;bite_applied=false;cooldown=1.15
	bite_event("START #%d target=%s distance=%.2f" % [bite_number,prey.name,position.distance_to(prey.position)])
	if animator:
		animator.play("CINEMA_4D_Main");animator.speed_scale=2.2
func apply_bite(victim: Node3D) -> void:
	if not is_instance_valid(victim):
		bite_event("MISS #%d invalid target" % bite_number);return
	# The player has no take_hit method: its health lives on PracticeRange.
	# Check it first so a player seated in a vehicle still takes the bite.
	if victim==arena.walker:
		bite_event("HIT #%d player=%s health_before=%s" % [bite_number,victim.name,str(manager.health)])
		manager.hurt(140,"T-REX BITE")
		bite_event("DONE #%d player health_after=%s" % [bite_number,str(manager.health)])
	elif victim.has_method("take_hit"):
		bite_event("HIT #%d enemy=%s" % [bite_number,victim.name])
		var result=victim.take_hit(360,position,victim.position+Vector3.UP)
		bite_event("DONE #%d enemy result=%s health_after=%s dead=%s" % [bite_number,result,str(victim.get("health")),str(victim.get("dead"))])
	else:
		bite_event("MISS #%d target=%s has no damage route" % [bite_number,victim.name])
func _physics_process(delta):
	cooldown-=delta
	if bite_time>0:
		bite_time-=delta
		if not bite_applied and bite_time<=.16:
			bite_applied=true;apply_bite(bite_target)
		if bite_time<=0:
			bite_event("RELEASE #%d applied=%s" % [bite_number,str(bite_applied)]);bite_target=null
		position.y=arena.height_at(position.x,position.z)+.05
		velocity=Vector3.ZERO
		return
	var prey=target();var target_point=prey.position
	if position.distance_to(prey.position)>150: target_point=patrol[waypoint]
	var move=target_point-position;move.y=0
	if move.length()<8 and position.distance_to(prey.position)>150: waypoint=(waypoint+1)%patrol.size()
	if move.length()>.1:
		rotation.y=lerp_angle(rotation.y,atan2(-move.x,-move.z),minf(1,delta*4))
		# Keep patrol independent of the large collision capsule; the terrain
		# height field supplies grounding, so trees and ramp seams cannot freeze it.
		position+=move.normalized()*9.0*delta
		if animator: animator.speed_scale=1.35 if position.distance_to(prey.position)<150 else .8
	else: velocity=Vector3.ZERO
	# The arena terrain is a height field. Pin the predator's root to it after
	# horizontal movement so an animation or a missed floor frame cannot leave
	# the whole creature suspended above the ground.
	position.y=arena.height_at(position.x,position.z)+.05
	velocity=Vector3.ZERO
	if position.distance_to(prey.position)<BITE_REACH and cooldown<=0:
		begin_bite(prey)

func _process(_delta):
	# The single imported timeline contains root-bone lift. Keep its limb work
	# but remove that vertical root motion, because world position is terrain-led.
	if skeleton and root_bone>=0:
		var pose=skeleton.get_bone_pose_position(root_bone);pose.y=0;skeleton.set_bone_pose_position(root_bone,pose)
	# Run after the animation player: terrain owns the actor root, while the
	# mesh stays at its native vertical origin instead of inheriting a 3.8m lift.
	global_position.y=arena.height_at(global_position.x,global_position.z)+.05
	telemetry_clock-=_delta
	if telemetry_clock<=0:
		telemetry_clock=.5;append_telemetry()

func append_telemetry():
	var path="user://trex-diagnostics.log"
	var file=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	if not file: return
	file.seek_end()
	var a=arena.kit.bounds(model);var terrain=arena.height_at(position.x,position.z)
	file.store_line("body=%s terrain=%.3f model_global=%s model_local=%s bounds=%s bottom=%.3f anim=%.3f root_pose=%s" % [global_position,terrain,model.global_position,model.position,a,model.global_position.y+a.position.y,animator.current_animation_position if animator else -1.0,skeleton.get_bone_pose_position(root_bone) if skeleton and root_bone>=0 else Vector3.ZERO])
func bite_event(message: String) -> void:
	var file=FileAccess.open("user://trex-bite.log",FileAccess.READ_WRITE if FileAccess.file_exists("user://trex-bite.log") else FileAccess.WRITE_READ)
	if not file: return
	file.seek_end();file.store_line("%.3f %s" % [Time.get_ticks_msec()*.001,message])
