extends Node
## Bounded, physics-rate flight recorder. No terrain/vehicle behaviour changes.
const HISTORY_USEC := 5000000
const CAPACITY := 600
var arena: Node
var history: Array = []
var cursor := 0
var active_id := 0
var pending: Array = []
var previous := {}

func _ready() -> void:
	process_physics_priority=100 # Observe after vehicle controllers have stepped.

func vector(v: Vector3) -> Array:
	return [v.x,v.y,v.z]

func remember(sample: Dictionary) -> void:
	if history.size()<CAPACITY: history.append(sample)
	else: history[cursor]=sample
	cursor=(cursor+1)%CAPACITY
	if active_id: pending.append(sample)

func recent(now: int) -> Array:
	var result: Array=[]
	for offset in history.size():
		var index := (cursor+offset)%history.size() if history.size()==CAPACITY else offset
		if now-int(history[index].sample_usec)<=HISTORY_USEC: result.append(history[index])
	return result

func drain() -> void:
	if pending.is_empty(): return
	arena.trace_edit("vehicle_samples",{"marker_id":active_id,"phase":"capture","samples":pending})
	pending=[]

func mark(id: int, begin: bool) -> void:
	if begin:
		active_id=id
		arena.trace_edit("vehicle_samples",{"marker_id":id,"phase":"pre_roll","samples":recent(Time.get_ticks_usec())})
	else:
		drain();active_id=0

func _process(_delta: float) -> void:
	drain() # Serialization stays outside the physics callback.

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	var kit: Node=arena.live_kit()
	if not is_instance_valid(kit) or not is_instance_valid(kit.vehicle_system): return
	var bodies: Array=[]
	for body in kit.vehicle_system.vehicles:
		var wheels: Array=[]
		var corners: Variant=body.get("corners")
		if corners is Array:
			for i in corners.size():
				var c: Dictionary=corners[i]
				var key := str(body.get_instance_id())+":"+str(i)
				var grounded: bool=c.get("grounded",false)
				var contact: Vector3=c.get("contact",Vector3.ZERO)
				var old: Dictionary=previous.get(key,{})
				var probe: Dictionary={"tested":false}
				if old.get("grounded",false) and not body.freeze:
					var q := PhysicsRayQueryParameters3D.create(old.contact+Vector3.UP,old.contact-Vector3.UP*2,1|4)
					q.exclude=[body.get_rid()];q.exclude+=body.suspension_exclusions
					var hit: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(q)
					probe={"tested":true,"hit":not hit.is_empty()}
					if not hit.is_empty():
						probe.height_delta=hit.position.y-old.contact.y
						probe.collider_id=hit.collider_id
				wheels.append({"index":i,"grounded":grounded,"contact":vector(contact) if grounded else null,"normal":vector(c.get("trace_normal",Vector3.ZERO)),"collider_id":c.get("trace_collider",0),"travel":c.travel,"travel_delta":float(c.travel)-float(old.get("travel",c.travel)),"compression":c.compression,"omega":c.get("omega",0),"slip":c.get("slip",0),"same_point_probe":probe})
				previous[key]={"grounded":grounded,"contact":contact,"travel":c.travel}
		var limit: float=body.stream_speed_limit
		bodies.append({"id":body.get_instance_id(),"name":str(body.name),"position":vector(body.global_position),"velocity":vector(body.linear_velocity),"angular_velocity":vector(body.angular_velocity),"speed_limit":limit if is_finite(limit) else null,"stream_braking":body.stream_braking,"suspended":body.streaming_suspended,"frozen":body.freeze,"controlled":body.controlled,"throttle":body.throttle,"turn":body.turn,"braking":body.braking,"balanced_braking":body.balanced_braking,"wheels":wheels})
	remember({"sample_usec":started,"physics_frame":Engine.get_physics_frames(),"delta":delta,"editing":arena.editing,"jobs":arena.stream_jobs.size(),"resident_chunks":arena.chunks.size(),"vehicles":bodies,"sampling_ms":(Time.get_ticks_usec()-started)/1000.0})
