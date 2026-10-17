extends RefCounted
const Ring=preload("res://world/terrain_drive_ring.gd")
var manager: Node
var grids: Array=[]
var revision := ""
var tree_state: Variant
var build_cursor := 0
func invalidate() -> void:
	for entry in grids: entry.grid.clear()
	grids.clear()
func step() -> void:
	var stamp=str(manager.arena.destruction.applied_revision)+":"+str(manager.arena.forge.store.revision)+":"+str(manager.arena.painted_trees.store.records.size())
	var current_tree_state=manager.arena.painted_trees.store.get("current")
	if stamp!=revision or current_tree_state!=tree_state:
		revision=stamp;tree_state=current_tree_state;invalidate()
	# Keep completed local maps while separated members request new coverage.
	# A distant member must never reset another member's in-progress map.
	for entry in grids.duplicate():
		var needed=false
		if is_instance_valid(entry.squad):
			for unit in entry.squad.members:
				if not unit.dead and unit.global_position.distance_to(entry.home)<80: needed=true;break
		if not needed: grids.erase(entry)
	for squad in manager.squads:
		for unit in squad.members:
			if unit.dead: continue
			var covered=false
			for entry in grids:
				if entry.squad==squad and unit.global_position.distance_to(entry.home)<32: covered=true;break
			if covered: continue
			var grid=preload("res://world/aliens/varied_grid.gd").new();grid.region=Rect2i(-16,-16,33,33);grid.cell_size=Vector2.ONE*4;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_EUCLIDEAN;grid.update()
			for x in range(-16,17):
				for y in range(-16,17): grid.set_point_solid(Vector2i(x,y),true)
			grids.append({"squad":squad,"home":unit.global_position,"grid":grid,"next":0,"points":{}})
	var began=Time.get_ticks_usec();var count=0
	var attempts=0
	while not grids.is_empty() and count<12 and attempts<grids.size()+12 and Time.get_ticks_usec()-began<1000:
		var entry=grids[build_cursor%grids.size()];build_cursor+=1;attempts+=1
		if entry.next>=1089: continue
		var cell=Vector2i(entry.next%33-16,int(entry.next/33)-16);entry.next+=1;count+=1
		var c=Ring.coordinates(entry.home);var wanted=Ring.point(c.x+cell.x*4,c.y,c.z+cell.y*4)
		var ground=manager.ground(wanted)
		if ground.is_empty() or not manager.clear_body(ground.position,1.95): continue
		entry.points[cell]=ground.position;entry.grid.set_point_solid(cell,false)
func select_grid(start: Vector3) -> Dictionary:
	var best: Dictionary={};var score=INF
	for candidate in grids:
		var c=Ring.coordinates(candidate.home);var p=Ring.coordinates(start)
		var inside=absf(wrapf(p.x-c.x,-1500000,1500000))<=64 and absf(p.z-c.z)<=64
		if not inside: continue
		var cost=start.distance_squared_to(candidate.home)+(0.0 if candidate.next>=1089 else 1000000.0)
		if cost<score: score=cost;best=candidate
	return best
func path(start: Vector3, end: Vector3, variation: int=0) -> Array[Vector3]:
	var result: Array[Vector3]=[];var entry=select_grid(start)
	if entry.is_empty() or entry.next<1089: result.append(start);return result
	var origin=Ring.coordinates(entry.home);var a=Ring.coordinates(start);var b=Ring.coordinates(end)
	var ac=Vector2i(clampi(roundi(wrapf(a.x-origin.x,-1500000,1500000)/4),-16,16),clampi(roundi((a.z-origin.z)/4),-16,16))
	var requested_end=Vector2i(roundi(wrapf(b.x-origin.x,-1500000,1500000)/4),roundi((b.z-origin.z)/4))
	var bc=Vector2i(clampi(requested_end.x,-16,16),clampi(requested_end.y,-16,16))
	var start_cell=ac;var end_cell=bc
	ac=open_cell(entry,ac);bc=open_cell(entry,bc)
	if not entry.points.has(ac) or not entry.points.has(bc): result.append(start);return result
	if entry.grid.has_method("set_variation"): entry.grid.set_variation(variation)
	for cell in entry.grid.get_id_path(ac,bc,true):
		var point: Vector3=entry.points[cell]
		if not result.is_empty():
			var up=Ring.up_at(point);var change=point-result[-1]
			if absf(change.dot(up))>change.slide(up).length()*1.0: break
		result.append(point)
	# Replanning must not send a unit back to the centre of its current cell.
	# Keep a snapped entry cell when the starting cell is blocked; that is recovery.
	if not result.is_empty() and ac==start_cell:
		result.pop_front()
	# Cell centres can be farther from an authored goal than the arrival radius.
	# Finish at the actual goal only when A* reached its original, open goal cell.
	if bc==end_cell and bc==requested_end and (ac==bc or (not result.is_empty() and result[-1]==entry.points[bc])):
		var previous: Vector3=start if result.is_empty() else result[-1]
		var change=end-previous;var up=Ring.up_at(end)
		if absf(change.dot(up))<=maxf(0.05,change.slide(up).length()) and manager.clear_body(end,1.95):
			result.append(end)
	if result.is_empty(): result.append(start)
	return result
func open_cell(entry: Dictionary, cell: Vector2i) -> Vector2i:
	if entry.points.has(cell): return cell
	for radius in range(1,5):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var next=cell+Vector2i(x,y)
				if entry.points.has(next): return next
	return cell
