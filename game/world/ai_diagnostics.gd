extends CanvasLayer
## Cache AI observations at 4 Hz; project fixed-pixel labels each rendered frame.
const Ring=preload("res://world/terrain_drive_ring.gd")
const Store=preload("res://world/actor_store.gd")
var arena: Node3D
var enabled := true
var clock := 0.0
var samples: Array=[]
var labels := {}
var history := {}
var transitions: Array=[]
var sequence := 0
var preroll: Array=[]
var links: Array=[]
var lines: Node2D
func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;layer=8
	lines=Node2D.new();add_child(lines);lines.draw.connect(draw_links)
func vector(v: Vector3) -> Array: return [v.x,v.y,v.z]
func identify(node: Node) -> String:
	var id=int(node.get_meta("actor_id",0));var slot=int(node.get_meta("slot",-1))
	return ("#%d" % id if id>0 else "runtime-%d" % node.get_instance_id())+(".%d" % slot if slot>=0 else "")
func route_info(route: RefCounted) -> Dictionary:
	if not route: return {}
	return {"waypoint":route.index+1,"waypoints":route.points.size(),"wait_remaining":route.remaining,"finished":route.finished,"holding":route.holding()}
func observe(node: Node3D, elapsed: float) -> Dictionary:
	var id=identify(node);var position=node.global_position;var old=history.get(id,{})
	if old.get("instance",node.get_instance_id())!=node.get_instance_id(): old={}
	var movement=position.distance_to(old.get("position",position))/maxf(.001,elapsed)
	var state={"id":id,"instance":node.get_instance_id(),"position":vector(position),"speed_mps":movement,"mode":"","motion":"","route":{},"health":node.get("health")}
	if node.has_method("order"):
		var squad=node.squad;state.kind="captain" if node.elite else "grunt"
		state.mode=["PATROL","COMBAT","HOLD","HUNT"][squad.mode]
		if squad.mode==0 and squad.authored_mode==1: state.mode="GUARD"
		if node.routed: state.mode="FLEE"
		if node.dead: state.mode="DEAD"
		if node.has_meta("trex_held"): state.mode="HELD BY REX"
		state.route=route_info(squad.route);state.destination=vector(node.destination);state.goal_distance=position.distance_to(node.destination);state.requested_speed=node.pace
		state.path_points=[]
		for point in node.path.slice(0,8): state.path_points.append(vector(point))
		state.path_count=node.path.size();state.repath_in=node.repath;state.last_known=vector(squad.last_known);state.quiet_seconds=squad.quiet
		state.target=identify(node.combat_target) if is_instance_valid(node.combat_target) else ""
		state.tactical_role=node.tactical_role;state.partner=identify(node.tactical_partner) if is_instance_valid(node.tactical_partner) else ""
		state.route_variation=node.route_variation
		var nearest=arena.aliens.navigation.select_grid(position)
		state.grid_cells=nearest.get("next",0);state.grid_total=1089
		state.grid_maps=arena.aliens.navigation.grids.size();state.grid_builds_pending=0
		for entry in arena.aliens.navigation.grids:
			if entry.next<1089: state.grid_builds_pending+=1
		state.grid_open=nearest.get("points",{}).size()
		if not nearest.is_empty():
			var a=Ring.coordinates(nearest.home);var b=Ring.coordinates(node.destination)
			state.goal_outside_grid=absf(wrapf(b.x-a.x,-1500000,1500000))>64 or absf(b.z-a.z)>64
		state.motion="MOVING" if movement>.15 else "IDLE"
		if node.pace>0 and state.goal_distance>2:
			if state.grid_cells<1089: state.motion="BUILDING PATH %d%%" % int(state.grid_cells*100/1089)
			elif node.path.is_empty() and movement<.15: state.motion="NO PATH"
		elif squad.route and squad.route.holding(): state.motion="ROUTE COMPLETE" if squad.route.finished else "WAYPOINT WAIT"
		state.blocker=""
		if node.get_slide_collision_count()>0:
			var obstacle=node.get_slide_collision(0).get_collider()
			if is_instance_valid(obstacle): state.blocker=str(obstacle.get_path())
	elif node.has_method("release_hold"):
		state.kind="trex";state.mode=["AUTO","PATROL","HUNT","HOLD","MANUAL"][node.behavior_mode]
		if node.behavior_mode==0: state.mode="HUNT" if is_instance_valid(node.cached_prey) else "PATROL"
		if node.bite_time>0: state.mode="BITE %d" % node.attack_kind
		elif node.attack_recovery>0: state.mode="ATTACK RECOVERY"
		state.route=route_info(node.authored_route);state.motion=node.movement_blocked.to_upper() if not node.movement_blocked.is_empty() else ("MOVING" if movement>.15 else "IDLE")
		state.blocker=node.last_blocker;state.target=identify(node.cached_prey) if is_instance_valid(node.cached_prey) else "";state.attack=node.telemetry()
		if not node.runtime_active: state.motion="SUSPENDED: "+node.suspension_reason
	else:
		state.kind="warthog";var id_number=int(node.get_meta("actor_id",0));var record=arena.actors.applied.get(id_number,{})
		var route=arena.actors.routes.get(id_number);state.route=route_info(route)
		state.mode="PLAYER" if node==arena.vehicle_kit.car and arena.vehicle_kit.driving else ("PATROL" if record.get("mode",0)==1 else "PARKED")
		state.speed_mps=node.linear_velocity.length();state.throttle=node.throttle;state.steer=node.turn;state.braking=node.braking
		state.motion="MOVING" if state.speed_mps>.15 else "IDLE"
		if route:
			state.destination=vector(route.points[route.index]);state.goal_distance=position.distance_to(route.points[route.index])
			if route.holding(): state.motion="ROUTE COMPLETE" if route.finished else "WAYPOINT WAIT"
		if node.streaming_suspended: state.motion="TERRAIN SUSPENDED"
		elif state.mode=="PATROL" and node.get_meta("patrol_status","")=="TERRAIN AHEAD UNLOADED": state.motion="TERRAIN AHEAD UNLOADED"
	var wants_motion=state.mode in ["PATROL","HUNT","COMBAT","FLEE"] and state.motion in ["MOVING","IDLE","NO PATH","COLLISION","SLOPE","TERRAIN_SUPPORT"]
	if node.has_method("order"): wants_motion=wants_motion and node.pace>0 and state.goal_distance>2 and not node.dead
	if node.has_method("release_hold"):
		wants_motion=wants_motion and node.runtime_active and (is_instance_valid(node.cached_prey) or (node.behavior_mode in [0,1] and (not node.authored_route or not node.authored_route.holding())))
		if node.authored_route and node.authored_route.holding() and not is_instance_valid(node.cached_prey) and node.bite_time<=0: state.motion="ROUTE COMPLETE" if node.authored_route.finished else "WAYPOINT WAIT";wants_motion=false
	var stalled=float(old.get("stalled",0))+elapsed if wants_motion and movement<.15 else 0.0
	state.stalled_seconds=stalled
	if stalled>=2 and state.motion=="IDLE": state.motion="STALLED (requested movement)"
	if arena.aliens.paused(): state.motion="PAUSED";stalled=0;state.stalled_seconds=0
	var signature=state.mode+"/"+state.get("tactical_role","")+"/"+state.get("partner","")+"/"+("BUILDING PATH" if state.motion.begins_with("BUILDING PATH") else state.motion)
	if old.get("signature","")!=signature:
		sequence+=1;var event={"sequence":sequence,"time_ms":Time.get_ticks_msec(),"id":id,"kind":state.kind,"from":old.get("signature","SPAWN"),"to":signature,"position":state.position}
		transitions.append(event)
		if transitions.size()>80: transitions.pop_front()
		if arena.get("jitter_trace"): arena.jitter_trace.write_event("ai_transition",event)
	history[id]={"instance":node.get_instance_id(),"position":position,"stalled":stalled,"signature":signature}
	return state
func refresh(elapsed: float) -> void:
	samples=[];var alive={};var nodes=arena.aliens.enemies.duplicate()
	for rex in get_tree().get_nodes_in_group("tyrants"): nodes.append(rex)
	for id in arena.actors.live:
		var actor=arena.actors.live[id]
		if is_instance_valid(actor) and actor.has_method("set_controls"): nodes.append(actor)
	for node in nodes:
		if not is_instance_valid(node): continue
		var state=observe(node,elapsed);samples.append(state);var id=state.id;alive[id]=true
		if not labels.has(id):
			var label=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",16)
			label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);label.add_theme_constant_override("outline_size",4);label.add_theme_color_override("font_outline_color",Color(.02,.025,.03,.95))
			var background=StyleBoxFlat.new();background.bg_color=Color(.015,.025,.03,.86);background.set_corner_radius_all(3)
			background.content_margin_left=6;background.content_margin_right=6;background.content_margin_top=3;background.content_margin_bottom=3
			label.add_theme_stylebox_override("normal",background)
			add_child(label);labels[id]={"label":label,"node":node}
		labels[id].node=node
		var route=state.route;var waypoint=" / WP %d/%d" % [route.waypoint,route.waypoints] if not route.is_empty() else ""
		var hp=" / %d HP" % state.health if state.health!=null else ""
		labels[id].label.text="%s %s / %s%s%s\n%s / %.1f m/s" % [id,state.kind.to_upper(),state.mode,waypoint,hp,state.motion,state.speed_mps]
		if not state.get("tactical_role","").is_empty(): labels[id].label.text+="\n"+state.tactical_role+" with "+state.partner
		labels[id].label.modulate=Color(1,.6,.25) if state.stalled_seconds>=2 or state.motion=="NO PATH" else Color(.65,1,.8)
	var frame={"sample_time_ms":Time.get_ticks_msec(),"actors":samples}
	preroll.append(frame)
	if preroll.size()>20: preroll.pop_front()
	if arena.get("jitter_trace"): arena.jitter_trace.write_event("ai_snapshot",frame)
	for id in labels.keys():
		if not alive.has(id): labels[id].label.queue_free();labels.erase(id);history.erase(id)
func _process(delta: float) -> void:
	if not arena or not arena.ready_to_play or not arena.actors: return
	clock+=delta
	if clock>=.25: var elapsed=clock;clock=0;refresh(elapsed)
	var display=enabled and arena.loading.dismissed and not arena.editor.opened and not arena.collision_debug.hud_hidden
	links=[]
	var occupied: Array[Rect2]=[];var viewport=arena.get_viewport().get_visible_rect()
	for entry in labels.values():
		var label: Label=entry.label;var node=entry.node;label.hide()
		if not display or not is_instance_valid(node) or not node.is_visible_in_tree() or node.get("dead")==true: continue
		var point=node.global_position+Ring.up_at(node.global_position)*(6 if node.has_method("release_hold") else 2.8)
		if arena.camera.is_position_behind(point) or point.distance_to(arena.camera.global_position)>220: continue
		var screen=arena.camera.unproject_position(point);label.reset_size();var rect=Rect2(screen-Vector2(label.size.x*.5,label.size.y+8),label.size)
		if not viewport.has_point(screen): continue
		rect.position.x=clampf(rect.position.x,4,maxf(4,viewport.size.x-rect.size.x-4));rect.position.y=clampf(rect.position.y,4,maxf(4,viewport.size.y-rect.size.y-4))
		for other in occupied:
			if rect.intersects(other): rect.position.y=other.position.y-rect.size.y-4
		if rect.position.y<0: continue
		label.position=rect.position;label.show();occupied.append(rect)
		links.append([Vector2(clampf(screen.x,rect.position.x,rect.end.x),rect.end.y),screen])
	lines.queue_redraw()
func telemetry() -> Dictionary:
	return {"sample_hz":4,"sample_time_ms":Time.get_ticks_msec()-int(clock*1000),"labels_enabled":enabled,"actor_count":samples.size(),"last_transition":sequence}

func draw_links() -> void:
	for link in links:
		lines.draw_line(link[0],link[1],Color(.8,1,.9,.6),1.0,true)
		lines.draw_circle(link[1],2.0,Color(.8,1,.9,.8))
