shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform sampler2D plasma_texture : source_color, filter_linear;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = dot(p,p);
	vec3 tex = texture(plasma_texture, vec2(UV.x, UV.y + sin(TIME * 17.0 + UV.x * 8.0) * 0.04)).rgb;
	float cloud = max(tex.g,tex.b);
	float halo = pow(max(0.0,1.0-r),1.7);
	float core = exp(-r * 24.0);
	ALBEDO = vec3(0.04,0.75,1.0) * (0.3 + cloud * 1.8) + vec3(1.0) * core * 3.0;
	ALPHA = halo * COLOR.a;
}
