shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec3 color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3 color_bottom : source_color = vec3(0.62, 0.68, 0.74);
uniform float cloud_base  : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top   : hint_range(0.0, 5000.0) = 2000.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float h = clamp((world_y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	ALBEDO = mix(color_bottom, color_top, h);
	ALPHA  = 0.7;
}
