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

// rudimentary "ring in the sky" backdrop: a real ray/cylinder intersection against the ring's own
// tube (radius ring_radius, centred on the camera's actual position) so the far side reads with
// correct perspective/foreshortening for free, rather than a faked band. Mostly hidden behind the
// real 3D band mesh in normal play -- this is the backdrop for wherever that mesh doesn't cover
// (grazing angles, culling gaps, future orbital/space viewpoints).
uniform float ring_radius = 0.0;
uniform float ring_width = 50000.0;
uniform vec3 cam_world_pos = vec3(0.0);

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

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

	// stars: hashed point sparkles on a direction-space grid; fade near the horizon, dimmed by day
	vec3 grid = floor(dir * star_density);
	float h = hash13(grid);
	float star = step(0.9975, h) * hash13(grid + vec3(3.7, 1.3, 5.1));
	float horizon_fade = smoothstep(-0.05, 0.2, up);
	float star_vis = mix(1.0, star_day_visibility, day);
	col += vec3(star) * star_vis * horizon_fade;

	// sun disc + glow, moves with to_sun. Disc radius ~0.5-0.8 deg (was ~2 deg -- read as a big
	// close blob instead of a distant point of light); glow (much wider, soft) unchanged.
	float sun_dot = dot(dir, normalize(to_sun));
	float sun_disc = smoothstep(0.99990, 0.99998, sun_dot);
	float sun_glow = pow(max(sun_dot, 0.0), 300.0) * 0.6;
	col += vec3(1.0, 0.95, 0.85) * (sun_disc * 3.0 + sun_glow);

	// ring-in-the-sky: solve for where this ray hits the ring's base tube, X^2 + (Y-R)^2 = (R-h)^2,
	// h = camera's height above the local floor. For a point ON the tube, X^2+(Y-R)^2 - R^2 =
	// -2Rh+h^2 (independent of arc position -- true for any theta, not just near the camera).
	if (ring_radius > 0.0) {
		float ox = cam_world_pos.x;
		float oy = cam_world_pos.y - ring_radius;
		float a = dir.x * dir.x + dir.y * dir.y;
		float b = 2.0 * (ox * dir.x + oy * dir.y);
		float c = ox * ox + oy * oy - ring_radius * ring_radius;
		float disc = b * b - 4.0 * a * c;
		if (a > 0.00001 && disc > 0.0) {
			float t = (-b + sqrt(disc)) / (2.0 * a);   // camera is inside the tube -> this root is the hit
			if (t > 0.0) {
				float lat = cam_world_pos.z + t * dir.z;
				float half_w = ring_width * 0.5;
				float edge = 1.0 - smoothstep(half_w * 0.85, half_w, abs(lat));
				if (edge > 0.0) {
					float px = ox + t * dir.x, py = oy + t * dir.y;
					float theta = atan(px, -py);                    // arc position (0 near you, PI far side)
					float sun_theta = atan(-to_sun.x, to_sun.y);     // arc position most face-on to the sun
					float lit = clamp(cos(theta - sun_theta), 0.0, 1.0);
					// bigger, more legible blotches (was a fine salt-and-pepper grain, barely read as cloud)
					vec2 cuv = vec2(theta * 5.0, lat / half_w * 3.0);
					float n = hash21(floor(cuv * 3.0)) * 0.6 + hash21(floor(cuv * 8.0) + 5.0) * 0.4;
					vec3 cloudcol = mix(vec3(0.10, 0.26, 0.16), vec3(0.72, 0.76, 0.72), n);   // terrain green / cloud white
					float glisten = smoothstep(0.82, 1.0, n) * lit * 0.2;                     // subtle, day-side only
					// brightness-modulate the SAME pattern by lit rather than swapping to a flat dark
					// colour -- otherwise the night side of the ring shows no cloud detail at all,
					// just a featureless block (this was the "no clouds overhead" bug).
					vec3 ring_col = cloudcol * mix(0.12, 1.0, lit) + glisten;
					col = mix(col, ring_col, edge);
				}
			}
		}
	}

	COLOR = col;
}
