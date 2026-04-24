shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3  color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3  color_bottom : source_color = vec3(0.62, 0.68, 0.74);
uniform float density_core : hint_range(0.5, 1.0) = 0.94;
uniform float density_edge : hint_range(0.1, 0.7) = 0.52;
uniform float cloud_base   : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top    : hint_range(0.0, 5000.0) = 2000.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	// Height tint
	float h = clamp((world_y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	ALBEDO = mix(color_bottom, color_top, h);

	// Normal-facing density: face-on = solid core, edge-on = wispy fringe
	float facing  = abs(dot(NORMAL, VIEW));
	float density = mix(density_edge, density_core, pow(facing, 0.4));

	// IGN — Interleaved Gradient Noise (Jimenez 2014)
	// Per-pixel, blue-noise-like distribution, no spatial correlation → true fine grain
	float threshold = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));

	if (density < threshold) discard;
}
