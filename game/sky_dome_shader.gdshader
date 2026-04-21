// Sky dome shader — shader_type spatial so it works in GL Compatibility renderer.
// Rendered on the inside of a large sphere that follows the camera.
// Samples a single equirectangular panorama — no cubemap face seams.
// day_night_cycle.gd creates the dome mesh and updates the uniforms each frame.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform sampler2D panorama : filter_linear, repeat_enable;

// Day/night
uniform float sun_elevation : hint_range(-90.0, 90.0) = 45.0;
uniform float sun_azimuth   : hint_range(0.0, 360.0)  = 180.0;
uniform float sun_size      : hint_range(0.0, 0.1)    = 0.025;
uniform vec3  sun_color     : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3  sunset_color  : source_color = vec3(1.0, 0.4,  0.15);
uniform vec3  night_tint    : source_color = vec3(0.04, 0.06, 0.12);
uniform float night_darkness : hint_range(0.0, 1.0) = 0.92;

uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

varying vec3 sky_dir;

void vertex() {
	sky_dir = VERTEX;
}

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

void fragment() {
	vec3 dir = normalize(sky_dir);

	// Equirectangular UV
	float u = atan(dir.x, -dir.z) / (2.0 * PI) + 0.5;
	float v = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;
	vec3 sky = texture(panorama, vec2(u, v)).rgb;

	// Day/night: darken skybox at night, tint toward deep blue
	float day    = smoothstep(-10.0, 20.0, sun_elevation);
	float sunset = smoothstep(-10.0, 5.0, sun_elevation) * smoothstep(25.0, 5.0, sun_elevation);

	// Night darkening
	sky = mix(night_tint, sky, mix(night_darkness, 1.0, day));

	// Sunset warmth at the horizon
	float hf = pow(max(1.0 - abs(dir.y), 0.0), 2.5);
	sky = mix(sky, sky * sunset_color * 1.4, sunset * hf * 0.6);

	// Sun disc + glow
	float er     = radians(sun_elevation);
	float ar     = radians(sun_azimuth);
	vec3 sun_dir = vec3(cos(er) * sin(ar), sin(er), cos(er) * cos(ar));
	float sd     = distance(dir, sun_dir);
	float sv     = smoothstep(-5.0, 5.0, sun_elevation);
	float disc   = smoothstep(sun_size, sun_size * 0.5, sd);
	float glow   = smoothstep(sun_size * 8.0, sun_size, sd) * 0.3;
	sky += sun_color * (disc + glow) * sv;

	// Extra stars at night
	float star_vis = clamp(1.0 - day * 0.85, 0.1, 1.0);
	if (dir.y > -0.1 && star_vis > 0.01) {
		sky += vec3(star_field(dir)) * star_vis * 2.0;
	}

	ALBEDO = sky;
}
