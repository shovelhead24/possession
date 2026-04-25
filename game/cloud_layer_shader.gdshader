shader_type spatial;
render_mode cull_disabled, shadows_disabled, blend_mix, depth_draw_never, unshaded;

uniform vec3  color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3  color_bottom : source_color = vec3(0.58, 0.64, 0.72);
uniform float cloud_brightness : hint_range(0.0, 1.0) = 0.5;
uniform float coverage     : hint_range(0.0, 1.0) = 0.52;
uniform float softness     : hint_range(0.05, 0.4) = 0.18;
uniform float noise_scale  : hint_range(0.00005, 0.001) = 0.00018;
uniform float cloud_base   : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top    : hint_range(0.0, 5000.0) = 2000.0;
uniform float layer_t      : hint_range(0.0, 1.0) = 0.5;
uniform vec2  wind_dir     = vec2(1.0, 0.0);
uniform float wind_speed       : hint_range(0.0, 0.05) = 0.008;
uniform float plane_half_size  : hint_range(1000.0, 50000.0) = 16000.0;

varying vec3 world_pos;
varying vec2 _plane_offset;

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
	world_pos      = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	_plane_offset  = VERTEX.xz;  // local XZ = metres from camera (plane tracks camera)
}

void fragment() {
	float d = fbm(world_pos.xz * noise_scale + wind_dir * TIME * wind_speed);
	float threshold = 1.0 - coverage;
	d = smoothstep(threshold - softness, threshold + softness, d);
	d *= mix(1.0, 0.8, layer_t);

	// Horizon fade: full opacity within 55% radius, gone at plane edge
	float dist        = length(_plane_offset);
	float horizon     = 1.0 - smoothstep(plane_half_size * 0.45, plane_half_size, dist);

	ALBEDO = mix(color_bottom, color_top, layer_t + d * 0.15) * cloud_brightness;
	ALPHA  = d * horizon;
}
