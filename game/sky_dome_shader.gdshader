// Sky dome shader — direct cubemap face sampling, no panorama bake needed.
// Per-face rotation (0-3 = 0/90/180/270 CCW) and flip (0/1) let you tune
// orientation in-game: [ ] selects face, Shift+R rotates, Shift+H flips.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform sampler2D face_ft : filter_linear, repeat_disable;  // front  -Z
uniform sampler2D face_bk : filter_linear, repeat_disable;  // back   +Z
uniform sampler2D face_lf : filter_linear, repeat_disable;  // left   -X
uniform sampler2D face_rt : filter_linear, repeat_disable;  // right  +X
uniform sampler2D face_up : filter_linear, repeat_disable;  // up     +Y
uniform sampler2D face_dn : filter_linear, repeat_disable;  // down   -Y

// Per-face rotation: 0=0° 1=90°CCW 2=180° 3=270°CCW
uniform int rot_ft : hint_range(0, 3) = 0;
uniform int rot_bk : hint_range(0, 3) = 0;
uniform int rot_lf : hint_range(0, 3) = 0;
uniform int rot_rt : hint_range(0, 3) = 0;
uniform int rot_up : hint_range(0, 3) = 0;
uniform int rot_dn : hint_range(0, 3) = 0;

// Per-face horizontal flip: 0=none 1=flip
uniform int flip_ft : hint_range(0, 1) = 0;
uniform int flip_bk : hint_range(0, 1) = 0;
uniform int flip_lf : hint_range(0, 1) = 0;
uniform int flip_rt : hint_range(0, 1) = 0;
uniform int flip_up : hint_range(0, 1) = 0;
uniform int flip_dn : hint_range(0, 1) = 0;

// Day/night
uniform float sun_elevation : hint_range(-90.0, 90.0) = 45.0;
uniform float sun_azimuth   : hint_range(0.0, 360.0)  = 180.0;
uniform float sun_size      : hint_range(0.0, 0.1)    = 0.025;
uniform vec3  sun_color     : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3  sunset_color  : source_color = vec3(1.0, 0.4,  0.15);
uniform vec3  night_tint    : source_color = vec3(0.04, 0.06, 0.12);
uniform float night_darkness : hint_range(0.0, 1.0) = 0.92;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

void vertex() {}

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

vec2 xform(vec2 uv, int rot, int flip) {
	uv -= 0.5;
	if (rot == 1)      uv = vec2(-uv.y,  uv.x);
	else if (rot == 2) uv = vec2(-uv.x, -uv.y);
	else if (rot == 3) uv = vec2( uv.y, -uv.x);
	uv += 0.5;
	if (flip == 1) uv.x = 1.0 - uv.x;
	return uv;
}

void fragment() {
	// Per-pixel world-space ray (GL Compat, no Y flip needed)
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec3 view_dir = normalize(vec3(
		ndc.x / PROJECTION_MATRIX[0][0],
		ndc.y / PROJECTION_MATRIX[1][1],
		-1.0
	));
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(view_dir, 0.0)).xyz);

	float ax = abs(dir.x), ay = abs(dir.y), az = abs(dir.z);
	vec3 sky;

	if (ax >= ay && ax >= az) {
		if (dir.x > 0.0) {
			sky = texture(face_rt, xform(vec2(-dir.z / ax, -dir.y / ax) * 0.5 + 0.5, rot_rt, flip_rt)).rgb;
		} else {
			sky = texture(face_lf, xform(vec2( dir.z / ax, -dir.y / ax) * 0.5 + 0.5, rot_lf, flip_lf)).rgb;
		}
	} else if (ay >= az) {
		if (dir.y > 0.0) {
			sky = texture(face_up, xform(vec2( dir.x / ay,  dir.z / ay) * 0.5 + 0.5, rot_up, flip_up)).rgb;
		} else {
			sky = texture(face_dn, xform(vec2( dir.x / ay, -dir.z / ay) * 0.5 + 0.5, rot_dn, flip_dn)).rgb;
		}
	} else {
		if (dir.z < 0.0) {
			sky = texture(face_ft, xform(vec2( dir.x / az, -dir.y / az) * 0.5 + 0.5, rot_ft, flip_ft)).rgb;
		} else {
			sky = texture(face_bk, xform(vec2(-dir.x / az, -dir.y / az) * 0.5 + 0.5, rot_bk, flip_bk)).rgb;
		}
	}

	// Day/night darkening
	float day    = smoothstep(-10.0, 20.0, sun_elevation);
	float sunset = smoothstep(-10.0, 5.0, sun_elevation) * smoothstep(25.0, 5.0, sun_elevation);
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

	// Stars at night
	float star_vis = clamp(1.0 - day * 0.85, 0.1, 1.0);
	if (dir.y > -0.1 && star_vis > 0.01) {
		sky += vec3(star_field(dir)) * star_vis * 2.0;
	}

	ALBEDO = sky;
}
