extends SceneTree
const Nav=preload("res://world/aliens/navigation.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
class Ground extends Node:
	func clear_body(_p: Vector3, _height: float) -> bool: return true
func _initialize() -> void: run.call_deferred()
func fixture() -> RefCounted:
	var nav=Nav.new();nav.manager=Ground.new();root.add_child(nav.manager)
	var grid=AStarGrid2D.new();grid.region=Rect2i(-16,-16,33,33);grid.cell_size=Vector2.ONE*4;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	var points={}
	for x in range(-16,17):
		for y in range(-16,17): points[Vector2i(x,y)]=Ring.point(x*4,0,y*4)
	nav.grids.append({"home":Ring.point(0,0,0),"next":1089,"grid":grid,"points":points})
	return nav
func check(ok: bool, message: String) -> void:
	if not ok: push_error(message);quit(1)
	assert(ok,message)
func run() -> void:
	var nav=fixture();var position=Ring.point(1.5,0,1.5);var goal=Ring.point(17.7,0,17.7)
	var path: Array[Vector3]=[];var repath=0.0;var backwards=0;var dt=1.0/60
	for i in range(1800):
		if position.distance_to(goal)<1.4: break
		repath-=dt
		if repath<=0: path=nav.path(position,goal);repath=1.3
		while not path.is_empty() and (path[0]-position).slide(Ring.up_at(position)).length()<1.25: path.pop_front()
		if path.is_empty(): continue
		var movement=(path[0]-position).slide(Ring.up_at(position)).normalized()*1.25*dt
		if movement.dot(goal-position)<-0.00001: backwards+=1
		position+=movement
	check(backwards==0,"Open patrol reversed during periodic replanning")
	check(position.distance_to(goal)<1.4,"Patrol failed to reach offset destination")
	var same=nav.path(Ring.point(0,0,0),Ring.point(1.8,0,1.8))
	check(same[-1].distance_to(Ring.point(1.8,0,1.8))<0.01,"Same-cell exact goal omitted")
	var distant=nav.path(Ring.point(0,0,0),Ring.point(200,0,0))
	check(distant[-1].distance_to(Ring.point(200,0,0))>100,"Path bypassed local grid boundary")
	# A blocked starting cell must retain its recovery entry point.
	var entry=nav.grids[0];entry.points.erase(Vector2i.ZERO);entry.grid.set_point_solid(Vector2i.ZERO,true)
	var recovery=nav.path(Ring.point(0,0,0),Ring.point(20,0,20))
	check(recovery[0].distance_to(entry.points[Vector2i(-1,-1)])<0.01,"Blocked-cell recovery skipped")
	# Wall requires an A* detour; skipping the start must not skip the wall.
	nav=fixture();entry=nav.grids[0]
	for y in range(-3,4): entry.points.erase(Vector2i(1,y));entry.grid.set_point_solid(Vector2i(1,y),true)
	var detour=nav.path(Ring.point(1,0,0),Ring.point(12,0,0));var went_around=false
	for point in detour:
		if absf(Ring.coordinates(point).z)>=16: went_around=true
	check(went_around,"Obstacle detour was bypassed")
	# Steep grid edge must still truncate the path.
	nav=fixture();entry=nav.grids[0];entry.points[Vector2i(1,0)]=Ring.point(4,20,0)
	var cliff=nav.path(Ring.point(0,0,0),Ring.point(8,0,0))
	check(cliff.size()==1 and cliff[0].distance_to(Ring.point(0,0,0))<0.01,"Cliff slope guard bypassed")
	print("PATROL_REPLAN_PASS: zero backwards steps, exact destination reached, blocked-cell recovery, wall detour, cliff guard")
	if "--brief-shot" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,800)
		var host=Node.new();root.add_child(host)
		var loading=load("res://world/workshop_loading.gd").new();loading.brief_path="res://world/rebuild_demo_brief.json";host.add_child(loading)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/patrol-fix-brief.png")
	quit()
