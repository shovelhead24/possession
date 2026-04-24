shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec3 color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3 color_bottom : source_color = vec3(0.62, 0.68, 0.74);
uniform float alpha_max   : hint_range(0.1, 1.0) = 0.88;
uniform float alpha_edge  : hint_range(0.0, 0.5) = 0.12;
uniform float noise_scale : hint_range(0.001, 0.02) = 0.006;
uniform float cloud_base  : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top   : hint_range(0.0, 5000.0) = 2000.0;

varying float world_y;
varying vec3  world_pos;

void vertex() {
	vec4 wp  = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_pos = wp.xyz;
	world_y   = wp.y;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Trilinear value noise — smooth and cheap
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i),             hash3(i+vec3(1,0,0)), f.x),
		    mix(hash3(i+vec3(0,1,0)), hash3(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i+vec3(0,0,1)), hash3(i+vec3(1,0,1)), f.x),
		    mix(hash3(i+vec3(0,1,1)), hash3(i+vec3(1,1,1)), f.x), f.y),
		f.z);
}

void fragment() {
	// Height tint — white top, grey-blue underside
	float h = clamp((world_y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	ALBEDO = mix(color_bottom, color_top, h);

	// Normal-facing opacity: face-on surfaces are dense, edge-on are wispy
	float facing = abs(dot(NORMAL, VIEW));
	float base_alpha = mix(alpha_edge, alpha_max, pow(facing, 0.5));

	// World-space noise breaks up flat polygon faces — two octaves, stable as camera moves
	vec3 np = world_pos * noise_scale;
	float n  = vnoise(np) * 0.55 + vnoise(np * 2.2 + 1.7) * 0.25;
	n = (n - 0.4) * 0.5;  // centre around 0, range ~-0.2..0.2

	ALPHA = clamp(base_alpha + n, 0.0, 1.0);
}
