shader_type sky;
// Real sky dome for ring_vibes (was a flat Environment.BG_COLOR lerp — no depth, no stars). Stars
// stay visible even in the "day" sky by deliberate stylistic choice (ref: Halo CE-style skyboxes
// that keep a rich starfield behind the ring regardless of local lighting) — not physically
// accurate (real daylight scatter would wash them out), intentional per user reference.
//
// 2026-07-28: the ray/cylinder "ring in the sky" backdrop that used to live here was removed —
// confirmed effectively invisible in practice (the real 3D CDLOD+band geometry occludes it
// everywhere except a thin seam). The "sense of the far ring" job moves to a real cloud-card
// layer (see mocks/ring_clouds.gd) instead of a stylized sky-dome hack.

uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float day : hint_range(0.0, 1.0) = 1.0;   // 0 = night, 1 = day
uniform vec3 day_zenith : source_color = vec3(0.20, 0.42, 0.72);
uniform vec3 day_horizon : source_color = vec3(0.62, 0.74, 0.86);
uniform vec3 night_zenith : source_color = vec3(0.02, 0.03, 0.06);
uniform vec3 night_horizon : source_color = vec3(0.07, 0.09, 0.15);
uniform float star_density = 260.0;
uniform float star_day_visibility = 0.4;   // stars dim, not gone, during the day
// The stars have to wheel with the sun. Day/night here is the RING TURNING, and the sun and the
// stars are both fixed in the same external frame -- so they share one apparent motion. A fixed
// starfield under a moving sun says the sky is painted on, which was the tell.
uniform float star_rot = 0.0;              // = sun_angle, radians
// ...about the SUN'S OWN axis, not the ring axis. to_sun(a) = cos(a)*v + sin(a)*u with u=(1,0,0)
// and v=(0,cos t,sin t), so the sun sweeps the plane those span and its rotation axis is
// u x v = (0,-sin t, cos t) -- Z tilted by the sun tilt. Rotating the stars about plain Z instead
// leaves them drifting away from the sun by the tilt angle over a day.
uniform vec3 star_axis = vec3(0.0, 0.0, 1.0);

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	vec3 zenith = mix(night_zenith, day_zenith, day);
	vec3 horizon = mix(night_horizon, day_horizon, day);
	vec3 col = mix(horizon, zenith, smoothstep(-0.05, 0.65, up));

	// stars: hashed point sparkles on an azimuth/elevation grid (NOT floor(dir*density) -- that
	// cartesian grid goes dead wherever two axes compress toward zero, e.g. looking straight up,
	// which is exactly the "no stars all the way around" gap found by flying up) -- fade near the
	// horizon, dimmed by day.
	// Rotate the SAMPLING direction by +star_rot about Z, which makes a star appear to travel at
	// -star_rot -- matching the sun, whose azimuth atan2(x, y) = atan2(sin a, cos a * cos tilt)
	// runs at +a. Derived rather than eyeballed: getting this backwards would look almost right,
	// with the stars sliding the wrong way at exactly the correct rate.
	float sr_c = cos(star_rot);
	float sr_s = sin(star_rot);
	vec3 sdir = dir * sr_c + cross(star_axis, dir) * sr_s
		+ star_axis * dot(star_axis, dir) * (1.0 - sr_c);   // Rodrigues about the sun's axis
	vec2 sph = vec2(atan(sdir.x, sdir.z), asin(clamp(sdir.y, -1.0, 1.0))) * star_density;
	vec2 sgrid = floor(sph);
	float h = hash21(sgrid);
	float star = step(0.9975, h) * hash21(sgrid + vec2(3.7, 1.3));
	float horizon_fade = smoothstep(-0.05, 0.2, up);
	float star_vis = mix(1.0, star_day_visibility, day);
	col += vec3(star) * star_vis * horizon_fade;

	// sun disc + glow, moves with to_sun. Disc radius ~0.5-0.8 deg (was ~2 deg -- read as a big
	// close blob instead of a distant point of light); glow (much wider, soft) unchanged.
	float sun_dot = dot(dir, normalize(to_sun));
	float sun_disc = smoothstep(0.99990, 0.99998, sun_dot);
	float sun_glow = pow(max(sun_dot, 0.0), 300.0) * 0.6;
	col += vec3(1.0, 0.95, 0.85) * (sun_disc * 3.0 + sun_glow);

	COLOR = col;
}
