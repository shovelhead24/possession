extends RefCounted
const Ring=preload("res://world/terrain_drive_ring.gd")
var pairs: Array=[]
func eligible(unit: Node) -> bool:
	return is_instance_valid(unit) and not unit.dead and not unit.elite and not unit.routed and not unit.has_meta("trex_held")
func orders(squad: Node) -> Dictionary:
	var result={}
	for unit in squad.members:
		unit.tactical_role="";unit.tactical_partner=null
	if not squad.captain_alive() or squad.mode not in [squad.Mode.COMBAT,squad.Mode.HUNT] or squad.quiet>60:
		pairs.clear();return result
	var used={}
	for pair in pairs.duplicate():
		if not eligible(pair.a) or not eligible(pair.b) or pair.a.global_position.distance_to(pair.b.global_position)>24:
			pairs.erase(pair);continue
		used[pair.a]=true;used[pair.b]=true
	# Contact (sight or incoming damage) triggers cooperation, not route markers.
	if squad.quiet<2:
		while true:
			var best_a: Node;var best_b: Node;var distance=18.0*18.0
			for a in squad.members:
				if not eligible(a) or used.has(a): continue
				for b in squad.members:
					if a==b or not eligible(b) or used.has(b): continue
					var d=a.global_position.distance_squared_to(b.global_position)
					if d<distance: distance=d;best_a=a;best_b=b
			if not best_a: break
			pairs.append({"a":best_a,"b":best_b,"mover":best_a,"goal":best_a.global_position,"until":squad.clock,"started":false})
			used[best_a]=true;used[best_b]=true
	for pair in pairs:
		var mover=pair.mover
		var arrived=mover.global_position.distance_to(pair.goal)<2
		if not pair.started or arrived or squad.clock>=pair.until:
			if pair.started: pair.mover=pair.b if mover==pair.a else pair.a
			mover=pair.mover
			var toward=(squad.last_known-mover.global_position).slide(Ring.up_at(mover.global_position))
			# Stop advancing at weapon range; don't leapfrog straight into the target.
			var step=toward.normalized()*minf(8,maxf(0,toward.length()-12))
			pair.goal=squad.cover_near(mover.global_position+step,squad.last_known,mover,4)
			pair.until=squad.clock+6;pair.started=true
		var cover=pair.b if mover==pair.a else pair.a
		mover.tactical_role="PAIR ADVANCE";cover.tactical_role="PAIR COVER"
		mover.tactical_partner=cover;cover.tactical_partner=mover
		result[mover]={"point":pair.goal,"speed":2.8,"gait":"Run"}
		result[cover]={"point":cover.global_position,"speed":0.0,"gait":"Idle"}
	return result
