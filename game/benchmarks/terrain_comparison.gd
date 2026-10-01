extends "res://benchmarks/mesh_snapshot/world/sdf_arena_expanded.gd"
## Frozen mesh baseline and shared visual benchmark harness.
var rendering_kind := "mesh"
var bench_view := 3
var bench_seconds := 10.0
var benchmark := false
var positioned := false
var sampling := false
var warmup := 0.0
var elapsed := 0.0
var previous_usec := 0
var sample_start_usec := 0
var samples: Array[float] = []
var report_done := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--terrain-bench": benchmark=true
		if arg.begins_with("--bench-view="): bench_view=int(arg.get_slice("=",1))
		if arg.begins_with("--bench-seconds="): bench_seconds=maxf(3,float(arg.get_slice("=",1)))
	super._ready()
	# Controlled comparison: standard sun/material lighting, shadows off in BOTH.
	# Original frozen scene remains separately available with its normal shadows.
	sun.shadow_enabled=false
	if benchmark:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=0
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_title("Terrain comparison / "+rendering_kind)

func _input(event: InputEvent) -> void:
	if benchmark: return
	super._input(event)

func make_arena_content() -> Node:
	# Identical static posed content avoids AI/vehicle drift between runs.
	return preload("res://benchmarks/comparison_content.gd").new()

func _physics_process(delta: float) -> void:
	if benchmark: return
	super._physics_process(delta)

func _process(delta: float) -> void:
	super._process(delta)
	hud.text += "\nCOMPARISON: "+rendering_kind+" | shadows OFF | static models | original collision retained"
	if not benchmark or report_done: return
	if not comparison_ready(): return
	if not coarse_ready or not is_instance_valid(arena_content) or not arena_content.finished: return
	if ring_background.previews_loaded != ring_background.preview_total: return
	if not positioned:
		positioned=true;focus_site(clampi(bench_view,0,6));warmup=0
		return
	if not stream_jobs.is_empty() or ready_frames<3:
		warmup=0;sampling=false;return
	if not sampling:
		warmup+=delta
		if warmup<3.0: return
		sampling=true;previous_usec=Time.get_ticks_usec();sample_start_usec=previous_usec;samples.clear();elapsed=0
		print("BENCH_START mode=",rendering_kind," view=",bench_view)
		return
	var now := Time.get_ticks_usec()
	samples.append((now-previous_usec)/1000.0);previous_usec=now
	elapsed=(now-sample_start_usec)/1000000.0
	if elapsed>=bench_seconds:
		report_done=true;finish_benchmark.call_deferred()

func finish_benchmark() -> void:
	var ordered := samples.duplicate();ordered.sort()
	var total := 0.0
	for ms in samples: total+=ms
	var report := {"mode":rendering_kind,"view":bench_view,"frames":samples.size(),"seconds":total/1000.0,"fps":samples.size()*1000.0/total,"median_ms":ordered[int(ordered.size()/2)],"p95_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"resolution":str(get_viewport().get_visible_rect().size),"shadows":false,"content":"identical static references including Altay","collision":"unchanged mesh collision","renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"camera":str(camera.position),"rotation":str(camera.rotation),"step_limit":0}
	augment_report(report)
	var path := "user://terrain-"+rendering_kind+"-view"+str(bench_view)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path+".png")
	if rendering_kind=="raymarch":
		image.convert(Image.FORMAT_RGBA8)
		var pixels := image.get_data()
		var unresolved := 0
		for index in range(0,pixels.size(),4):
			if pixels[index]>220 and pixels[index+1]<50 and pixels[index+2]>220: unresolved+=1
		report.unresolved_diagnostic_pixels=unresolved
		report.unresolved_screen_percent=100.0*unresolved/(image.get_width()*image.get_height())
	var file := FileAccess.open(path+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TERRAIN_BENCH ",JSON.stringify(report))
	# Withdraw rendered instances before releasing the imported scene resources.
	hide()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_tree().quit()

func augment_report(_report: Dictionary) -> void:
	pass

func comparison_ready() -> bool:
	return true
