shader_type spatial;
render_mode unshaded, cull_disabled;
// CDLOD terrain for the ring_vibes scene: same quadtree-morph vertex logic as cdlod.gdshader (see
// that file's header — this is the "found viable in cdlod.tscn, ported here" case), but UNSHADED +
// manual sun/haze lighting to match ring_vibes.gdshader / ring_vibes_wall.gdshader's established
// look (consistent day/night + haze across band+walls+terrain). Trade-off: unshaded materials can't
// receive Godot's shadow map, so unlike the standalone cdlod mock the car casts no shadow on the
// ground here — accepted for visual consistency with the already-validated ring look.

uniform sampler2D heightmap : repeat_enable;
uniform sampler2D dem_tex;
uniform vec2 dem_cam = vec2(0.0);
uniform float dem_mpp = 47.0;
uniform vec2 dem_size = vec2(1.0);
uniform bool use_dem = false;
uniform float dem_scale = 1.0;
uniform sampler2D sat_tex : source_color, filter_linear;
uniform bool has_sat = false;
uniform sampler2D road_tex : filter_linear;
uniform bool has_roads = false;
uniform float sat_gain = 1.35;
uniform float terrain_size = 4096.0;
uniform float feature = 3500.0;
uniform float disp = 300.0;
uniform float ring_radius = 0.0;
uniform float ring_width = 1.0e9;
uniform vec2 node_origin = vec2(0.0);
uniform float node_size = 128.0;
uniform float morph_start = 0.0;
uniform float morph_end = 1.0;
uniform vec3 cam_pos = vec3(0.0);
uniform float grid = 16.0;
uniform float lod_tint = 0.0;
uniform bool show_lod = false;
uniform bool morph_horizontal = true;
uniform float skirt = 0.15;
// ring look: same manual sun/haze system as ring_vibes.gdshader / ring_vibes_wall.gdshader
uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float haze_density = 0.000012;
uniform vec3 sky_color = vec3(0.45, 0.62, 0.82);

varying float v_h;
varying vec3 v_n;
varying vec2 v_demuv;
varying vec3 v_world_pos;

bool in_dem_bounds(vec2 uv) {
	return uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0;
}

float sample_h(vec2 wxz) {
	if (use_dem) {
		vec2 uv = vec2(dem_cam.x + wxz.x / dem_mpp, dem_cam.y - wxz.y / dem_mpp) / dem_size;
		if (in_dem_bounds(uv)) {
			return texture(dem_tex, uv).r * dem_scale;
		}
	}
	return texture(heightmap, wxz / feature).r * disp;
}

void vertex() {
	vec2 uv01 = vec2(VERTEX.x, VERTEX.z);
	vec2 wxz = node_origin + uv01 * node_size;
	float d = morph_horizontal ? distance(cam_pos.xz, wxz) : distance(cam_pos, vec3(wxz.x, 0.0, wxz.y));
	float morph = clamp((d - morph_start) / max(morph_end - morph_start, 0.001), 0.0, 1.0);
	vec2 g = uv01 * grid;
	vec2 g_coarse = g - mod(g, 2.0);
	vec2 uvm = mix(uv01, g_coarse / grid, morph);
	wxz = node_origin + uvm * node_size;
	v_demuv = vec2(dem_cam.x + wxz.x / dem_mpp, dem_cam.y - wxz.y / dem_mpp) / dem_size;
	float h = sample_h(wxz);
	float e = max(node_size / grid, 2.0);
	float hl = sample_h(wxz + vec2(-e, 0.0));
	float hr = sample_h(wxz + vec2(e, 0.0));
	float hd = sample_h(wxz + vec2(0.0, -e));
	float hu = sample_h(wxz + vec2(0.0, e));
	v_n = normalize(vec3(hl - hr, 2.0 * e, hd - hu));
	v_h = h / max(disp, 1.0);
	float y = (VERTEX.y < -0.5) ? h - node_size * skirt : h;
	if (abs(wxz.y) > ring_width * 0.5) {
		y = -1.0e5;   // beyond the wall's lat position -> sink out of sight, never poke past the rim
	}
	vec3 world;
	if (ring_radius > 0.0) {
		float theta = wxz.x / ring_radius;
		float rr = ring_radius - y;
		float ct = cos(theta), stt = sin(theta);
		world = vec3(rr * stt, ring_radius - rr * ct, wxz.y);
		v_n = vec3(v_n.x * ct - v_n.y * stt, v_n.x * stt + v_n.y * ct, v_n.z);
	} else {
		world = vec3(wxz.x, y, wxz.y);
	}
	VERTEX = world;
	NORMAL = v_n;
	v_world_pos = world;   // instances never carry a transform (identity MODEL_MATRIX) -> VERTEX IS world pos
}

void fragment() {
	vec3 base = mix(vec3(0.30, 0.40, 0.24), vec3(0.52, 0.52, 0.48), smoothstep(0.45, 0.85, v_h));
	bool in_dem = v_demuv.x > 0.0 && v_demuv.x < 1.0 && v_demuv.y > 0.0 && v_demuv.y < 1.0;
	if (use_dem && has_sat && in_dem) {
		vec3 sat = texture(sat_tex, v_demuv).rgb * sat_gain;
		base = mix(base, sat, smoothstep(0.015, 0.05, dot(sat, vec3(0.333))));
		if (has_roads) {
			float road = texture(road_tex, v_demuv).r;
			base = mix(base, vec3(0.27, 0.27, 0.285), smoothstep(0.2, 0.75, road));
		}
	}
	if (show_lod) {
		vec3 lod_col = mix(vec3(0.1, 0.9, 0.2), vec3(0.95, 0.2, 0.1), lod_tint);
		base = mix(base, lod_col, 0.55);
	}
	vec3 n = normalize(v_n);
	if (!FRONT_FACING) { n = -n; }
	float diffuse = max(dot(n, normalize(to_sun)), 0.0);
	vec3 lit = base * (0.06 + 0.94 * diffuse);
	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	ALBEDO = mix(lit, sky_color, fog);
}
