extends "res://benchmarks/terrain_comparison.gd"
## Visual-only experiment; collision meshing is deliberately held constant.
var proxy := MeshInstance3D.new()
var ray_material: ShaderMaterial
var step_limit := 4096
var step_divisor := 8.0
var diagnostic := true
var field_probe_done := false
var field_probe_error := 0.0

func _ready() -> void:
	rendering_kind="raymarch"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ray-steps="): step_limit=clampi(int(arg.get_slice("=",1)),32,4096)
		if arg.begins_with("--ray-divisor="): step_divisor=maxf(1,float(arg.get_slice("=",1)))
		if arg=="--ray-hide-failures": diagnostic=false
	super._ready()
	var shader := Shader.new()
	var source := FileAccess.get_file_as_string("res://benchmarks/mesh_snapshot/world/materials/expanse.gdshader")
	source=source.replace("render_mode diffuse_burley, specular_schlick_ggx;","render_mode diffuse_burley, specular_schlick_ggx, cull_front;")
	var functions := FileAccess.get_file_as_string("res://benchmarks/raymarch_field.gdshaderinc")
	source=source.replace("void fragment() {",functions+"\nvoid fragment() {")
	source=source.replace("vec3 p = world_position;",FileAccess.get_file_as_string("res://benchmarks/raymarch_trace.gdshaderinc"))
	source=source.replace("vec3 n = normalize(world_normal);","vec3 n = hit_normal;\n NORMAL = normalize((VIEW_MATRIX * vec4(n,0.0)).xyz);")
	var last_brace := source.rfind("}")
	source=source.insert(last_brace,"\n if (!found) { ALBEDO=vec3(1,0,1); EMISSION=vec3(1,0,1); }\n")
	shader.code=source
	ray_material=terrain.material_override.duplicate();ray_material.shader=shader
	ray_material.set_shader_parameter("detail_surface",false)
	ray_material.set_shader_parameter("max_steps",step_limit)
	ray_material.set_shader_parameter("step_divisor",step_divisor)
	ray_material.set_shader_parameter("show_failures",diagnostic)
	var box_mesh := BoxMesh.new();box_mesh.size=Vector3(1536,96,1536)
	proxy.mesh=box_mesh;proxy.position=Vector3(0,24,0);proxy.material_override=ray_material
	proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(proxy)
	if benchmark: check_field_port.call_deferred()

func check_field_port() -> void:
	# GPU readback checks the port against the frozen CPU recipe at landmarks.
	var points := PackedVector3Array()
	for center in [Vector3(-154,8,-80),Vector3(-186,-5,-80),Vector3(-122,-5,-80),Vector3(-363,8,145),Vector3(-245,8,145),Vector3(-127,8,145),Vector3(145,8,-250),Vector3(145,8,-140),Vector3(145,8,-30),Vector3(-30,2,180),Vector3(65,5,-195),Vector3(-10,2,14),Vector3(25,1,8),Vector3(-39,1.5,33),Vector3(450,46,430),Vector3(-500,50,-430)]:
		for offset in [Vector3.ZERO,Vector3(3,7,2),Vector3(-7,-3,-4),Vector3(11,15,8)]: points.append(center+offset)
	var viewport := SubViewport.new();viewport.size=Vector2i(64,1);viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var rect := ColorRect.new();rect.size=Vector2(64,1);viewport.add_child(rect)
	var shader := Shader.new()
	shader.code="shader_type canvas_item;\nuniform vec3 probes[64];\n"+FileAccess.get_file_as_string("res://benchmarks/raymarch_field.gdshaderinc")+"\nvoid fragment(){float f=arena_field(probes[clamp(int(FRAGCOORD.x),0,63)]);float code=floor(clamp((f+256.0)/512.0,0.0,1.0)*65535.0+0.5);COLOR=vec4(floor(code/256.0)/255.0,mod(code,256.0)/255.0,0.0,1.0);}\n"
	var material := ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("probes",points)
	material.set_shader_parameter("tunnel_radius",tunnel_radius);material.set_shader_parameter("terrain_detail",roughness)
	rect.material=material
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	for index in points.size():
		var color := pixels.get_pixel(index,0)
		var actual := (roundf(color.r*255)*256+roundf(color.g*255))/65535.0*512.0-256.0
		var expected := expanded_field(points[index],tunnel_radius,roughness)
		field_probe_error=maxf(field_probe_error,absf(actual-expected))
	viewport.queue_free()
	print("FIELD_PORT_CHECK probes=64 max_error=",field_probe_error)
	if field_probe_error>.03:
		push_error("CPU/GPU terrain field port differs; refusing benchmark")
		get_tree().quit(2);return
	field_probe_done=true

func _process(delta: float) -> void:
	super._process(delta)
	if ray_material==null: return
	ray_material.set_shader_parameter("tunnel_radius",tunnel_radius)
	ray_material.set_shader_parameter("terrain_detail",roughness)
	ray_material.set_shader_parameter("textured",textured)
	coarse.hide();coarse_mid.hide();terrain.hide()
	for child in get_children():
		# Chunk container visibility hides visuals, not its physics bodies.
		if child is Node3D and child.name.begins_with("Chunk"): child.hide()
	for entries in [chunks,retiring,spares]:
		for key in entries:
			for mesh in entries[key].node.find_children("*","MeshInstance3D",true,false): mesh.hide()
	hud.text+="\nRAY: %d steps | divisor %.1f (experimental, NOT certified bound) | magenta = unresolved" % [step_limit,step_divisor]

func augment_report(report: Dictionary) -> void:
	report.step_limit=step_limit;report.step_divisor=step_divisor;report.failure_diagnostic=diagnostic
	report.distance_bound_certified=false
	report.field_port_probes=64;report.field_port_max_error=field_probe_error

func comparison_ready() -> bool:
	return field_probe_done
