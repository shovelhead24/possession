extends Node
## One active regional satellite image; distant regions retain the 512px array.
const Ring=preload("res://world/terrain_drive_ring.gd")
const Loader=preload("res://world/terrain_drive_satellite.gd")
var arena: Node3D
var material: ShaderMaterial
var worker: Thread
var pending=-1
var wanted=-1
var loaded=-1
var failed=-1
var texture: ImageTexture
var clock=0.0

func setup(owner_arena: Node3D):
	arena=owner_arena;material=arena.backdrop._mat
	var shader=Shader.new()
	var code: String=material.shader.code
	code=code.replace("uniform vec3 to_sun", "uniform sampler2D regional_satellite : source_color, filter_linear_mipmap_anisotropic, repeat_disable;\nuniform int regional_satellite_index = -1;\nuniform bool regional_satellite_enabled = true;\nuniform vec2 regional_satellite_focus;\nuniform vec3 to_sun")
	# Replace only the imagery lookup, before existing tint, water mask and haze.
	code=code.replace("vec3 sat = texture(patch_col_tex, vec3(puv, float(pi))).rgb * sat_gain;", "vec3 sat = texture(patch_col_tex, vec3(puv, float(pi))).rgb;\n if (regional_satellite_enabled && pi == regional_satellite_index) {\n vec2 d = UV - regional_satellite_focus;\n d.x -= ring_circumference * floor(d.x / ring_circumference + 0.5);\n float weight = 1.0 - smoothstep(4000.0, 8000.0, length(d));\n sat = mix(sat, texture(regional_satellite, puv).rgb, weight);\n }\n sat *= sat_gain;")
	shader.code=code;material.shader=shader

func _process(delta: float):
	if not arena.ready_to_play:return
	clock-=delta
	if clock<=0:
		clock=.25
		var at=Ring.coordinates(arena.camera.global_position)
		material.set_shader_parameter("regional_satellite_focus",Vector2(at.x,at.z))
		wanted=arena.backdrop._patch_at(at.x,at.z)
		material.set_shader_parameter("regional_satellite_index",loaded if wanted==loaded else -1)
	if worker and not worker.is_alive():
		var image: Image=worker.wait_to_finish();worker=null
		if image and pending==wanted:
			texture=ImageTexture.create_from_image(image);loaded=pending
			material.set_shader_parameter("regional_satellite",texture)
			material.set_shader_parameter("regional_satellite_index",loaded)
			print("REGIONAL_SATELLITE_READY ",arena.backdrop._patch_names[loaded]," width=",image.get_width()," bytes=",image.get_data().size())
		elif not image:
			failed=pending;push_warning("Regional satellite unavailable: "+str(pending))
	if not worker and wanted>=0 and wanted!=loaded and wanted!=failed:
		pending=wanted;worker=Thread.new()
		var path="res://mocks/dem/"+arena.backdrop._patch_names[pending]+"_sat.dat"
		if worker.start(Loader.load_image.bind(path))!=OK:worker=null;failed=pending

func _exit_tree():
	if worker:worker.wait_to_finish();worker=null
