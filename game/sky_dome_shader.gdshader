// Sky dome shader — shader_type spatial so it works in GL Compatibility renderer.
// Rendered on the inside of a large sphere that follows the camera.
// day_night_cycle.gd creates the dome mesh and updates the uniforms each frame.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec3 day_sky_top    : source_color = vec3(0.3,  0.5,  0.9);
uniform vec3 day_sky_horizon: source_color = vec3(0.6,  0.75, 0.9);
uniform vec3 night_sky_top  : source_color = vec3(0.005,0.005,0.015);
uniform vec3 night_sky_horiz: source_color = vec3(0.01, 0.01, 0.03);
uniform vec3 sunset_color   : source_color = vec3(1.0,  0.4,  0.2);

uniform float sun_elevation : hint_range(-90.0, 90.0) = 45.0;
uniform float sun_azimuth   : hint_range(0.0, 360.0)  = 180.0;
uniform float sun_size      : hint_range(0.0, 0.1)    = 0.025;
uniform vec3  sun_color     : source_color = vec3(1.0, 0.95, 0.8);

uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

uniform float ring_visual_width : hint_range(0.001, 0.1) = 0.006;
uniform float ring_azimuth_offset : hint_range(0.0, 360.0) = 0.0;
uniform vec3  ring_near_color : source_color = vec3(0.30, 0.45, 0.25);
uniform vec3  ring_far_color  : source_color = vec3(0.50, 0.58, 0.68);

// Pass local sphere vertex position as the sky ray direction.
// SphereMesh vertices are centred at origin, so VERTEX normalised = outward direction.
// cull_front renders the inner surface; the local position still points "outward"
// from the sphere centre, which is exactly the sky ray we want.
varying vec3 sky_dir;

void vertex() {
	sky_dir = VERTEX;
}

// --- helpers ---

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float star_field(vec3 dir) {
	vec2 uv   = vec2(atan(dir.x, dir.z), asin(clamp(dir.y, -1.0, 1.0))) * 80.0;
	vec2 grid = floor(uv);
	vec2 f    = fract(uv);
	float s   = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 nb   = vec2(float(x), float(y));
			vec2 cell = grid + nb;
			vec2 pos  = vec2(hash(cell), hash(cell + vec2(1.0, 0.0)));
			float d   = length(f - nb - pos);
			float b   = hash(cell + vec2(0.0, 1.0));
			if (b > 0.85) {
				float tw = sin(TIME * (2.0 + hash(cell) * 3.0)) * 0.3 + 0.7;
				s += smoothstep(0.04, 0.0, d) * b * tw * 0.5;
			}
		}
	}
	return s * star_brightness;
}

// --- main ---

void fragment() {
	vec3 dir = normalize(sky_dir);

	float day    = smoothstep(-10.0, 20.0, sun_elevation);
	float sunset = smoothstep(-10.0, 5.0, sun_elevation) * smoothstep(25.0, 5.0, sun_elevation);

	// Sky gradient — dir.y: +1 = zenith, 0 = horizon, -1 = nadir
	vec3 top   = mix(night_sky_top,   day_sky_top,    day);
	vec3 horiz = mix(night_sky_horiz, day_sky_horizon, day);
	horiz      = mix(horiz, sunset_color, sunset * 0.7);
	float hf   = pow(max(1.0 - abs(dir.y), 0.0), 0.8);
	vec3 sky   = mix(top, horiz, hf);

	// Sun disc + glow
	float er = radians(sun_elevation);
	float ar = radians(sun_azimuth);
	vec3 sun_dir = vec3(cos(er) * sin(ar), sin(er), cos(er) * cos(ar));
	float sd     = distance(dir, sun_dir);
	float sv     = smoothstep(-5.0, 5.0, sun_elevation);
	float disc   = smoothstep(sun_size, sun_size * 0.5, sd);
	float glow   = smoothstep(sun_size * 8.0, sun_size, sd) * 0.3;
	sky += sun_color * (disc + glow) * sv;

	// Stars — visible at night, faintly visible during day
	float star_vis = clamp(1.0 - day * 0.85, 0.1, 1.0);
	if (dir.y > -0.1 && star_vis > 0.01) {
		sky += vec3(star_field(dir)) * star_vis * 1.2;
	}

	// Halo ring horizon — a great circle passing through zenith.
	// Perspective: width scales as 1/sin(elevation), capped at 50x.
	float ring_rad   = radians(ring_azimuth_offset);
	vec3 rot_dir = vec3(
		dir.x * cos(ring_rad) - dir.z * sin(ring_rad),
		dir.y,
		dir.x * sin(ring_rad) + dir.z * cos(ring_rad));
	float ring_dist  = abs(rot_dir.z);
	float elev       = asin(clamp(rot_dir.y, -1.0, 1.0));
	float sin_e      = max(sin(abs(elev)), 0.02);
	float eff_width  = ring_visual_width / sin_e;
	float ring_band  = smoothstep(eff_width, eff_width * 0.05, ring_dist);
	float ring_fade  = smoothstep(-0.02, 0.15, elev);
	float ring_alpha = min(ring_band * ring_fade * 2.5, 1.0);
	float t          = clamp(elev * 3.0, 0.0, 1.0);
	vec3 ring_col    = mix(ring_near_color, ring_far_color, t);
	// Night illumination from the ring itself
	float night_glow = (1.0 - day) * 0.5;
	ring_col        += vec3(0.12, 0.14, 0.20) * night_glow;
	sky              = mix(sky, ring_col, ring_alpha);

	ALBEDO = sky;
}
