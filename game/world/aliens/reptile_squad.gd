extends Node
const Ring=preload("res://world/terrain_drive_ring.gd")
enum Mode { PATROL, COMBAT, HOLD, HUNT }
var mode := Mode.PATROL
var manager: Node
var members: Array=[]
var captain: Node
var home := Vector3.ZERO
var last_known := Vector3.ZERO
var quiet := 300.0
var clock := 0.0
var sense_timer := 0.0
var sense_elapsed := 0.0
var order_timer := 0.0
var patrol_step := 0
var covering_team := 0
var claimed := {}
var assault_pairs=preload("res://world/aliens/assault_pairs.gd").new()
var authored := false
var authored_mode := 0
var patrol_speed := 1.25
var route: RefCounted
var route_target := Vector3.ZERO
func origin_shifted(delta: Vector3):
	home-=delta;last_known-=delta;route_target-=delta
	for pair in assault_pairs.pairs:pair.goal-=delta
	if route:route.origin_shifted(delta)
func configure_authored(record: Dictionary) -> void:
	authored=true;authored_mode=record.mode;patrol_speed=record.speed;home=preload("res://world/actor_store.gd").point(record.p)
	route=preload("res://world/actor_route.gd").new();route.configure(record)
	route_target=route.points[0]
func report_contact(point: Vector3) -> void:
	if authored_mode==2: return
	last_known=point;quiet=0;mode=Mode.COMBAT
func captain_alive() -> bool:
	return is_instance_valid(captain) and not captain.dead
func advance_memory(delta: float,contact: bool) -> void:
	quiet=0.0 if contact else quiet+delta
	if quiet>=300: mode=Mode.PATROL
	elif quiet>=30: mode=Mode.HUNT
	elif not contact and quiet>2: mode=Mode.HOLD
	else: mode=Mode.COMBAT
func _physics_process(delta: float) -> void:
	if manager.paused(): return
	if authored and mode==Mode.PATROL:
		for unit in members:
			if not unit.dead:
				route_target=route.step(unit.global_position,delta,3.5);break
	clock+=delta;sense_timer-=delta;order_timer-=delta;sense_elapsed+=delta
	if sense_timer<=0:
		sense_timer=.3;var contact=false
		for unit in members:
			if not unit.dead and unit.sees_player(): contact=true;last_known=unit.combat_target.global_position;break
		if authored_mode==2: contact=false;mode=Mode.PATROL;quiet=300
		else: advance_memory(sense_elapsed,contact)
		sense_elapsed=0
		if contact: manager.active=true
	if order_timer<=0:
		order_timer=1.2;issue_orders()
func issue_orders() -> void:
	claimed.clear();covering_team=int(clock/4.5)%2
	var paired=assault_pairs.orders(self)
	for i in range(members.size()):
		var unit=members[i]
		if unit.dead: continue
		unit.crouch_order=false;unit.routed=not captain_alive() and mode!=Mode.PATROL and members.size()>1
		if unit.routed:
			var up=Ring.up_at(unit.global_position)
			var away=(unit.global_position-last_known).slide(up)
			if away.length()<.1: away=Vector3.RIGHT
			away=away.normalized().rotated(up,(i-2)*.36)
			unit.order(unit.global_position+away*22,4.8,"Flee");continue
		if paired.has(unit):
			var command=paired[unit];unit.order(command.point,command.speed,command.gait);continue
		match mode:
			Mode.PATROL:
				if authored:
					var anchor=home if authored_mode==1 else route_target
					var formation=Vector3.ZERO if members.size()==1 else Vector3((i%2)*3,0,int(i/2)*3)
					unit.order(anchor+Ring.tangent_basis(anchor,0)*formation,0.0 if authored_mode==1 or route.holding() else patrol_speed,"Walk")
					continue
				var angle=float(int(clock/18)%4)*PI/2;var offset=Vector3(cos(angle),0,sin(angle))*9
				var formation=Vector3((i%2)*3-1.5,0,int(i/2)*3)
				unit.order(home+Ring.tangent_basis(home,0)*(offset+formation),1.25,"Walk")
			Mode.HUNT:
				# Alternating pairs advance; the other pair keeps its current position.
				if i%2==covering_team:
					unit.order(unit.global_position,0,"Crouch");unit.crouch_order=true
				else:
					var advance=(last_known-unit.global_position).limit_length(12)
					var destination=unit.global_position+advance
					if destination.distance_to(last_known)<5: destination=last_known+Ring.tangent_basis(last_known,0)*Vector3(sin(clock*.12+i),0,cos(clock*.12+i))*7
					unit.order(cover_near(destination,last_known,unit,13),1.65,"Walk");unit.crouch_order=true
			_:
				if unit.elite:
					if last_known.distance_to(home)<17 and unit.global_position.distance_to(last_known)<24 and quiet<2:
						unit.order(last_known,5.2,"Run")
					else:
						unit.order(cover_near(home,last_known,unit,18),2.3,"Run");unit.crouch_order=true
				else:
					var toward=(last_known-home).slide(Ring.up_at(home)).normalized()
					var flank=toward.cross(Ring.up_at(home))*(i-2.5)*3
					var destination=last_known-toward*(14+i*1.7)+flank
					unit.order(cover_near(destination,last_known,unit,10),2.8,"Run");unit.crouch_order=true
func cover_near(point: Vector3,threat: Vector3,unit: Node,radius: float) -> Vector3:
	var best=point;var score=radius*radius;var best_index=-1;var ids: Array[RID]=[]
	for member in members: ids.append(member.get_rid())
	for i in range(manager.cover.slots.size()):
		var slot=manager.cover.slots[i];var distance=slot.distance_squared_to(point)
		if distance>=score or claimed.has(i): continue
		if manager.cover.obscures(slot,threat,ids): best=slot;score=distance;best_index=i
	if best_index>=0: claimed[best_index]=unit
	return best
