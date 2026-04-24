shader_type spatial;
render_mode cull_disabled;

uniform vec3 color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3 color_bottom : source_color = vec3(0.62, 0.68, 0.74);
uniform float alpha_density : hint_range(0.1, 1.0) = 0.82;
uniform float cloud_base  : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top   : hint_range(0.0, 5000.0) = 2000.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	// Height-based tint — bright white on top, grey-blue on underside
	float h = clamp((world_y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	ALBEDO = mix(color_bottom, color_top, h);

	// Alpha hash — screen-space dithering, no depth-sort needed
	const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
	float threshold = fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)));
	if (alpha_density < threshold) discard;
}
