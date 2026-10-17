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
	for i in 30: await process_frame
	var times := [];var last := Time.get_ticks_usec();var draws := 0.0
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	w.trigger_held=false
	var total := 0.0
	for t in times: total+=t
	times.sort()
	print("FIRE_PROFILE ",label," mean_ms=",total/times.size()," p95=",times[171]," draws=",draws/times.size())
	await create_timer(2.5).timeout
func run() -> void:
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var arena := Arena.new();root.add_child(arena)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.make_current()
	w=preload("res://world/rebuild_weapons.gd").new();arena.add_child(w);await w.setup(arena)
	w.select_weapon(2);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await create_timer(.5).timeout
	await sample("idle",false,false)
	await sample("firing",true,false)
	await sample("firing_no_model",true,true)
	quit()
