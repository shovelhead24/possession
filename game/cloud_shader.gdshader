shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3 color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3 color_bottom : source_color = vec3(0.62, 0.68, 0.74);
uniform float density_top  : hint_range(0.3, 1.0) = 0.92;
uniform float density_edge : hint_range(0.0, 0.6) = 0.35;
uniform float cloud_base   : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top    : hint_range(0.0, 5000.0) = 2000.0;

varying float world_y;
varying vec3  world_pos;

void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_pos = wp.xyz;
	world_y   = wp.y;
}

void fragment() {
	float h = clamp((world_y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	ALBEDO = mix(color_bottom, color_top, h);

	// Normal-facing: face-on = dense cloud core, edge-on = wispy edge
	float facing  = abs(dot(NORMAL, VIEW));
	float density = mix(density_edge, density_top, pow(facing, 0.5));

	// Blue-noise-style hash — much less regular than simple screen-space hash
	vec3 fp = fract(world_pos * 0.005 + FRAGCOORD.xyz * 0.003);
	fp += dot(fp, fp.zyx + 31.32);
	float threshold = fract((fp.x + fp.y) * fp.z);

	if (density < threshold) discard;
}
