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
var frame_history: Array=[]
var frame_cursor := 0
var pending_frames: Array=[]
var last_frame_usec := 0

func write_event(event: String, data: Dictionary) -> void:
	arena.trace_edit(event,data)

func traced_vehicles() -> Array:
	var kit: Node=arena.live_kit()
	return kit.vehicle_system.vehicles if is_instance_valid(kit) and is_instance_valid(kit.vehicle_system) else []

func terrain_context() -> Dictionary:
	return {"editing":arena.editing,"jobs":arena.stream_jobs.size(),"resident_chunks":arena.chunks.size()}

func frame_context() -> Dictionary:
	return {"terrain_plan_ms":arena.terrain_lod.plan_ms if arena.terrain_lod else 0.0}

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
	if not pending.is_empty():
		write_event("vehicle_samples",{"marker_id":active_id,"phase":"capture","samples":pending})
		pending=[]
	if not pending_frames.is_empty():
		write_event("frame_samples",{"marker_id":active_id,"phase":"capture","samples":pending_frames})
		pending_frames=[]

func mark(id: int, begin: bool) -> void:
	if begin:
		active_id=id
		write_event("vehicle_samples",{"marker_id":id,"phase":"pre_roll","samples":recent(Time.get_ticks_usec())})
		var frames: Array=[]
		for offset in frame_history.size():
			var index := (frame_cursor+offset)%frame_history.size() if frame_history.size()==CAPACITY else offset
			if Time.get_ticks_usec()-int(frame_history[index].sample_usec)<=HISTORY_USEC: frames.append(frame_history[index])
		write_event("frame_samples",{"marker_id":id,"phase":"pre_roll","samples":frames})
	else:
		drain();active_id=0

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if last_frame_usec and not traced_vehicles().is_empty():
		var sample := {"sample_usec":now,"frame_ms":(now-last_frame_usec)/1000.0,"cpu_monitor_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		sample.merge(frame_context())
		if frame_history.size()<CAPACITY: frame_history.append(sample)
		else: frame_history[frame_cursor]=sample
		frame_cursor=(frame_cursor+1)%CAPACITY
		if active_id: pending_frames.append(sample)
	last_frame_usec=now
	drain() # Serialization stays outside the physics callback.

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	var vehicles := traced_vehicles()
	if vehicles.is_empty(): return
	var bodies: Array=[]
	for body in vehicles:
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
					var q := PhysicsRayQueryParameters3D.create(old.contact+body.global_basis.y,old.contact-body.global_basis.y*2,int(body.get("suspension_mask")) if body.get("suspension_mask")!=null else 1|4)
					q.exclude=[body.get_rid()];q.exclude+=body.suspension_exclusions
					var hit: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(q)
					probe={"tested":true,"hit":not hit.is_empty()}
					if not hit.is_empty():
						probe.height_delta=hit.position.y-old.contact.y
						probe.collider_id=hit.collider_id
						probe.collider_layer=hit.collider.collision_layer
				wheels.append({"index":i,"grounded":grounded,"contact":vector(contact) if grounded else null,"normal":vector(c.get("trace_normal",Vector3.ZERO)),"collider_id":c.get("trace_collider",0),"travel":c.travel,"travel_delta":float(c.travel)-float(old.get("travel",c.travel)),"compression":c.compression,"omega":c.get("omega",0),"slip":c.get("slip",0),"same_point_probe":probe})
				previous[key]={"grounded":grounded,"contact":contact,"travel":c.travel}
				wheels[-1].merge(c.get("trace_forces",{}))
		var limit: float=body.stream_speed_limit
		bodies.append({"id":body.get_instance_id(),"name":str(body.name),"position":vector(body.global_position),"velocity":vector(body.linear_velocity),"angular_velocity":vector(body.angular_velocity),"speed_limit":limit if is_finite(limit) else null,"stream_braking":body.stream_braking,"suspended":body.streaming_suspended,"frozen":body.freeze,"controlled":body.controlled,"throttle":body.throttle,"turn":body.turn,"braking":body.braking,"balanced_braking":body.balanced_braking,"wheels":wheels})
		bodies[-1].stream_brake_amount=body.stream_brake_amount
		bodies[-1].stream_drive_scale=body.stream_drive_scale
		bodies[-1].rotation=vector(body.global_rotation)
		bodies[-1].chassis_contacts=body.get_contact_count()
		bodies[-1].suspension_mask=body.get("suspension_mask")
	var sample := {"sample_usec":started,"physics_frame":Engine.get_physics_frames(),"delta":delta,"vehicles":bodies,"sampling_ms":(Time.get_ticks_usec()-started)/1000.0}
	sample.merge(terrain_context())
	remember(sample)
