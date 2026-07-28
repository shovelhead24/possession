shader_type spatial;
render_mode cull_disabled, shadows_disabled, blend_mix, depth_draw_never, unshaded;

uniform vec3  color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3  color_bottom : source_color = vec3(0.58, 0.64, 0.72);
uniform float cloud_brightness : hint_range(0.0, 1.0) = 0.5;
uniform float coverage     : hint_range(0.0, 1.0) = 0.52;
uniform float softness     : hint_range(0.05, 0.5) = 0.18;
uniform float noise_scale  : hint_range(0.00005, 0.001) = 0.00018;
uniform vec2  noise_stretch = vec2(1.0, 1.0);
uniform float cloud_base   : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top    : hint_range(0.0, 5000.0) = 2000.0;
uniform float layer_t      : hint_range(0.0, 1.0) = 0.5;
uniform vec2  wind_dir     = vec2(1.0, 0.0);
uniform float wind_speed       : hint_range(0.0, 0.05) = 0.008;
uniform float plane_half_size  : hint_range(1000.0, 50000.0) = 14000.0;
uniform vec2  sun_dir_xz   = vec2(0.0, -1.0);
uniform vec3  sun_tint     : source_color = vec3(1.0, 0.6, 0.3);
uniform float scatter      : hint_range(0.0, 1.0) = 0.0;
// added 2026-07-28 for ring_vibes' 5-layer stack. Defaults reproduce the original 3-layer
// behaviour exactly, so the older cloud_system.gd usage is unaffected.
uniform float layer_alpha    : hint_range(0.0, 1.0) = 1.0;   // per-layer transparency (stacked layers compound)
uniform float self_shadow_amt: hint_range(0.0, 1.0) = 0.72;  // lower = flatter/less dark in thick overcast
// Underside lighting. The top-lit diffuse model above is only right when you're ABOVE the layer;
// from below (the normal case, standing on the ground) a real cloud base isn't lit by direct sun at
// all -- it's lit by light TRANSMITTED through the cloud, so thin cloud glows and thick cloud goes
// flat grey. Without this the underside just showed the unlit side and read as muddy/too dark.
uniform float under_ambient  : hint_range(0.0, 1.0) = 0.55;  // sky-bounce floor on the cloud base
uniform float under_transmit : hint_range(0.0, 2.0) = 0.75;  // how much sun bleeds through thin cloud
uniform float transmit_k     : hint_range(0.5, 8.0) = 2.5;   // higher = thickness kills transmission faster

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
	_plane_offset  = VERTEX.xz;
}

void fragment() {
	// noise_stretch elongates cirrus into streaks (x=6 for top layer)
	vec2 uv = world_pos.xz * (noise_scale * noise_stretch) + wind_dir * TIME * wind_speed;
	float raw = fbm(uv);
	float threshold = 1.0 - coverage;
	float d = smoothstep(threshold - softness, threshold + softness, raw);
	d *= mix(1.0, 0.8, layer_t);

	// Horizon fade: full opacity at 45% radius, gone at plane edge
	float dist    = length(_plane_offset);
	float horizon = 1.0 - smoothstep(plane_half_size * 0.45, plane_half_size, dist);

	// Base cloud colour
	vec3 base_color = mix(color_bottom, color_top, layer_t + d * 0.15);

	// Fake surface normal from FBM density gradient (2 extra samples)
	// Gives each cloud puff a lit dome on top and shadowed sides
	float e = 0.5;
	float ndx = fbm(uv + vec2(e, 0.0)) - raw;
	float ndz = fbm(uv + vec2(0.0, e)) - raw;
	vec3 fake_normal = normalize(vec3(-ndx * 10.0, 1.0, -ndz * 10.0));

	// Sun direction with slight upward component (approximate elevation)
	vec3 sun3d = normalize(vec3(sun_dir_xz.x, 0.4, sun_dir_xz.y));
	float diffuse = max(0.0, dot(fake_normal, sun3d));

	// Self-shadow: denser cloud interior is darker (simulates depth/thickness)
	float self_shadow = 1.0 - raw * self_shadow_amt;

	// Top-lit (viewer above the layer): direct sun on the fake normal + self-shadow by thickness.
	float lighting_top = (0.20 + diffuse * 0.80) * self_shadow;
	lighting_top = smoothstep(0.0, 1.0, lighting_top);   // contrast: darks darker, lights lighter
	// Under-lit (viewer below the layer -- the usual case): transmitted light, not direct sun.
	// exp(-thickness) so thin cloud glows and dense cloud settles to a flat grey, never black.
	float transmit = exp(-raw * transmit_k);
	float lighting_bottom = under_ambient + transmit * under_transmit * max(0.0, sun3d.y);
	float viewing_top = step(world_pos.y, CAMERA_POSITION_WORLD.y);   // 1 = camera above the layer
	float lighting = mix(lighting_bottom, lighting_top, viewing_top);
	base_color *= lighting;

	// Sunset/sunrise: global warm tint on all cloud fragments + directional boost
	if (scatter > 0.01) {
		base_color = mix(base_color, sun_tint, scatter * 0.5);
		if (dist > 1.0) {
			vec2 frag_dir  = _plane_offset / dist;
			float sun_face = max(0.0, dot(frag_dir, sun_dir_xz));
			sun_face = pow(sun_face, 1.5) * scatter;
			base_color = mix(base_color, sun_tint, sun_face * 0.9);
		}
	}

	ALBEDO = base_color * cloud_brightness;
	ALPHA  = d * horizon * layer_alpha;
}
