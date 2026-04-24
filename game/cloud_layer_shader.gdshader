shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3  color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3  color_bottom : source_color = vec3(0.58, 0.64, 0.72);
uniform float coverage     : hint_range(0.0, 1.0) = 0.52;
uniform float softness     : hint_range(0.05, 0.4) = 0.18;
uniform float noise_scale  : hint_range(0.00005, 0.001) = 0.00018;
uniform float cloud_base   : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top    : hint_range(0.0, 5000.0) = 2000.0;
uniform float layer_t      : hint_range(0.0, 1.0) = 0.5;  // 0=bottom layer, 1=top layer

varying vec3 world_pos;

float hash2(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
	           mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	vec2  s = vec2(1.7, 9.2);
	for (int i = 0; i < 6; i++) {
		v += a * vnoise2(p);
		p  = p * 2.07 + s;
		a *= 0.5;
		s  = s.yx * 1.3;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// FBM density at this world XZ position
	float d = fbm(world_pos.xz * noise_scale);

	// Map to 0..1 cloud presence — smoothstep gives soft edges
	float threshold = 1.0 - coverage;
	d = smoothstep(threshold - softness, threshold + softness, d);

	// Top layers slightly sparser (cloud tops are wispier)
	d *= mix(1.0, 0.8, layer_t);

	// Height tint: darker underside, bright luminous top
	ALBEDO = mix(color_bottom, color_top, layer_t + d * 0.15);

	// IGN — fine per-pixel grain against the smooth FBM field
	float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (d < ign) discard;
}
