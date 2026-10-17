extends SceneTree
func _initialize(): run.call_deferred()
func bake(code: String,path: String) -> void:
	var viewport=SubViewport.new();viewport.size=Vector2i(2048,2048);viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var rect=ColorRect.new();rect.size=Vector2(2048,2048)
	var shader=Shader.new();shader.code=code
	var material=ShaderMaterial.new();material.shader=shader;rect.material=material;viewport.add_child(rect)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image=viewport.get_texture().get_image()
	assert(image.save_png(path)==OK)
	viewport.free()
func run():
	DirAccess.make_dir_recursive_absolute("res://world/cloud_cache")
	var source=FileAccess.get_file_as_string("res://benchmarks/sky_before/sky_billboard.gdshader")
	var functions=source.substr(source.find("float hash("),source.find("void vertex()")-source.find("float hash("))
	var fragment=source.substr(source.find("void fragment()"))
	fragment=fragment.replace("vec2 p=(UV-0.5)","vec2 p=(cell_uv-0.5)").replace("UV-0.5","cell_uv-0.5").replace("1.0-UV.y","1.0-cell_uv.y")
	fragment=fragment.replace("vec2(TIME*0.001,0)","vec2(0)")
	fragment=fragment.replace("UV.x","cell_uv.x").replace("UV.y","cell_uv.y")
	fragment=fragment.replace("ALBEDO=vec3(0.94,0.96,1.0)*light*cloud_brightness;ALPHA=density*edge*0.9*range_alpha;","COLOR=vec4(vec3(light),density*edge*0.9);")
	fragment=fragment.replace("void fragment(){","void fragment(){\n vec2 tile=floor(UV*8.0); vec2 cell_uv=fract(UV*8.0); float cloud_seed=(tile.x+tile.y*8.0)*7.813+0.37;")
	await bake("shader_type canvas_item;\nrender_mode blend_disabled;\n"+functions+fragment,"res://world/cloud_cache/billboards-v1.png")
	var old=FileAccess.get_file_as_string("res://world/sky_painterly.gdshader")
	var noise=old.substr(old.find("float hash3"),old.find("void sky()")-old.find("float hash3"))
	var upper="""
float mass_at(vec2 uv){vec3 p=vec3(uv,2.73);vec3 warp=vec3(noise3(p+17.1),noise3(p+43.8),noise3(p+91.3))-0.5;return fbm(p+warp*1.3);}
void fragment(){
 vec2 p=UV*16.0;vec2 w=UV*UV*(3.0-2.0*UV);
 float mass=mix(mix(mass_at(p),mass_at(p-vec2(16,0)),w.x),mix(mass_at(p-vec2(0,16)),mass_at(p-vec2(16)),w.x),w.y);
 vec3 tint=mix(vec3(0.45,0.46,0.56),vec3(0.86,0.82,0.81),smoothstep(0.33,0.72,mass));
 COLOR=vec4(tint,smoothstep(0.34,0.67,mass)*0.85);
}
"""
	await bake("shader_type canvas_item;\nrender_mode blend_disabled;\n"+noise+upper,"res://world/cloud_cache/painterly-v1.png")
	print("PASS baked 64 billboard shapes and seamless painterly density/colour; 2048px each")
	quit()
