extends "res://world/sky_demo.gd"
var performance_clock := 0.0
var cloud_review: Node
var ring_landing: Node
var floating_origin: Node
var regional_satellite: Node
var painted_grass: Node3D
var showcases: Node
func ring_position_data() -> Dictionary:
	var mode="view" if cloud_review and cloud_review.viewpoints.active else ("vehicle" if vehicle_kit.driving else ("player" if on_foot.active else "camera"))
	var point: Vector3=camera.global_position
	if mode=="vehicle":point=vehicle_kit.car.global_position
	elif mode=="player":point=on_foot.global_position
	var coord=Ring.coordinates(point)
	return {"arc_m":coord.x,"lateral_m":coord.z,"height_m":coord.y,"mode":mode,"origin_offset":[Ring.origin_x,Ring.origin_y,Ring.origin_z],"elapsed_ms":Time.get_ticks_msec(),"utc":Time.get_datetime_string_from_system(true),"fps":Engine.get_frames_per_second()}
func ring_position_text() -> String:
	var data=ring_position_data()
	var text="%s | arc %.1f m | lateral %.1f m" % [data.mode,data.arc_m,data.lateral_m]
	if cloud_review and not cloud_review.viewpoints.player_start.operation.is_empty():text+=" | Click ground; Esc cancels"
	return text
func _input(event: InputEvent) -> void:
	if ready_to_play and loading.dismissed and cloud_review and cloud_review.viewpoints:
		if cloud_review.viewpoints.handle_input(event):
			get_viewport().set_input_as_handled();return
		if cloud_review.viewpoints.active:return
	super._input(event)
func _ready() -> void:
	Ring.reset_origin()
	RenderingServer.global_shader_parameter_set("ring_origin_offset",Vector3.ZERO)
	super._ready()
	loading.free();loading=Loading.new()
	loading.brief_path="res://world/performance_demo_pines_brief.json" if "--pine-trees" in OS.get_cmdline_user_args() and not "--original-trees" in OS.get_cmdline_user_args() else "res://world/performance_demo_brief.json"
	add_child(loading)
func _process(delta: float) -> void:
	super._process(delta)
	if ready_to_play and hud_refresh_due:
		hud.text=hud.text.replace("SKY DEMO /","PERFORMANCE DEMO /")
		var lines=hud.text.split("\n")
		if lines.size()>1:lines[1]=lines[1].replace(" FPS |", " FPS | "+ring_position_text()+"\n")
		hud.text="\n".join(lines)
	performance_clock-=delta
	if ready_to_play and performance_clock<=0:
		performance_clock=.5
		for rex in get_tree().get_nodes_in_group("tyrants"):
			if rex.has_meta("damage_regions"): continue
			var regions=preload("res://world/performance_rex_regions.gd").new();rex.add_child(regions);regions.setup(rex)
			rex.screen_size_animation=true
func performance_features() -> bool: return true
func prepare_content() -> void:
	await super.prepare_content()
	weapons.select_weapon(4) # Halo CE Plasma Rifle, the blue/silver second rifle.
	# Only the original 3.2 km local terrain square gets the grass study.
	material.shader=preload("res://world/performance_grass.gdshader")
	for item in [["grass","grass.png"],["grass_height","grass-height.png"],["biome_mask","biome-mask.png"]]:
		var image=Image.load_from_file("res://assets/terrain/grass-study/"+item[1])
		image.generate_mipmaps()
		material.set_shader_parameter(item[0],ImageTexture.create_from_image(image))
	var rock_image=Image.load_from_file("res://world/materials/nature/rock_boulder_dry_diffuse.jpg")
	rock_image.generate_mipmaps()
	material.set_shader_parameter("rock",ImageTexture.create_from_image(rock_image))
	daylight.balanced_shadow_map_size=2048 if "--high-resolution-shadows" in OS.get_cmdline_user_args() else 1024
	daylight.apply()
	hud_refresh_interval=.1
	hud_skip_when_hidden=true
	jitter_trace.passive_sample_interval=.1
	jitter_trace.status="F8: capture diagnostics (10 Hz pre-roll, full-rate recording)"
	cloud_review=preload("res://world/performance_cloud_review.gd").new();add_child(cloud_review);cloud_review.setup(self)
	regional_satellite=preload("res://world/performance_satellite.gd").new();add_child(regional_satellite);regional_satellite.setup(self)
	ring_landing=preload("res://world/performance_ring_landing.gd").new();add_child(ring_landing);ring_landing.setup(self)
	floating_origin=preload("res://world/performance_floating_origin.gd").new();add_child(floating_origin);floating_origin.setup(self)
	floating_origin.enabled=not "--no-floating-origin" in OS.get_cmdline_user_args()
	showcases=preload("res://world/performance_showcases.gd").new();add_child(showcases);showcases.setup(self)
	painted_grass=preload("res://world/grass_paint.gd").new();add_child(painted_grass);painted_grass.setup(self)
	editor.add_grass_tools()
