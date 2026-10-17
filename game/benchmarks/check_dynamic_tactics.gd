extends SceneTree
const Nav=preload("res://world/aliens/navigation.gd")
const Squad=preload("res://world/aliens/reptile_squad.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
class Unit extends CharacterBody3D:
	var dead=false
	var elite=false
	var routed=false
	var tactical_role=""
	var tactical_partner: Node
	var crouch_order=false
	var destination=Vector3.ZERO
	var pace=0.0
	func order(point, speed, _gait): destination=point;pace=speed
class Manager extends Node:
	var squads=[]
	var arena={"destruction":{"applied_revision":0},"forge":{"store":{"revision":0}},"painted_trees":{"store":{"records":[],"current":0}}}
	var cover={"slots":[]}
	func ground(p): return {"position":p}
	func clear_body(_p,_h): return true
func _initialize(): run.call_deferred()
func require(ok: bool, message: String):
	if not ok: push_error(message);quit(1)
	assert(ok,message)
func run():
	var manager=Manager.new();root.add_child(manager)
	var squad=Squad.new();squad.manager=manager;root.add_child(squad);squad.set_physics_process(false);squad.authored=true;manager.squads=[squad]
	for i in 5:
		var unit=Unit.new();root.add_child(unit);unit.position=Ring.point(i*3,0,0);squad.members.append(unit)
	squad.captain=squad.members[0];squad.captain.elite=true
	var nav=Nav.new();nav.manager=manager
	squad.members[4].position=Ring.point(100,0,0)
	for i in 600: nav.step()
	require(nav.grids.size()==2,"Scattered squad should have two stable maps")
	for entry in nav.grids: require(entry.next==1089,"Separated member repeatedly reset build")
	var original=nav.grids[0].grid
	for i in range(4): squad.members[i].position+=Vector3(35,0,0)
	nav.step()
	require(nav.grids.any(func(e): return e.grid==original and e.next==1089),"Usable grid discarded during replacement")
	require(nav.select_grid(squad.members[0].position).next==1089,"Incomplete map displaced usable map")
	for i in 600: nav.step()
	for entry in nav.grids: require(entry.next==1089,"Round-robin build starved a grid")
	# Symmetric obstacle: independent seeds can choose either near-shortest side.
	var grid=preload("res://world/aliens/varied_grid.gd").new();grid.region=Rect2i(-8,-8,17,17);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_EUCLIDEAN;grid.update()
	for y in range(-2,3): grid.set_point_solid(Vector2i(0,y),true)
	var choices={}
	for seed_value in range(1,33):
		grid.set_variation(seed_value);var path=grid.get_id_path(Vector2i(-6,0),Vector2i(6,0))
		require(path==grid.get_id_path(Vector2i(-6,0),Vector2i(6,0)),"Noise changed between identical replans")
		for cell in path:
			require(not grid.is_point_solid(cell),"Noise bypassed obstacle")
			if cell.x==0: choices[signi(cell.y)]=true
	require(choices.size()==2,"Noise never varied obstacle side")
	for i in 5: squad.members[i].position=Ring.point(i*3,0,0)
	# Nearest pairs are slots (1,2) and (3,4); hold while no environmental contact.
	squad.authored=false;squad.mode=squad.Mode.PATROL;squad.issue_orders()
	require(squad.assault_pairs.pairs.is_empty(),"Pairs scripted onto patrol")
	squad.report_contact(Vector3(0,0,40));squad.issue_orders()
	require(squad.assault_pairs.pairs.size()==2,"Contact did not form pairs")
	require(squad.members[1].tactical_partner==squad.members[2],"Closest members were not paired")
	var pair=squad.assault_pairs.pairs[0];var mover=pair.mover;var cover=pair.b if mover==pair.a else pair.a
	require(mover.pace>0 and cover.pace==0 and not cover.crouch_order,"Cover member must stop and remain able to fire")
	mover.position=pair.goal;squad.clock+=1.2;squad.issue_orders()
	require(pair.mover==cover,"Arrival did not exchange roles")
	var previous=pair.mover;squad.clock+=7;squad.issue_orders()
	require(pair.mover!=previous,"Blocked advance did not time out")
	squad.members[2].dead=true;squad.issue_orders()
	require(squad.members[1].tactical_partner==null,"Dead partner retained")
	squad.captain.dead=true;squad.issue_orders()
	require(squad.assault_pairs.pairs.is_empty(),"Captain loss must interrupt assault pairs")
	for unit in squad.members:
		if not unit.dead: require(unit.routed and unit.tactical_role.is_empty(),"Flee must override cooperation")
	print("DYNAMIC_TACTICS_PASS: split maps finish, old grid retained, fair build, stable varied obstacle routes, contact-triggered closest pairs, arrival/timeout handoff, casualty cleanup, flee override")
	quit()
