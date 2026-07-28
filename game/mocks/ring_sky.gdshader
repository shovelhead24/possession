shader_type sky;
// Real sky dome for ring_vibes (was a flat Environment.BG_COLOR lerp — no depth, no stars). Stars
// stay visible even in the "day" sky by deliberate stylistic choice (ref: Halo CE-style skyboxes
// that keep a rich starfield behind the ring regardless of local lighting) — not physically
// accurate (real daylight scatter would wash them out), intentional per user reference.

uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float day : hint_range(0.0, 1.0) = 1.0;   // 0 = night, 1 = day
uniform vec3 day_zenith : source_color = vec3(0.20, 0.42, 0.72);
uniform vec3 day_horizon : source_color = vec3(0.62, 0.74, 0.86);
uniform vec3 night_zenith : source_color = vec3(0.008, 0.012, 0.03);
uniform vec3 night_horizon : source_color = vec3(0.04, 0.05, 0.09);
uniform float star_density = 260.0;
uniform float star_day_visibility = 0.4;   // stars dim, not gone, during the day

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	vec3 zenith = mix(night_zenith, day_zenith, day);
	vec3 horizon = mix(night_horizon, day_horizon, day);
	vec3 col = mix(horizon, zenith, smoothstep(-0.05, 0.65, up));

	// stars: hashed point sparkles on a direction-space grid; fade near the horizon, dimmed by day
	vec3 grid = floor(dir * star_density);
	float h = hash13(grid);
	float star = step(0.9975, h) * hash13(grid + vec3(3.7, 1.3, 5.1));
	float horizon_fade = smoothstep(-0.05, 0.2, up);
	float star_vis = mix(1.0, star_day_visibility, day);
	col += vec3(star) * star_vis * horizon_fade;

	// sun disc + glow, moves with to_sun
	float sun_dot = dot(dir, normalize(to_sun));
	float sun_disc = smoothstep(0.9993, 0.9998, sun_dot);
	float sun_glow = pow(max(sun_dot, 0.0), 300.0) * 0.6;
	col += vec3(1.0, 0.95, 0.85) * (sun_disc * 3.0 + sun_glow);

	COLOR = col;
}
