extends SceneTree
const Store=preload("res://world/actor_store.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs"
func _initialize():
	create_timer(240).timeout.connect(func(): push_error("Actor world timeout");quit(1))
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: push_error("ACTOR_FAIL: "+message);quit(1)
	assert(value,message)
func capture(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
func run():
	Engine.max_fps=120
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	check(arena.actors.store.path.contains("actor-test-saves"),"Actor tests require isolated saves")
	await capture("actor-editor-brief.png")
	arena.loading.close();arena.diagnostic=true
	var manager=arena.aliens;var world=arena.actors;var editor=arena.editor;var store=world.store
	arena.vehicle_kit.driving=false;arena.on_foot.active=false
	editor.toggle();editor.select_tool("actors")
	var before=store.snapshot();store.records=[];store.commit(before);world.synchronize()
	var car=arena.vehicle_kit.car;var origin=Ring.coordinates(car.position)
	await create_timer(2).timeout
	var places=[]
	for i in 80:
		var angle=i*2.4;var distance=18+sqrt(i)*6
		var point=manager.safe_spawn(Ring.point(origin.x+cos(angle)*distance,origin.y,origin.z+sin(angle)*distance))
		if point==Vector3.INF: continue
		var separated=true
		for other in places:
			if point.distance_to(other)<18: separated=false
		if separated: places.append(point)
		if places.size()==4: break
	check(places.size()==4,"Fixture has four clear grounded placement sites")
	var ids=[];var kinds=["grunt","captain","trex","warthog"]
	for i in 4:
		editor.begin_place(kinds[i]);editor.commit_at(places[i]);ids.append(editor.actor_id)
		check(Store.valid_record(editor.selected()),"Valid placement: "+kinds[i])
		if kinds[i]=="trex": editor.change("mode",3)
		elif kinds[i]=="warthog": editor.change("mode",0)
		else: editor.change("mode",2)
		editor.begin_operation("add_point");editor.commit_at(places[i]+Ring.tangent_basis(places[i],0)*Vector3(12,0,-14))
		editor.commit_at(places[i]);editor.operation=""
	editor.select_actor(ids[0]);editor.waypoint=0;var first=editor.selected().route[0].duplicate()
	editor.reorder_point(1);check(editor.selected().route[1]==first,"Waypoint reorder")
	editor.undo();check(editor.selected().route[0]==first,"Route undo")
	editor.redo();editor.undo()
	var original=editor.selected().duplicate(true);editor.begin_operation("move");editor.commit_at(places[0]+Ring.tangent_basis(places[0],0)*Vector3(3,0,0))
	check(editor.selected().p!=original.p and editor.selected().route!=original.route,"Moving an actor translates its route")
	editor.undo();check(editor.selected()==original,"Actor move undo")
	editor.copy_actor();check(store.records.size()==4,"Copy remains a draft until placed");editor.commit_at(places[0]+Vector3(5,0,0));check(store.records.size()==5,"Copy actor")
	editor.delete_actor();check(store.records.size()==4,"Delete copy")
	editor.select_actor(ids[0]);editor.focus_actor();await create_timer(.4).timeout
	await capture("actor-editor-panel.png")
	check(store.save(),"Save actor layout");var saved=store.snapshot();check(store.load_saved(),"Reload actor layout");check(store.records.size()==saved.size(),"Round trip record count")
	for i in saved.size():
		var got=store.records[i];var expected=saved[i]
		check(got.id==expected.id and got.kind==expected.kind and got.mode==expected.mode and got.loop==expected.loop and got.enabled==expected.enabled,"Round trip configuration")
		check(Store.point(got.p).distance_to(Store.point(expected.p))<.0001 and got.route.size()==expected.route.size(),"Round trip position")
		for j in got.route.size(): check(Store.point(got.route[j]).distance_to(Store.point(expected.route[j]))<.0001,"Round trip route accuracy")
	editor.toggle();await create_timer(3).timeout
	check(world.live.has(ids[2]) and is_instance_valid(world.live[ids[2]]),"Placed Rex spawns")
	check(world.live.has(ids[3]) and is_instance_valid(world.live[ids[3]]),"Placed Warthog spawns")
	check(manager.enemies.size()==2,"Placed grunt and captain spawn individually")
	var rex=world.live[ids[2]];var placed_car=world.live[ids[3]]
	check(placed_car.corners.size()==4,"Placed Warthog retains four-wheel suspension")
	check(rex.behavior_mode==3 and rex.authored_route.points.size()==2,"Rex receives authored behavior and route")
	var grunt=manager.enemies.filter(func(unit): return not unit.elite)[0]
	var starting=grunt.position
	await create_timer(5).timeout
	print("ACTOR_MOVEMENT ",grunt.position.distance_to(starting)," pace=",grunt.pace," destination=",grunt.destination," path=",grunt.path.size())
	check(grunt.position.distance_to(starting)>1,"Alien follows authored patrol")
	check(not grunt.sees_player(),"Patrol-only alien does not acquire firing target")
	var entered=false
	for offset in [Vector3(-3.2,0,0),Vector3(3.2,0,0),Vector3(0,0,4.5)]:
		var landing=arena.on_foot.find_ground(placed_car.global_transform*offset)
		if landing.is_empty(): continue
		arena.on_foot.activate_at(landing.feet)
		if arena.on_foot.enter_vehicle(): entered=true;break
	check(entered and arena.vehicle_kit.car==placed_car,"Enter nearby authored Warthog on foot")
	check(arena.vehicle_kit.menu.car==placed_car,"Tuning switches to placed vehicle")
	arena.vehicle_kit.driving=true;arena.vehicle_kit.test_controls=true;arena.vehicle_kit.test_throttle=.5
	var car_start=placed_car.position;await create_timer(2).timeout
	check(placed_car.position.distance_to(car_start)>.5,"Placed Warthog drives with existing controls")
	arena.vehicle_kit.test_controls=false;arena.vehicle_kit.driving=false;arena.vehicle_kit.select_vehicle(arena.vehicle_kit.original_car)
	editor.toggle();editor.select_actor(ids[3]);editor.change("mode",1);editor.change("speed",5.0);editor.toggle()
	await create_timer(2).timeout;placed_car=world.live[ids[3]];car_start=placed_car.position
	await create_timer(3).timeout
	print("ACTOR_CAR_PATROL ",placed_car.position.distance_to(car_start)," controls ",placed_car.throttle,"/",placed_car.turn)
	check(placed_car.position.distance_to(car_start)>.5,"Warthog patrol drives")
	# Runtime reset must preserve the authored layout and avoid duplicate rigs.
	var count=store.records.size();manager.reset();await create_timer(2).timeout
	check(store.records.size()==count,"Encounter reset preserves authoring")
	check(get_nodes_in_group("tyrants").size()==1,"Reset creates one authored Rex")
	var current_rex=world.live[ids[2]];current_rex.health=3210;current_rex.authored_route.index=1
	world.retire(ids[2]);await process_frame
	check(world.spawn_actor(store.find(ids[2])),"Respawn streamed Rex")
	check(world.live[ids[2]].health==3210 and world.live[ids[2]].authored_route.index==1,"Streaming preserves Rex health and waypoint")
	world.live[ids[2]].take_hit(9999,places[0],places[2]);await process_frame
	world.stream_actors();check(world.snapshots[ids[2]].get("dead",false),"Authored Rex death persists")
	check(not world.spawn_actor(store.find(ids[2])),"Dead Rex does not respawn before F7")
	manager.reset();await create_timer(2).timeout
	editor.toggle();editor.select_actor(ids[3]);editor.focus_actor();await create_timer(.3).timeout;await capture("actor-editor-warthog.png")
	print("ACTOR_WORLD_PASS: editor placement, route editing, undo/redo, save/reload, individual aliens, Rex behavior, vehicle suspension, driving, patrol and encounter reset")
	arena.free();quit()
