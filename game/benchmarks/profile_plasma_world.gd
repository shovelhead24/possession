extends SceneTree
class Flag extends RefCounted:
	var opened := false
	var dismissed := true
	func log_event(text: String) -> void: print(text)
class Streamer extends RefCounted:
	func ready_at(_p: Vector3) -> bool: return true
class Foot extends CharacterBody3D:
	var active := true
class Kit extends RefCounted:
	var menu := Flag.new()
class Arena extends Node3D:
	var ready_to_play := true
	var on_foot: Foot
	var editor := Flag.new()
	var loading := Flag.new()
	var vehicle_kit := Kit.new()
	var streamer := Streamer.new()
	var camera: Camera3D
	var forge: Node
	var painted_trees: Node
func _initialize() -> void: run.call_deferred()
var w: Node
func sample(label: String, firing: bool, hide_model: bool) -> void:
	w.container.visible=not hide_model
	w.trigger_held=firing;w.ammo[2]=10000
	await create_timer(3).timeout
	var trace_start: int=w.trace_usec
	var count_start: int=w.trace_count
	var redraw_start: int=w.view_redraws
	var times := [];var last := Time.get_ticks_usec();var draws := 0.0
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	w.trigger_held=false
	var total := 0.0
	for t in times: total+=t
	times.sort()
	print("FIRE_PROFILE ",label," mean_ms=",total/times.size()," p95=",times[171]," draws=",draws/times.size()," trace_us_per_query=",(w.trace_usec-trace_start)/float(maxi(1,w.trace_count-count_start))," model_redraws=",w.view_redraws-redraw_start," bolts=",w.plasma.bolts.size())
	await create_timer(2.5).timeout
func run() -> void:
	create_timer(240).timeout.connect(func(): quit(1))
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.forge.store.path.contains("collision-saves"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs/projectile-loading-screen.png")
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	var e := InputEventKey.new();e.keycode=KEY_E;e.pressed=true;arena._input(e)
	arena.on_foot.test_controls=true;arena.on_foot.set_physics_process(false)
	arena.on_foot.global_position=Vector3(13,-5,222);arena.on_foot.reset_physics_interpolation()
	arena.on_foot.yaw=1.28;arena.on_foot.pitch=-.1
	arena.camera.global_position=Vector3(13,-3.46,222);arena.camera.global_rotation=Vector3(-.1,-1.86,0)
	w=arena.weapons;w.select_weapon(2);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await create_timer(5).timeout
	await sample("world_idle",false,false)
	await sample("world_firing",true,false)
	arena.on_foot.pitch=1.2
	await sample("sustained_sky_fire",true,false)
	quit()
