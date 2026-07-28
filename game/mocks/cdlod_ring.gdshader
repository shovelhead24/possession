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
varying vec2 v_tile_uv;   // repeating drape UV for the beyond-DEM fallback (same imagery, tiled)
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
	v_tile_uv = vec2(wxz.x, -wxz.y) / (dem_mpp * dem_size);   // repeats every patch-width of arc/lat
	float h = sample_h(wxz);
	float e = max(node_size / grid, 2.0);
	float hl = sample_h(wxz + vec2(-e, 0.0));
	float hr = sample_h(wxz + vec2(e, 0.0));
	float hd = sample_h(wxz + vec2(0.0, -e));
	float hu = sample_h(wxz + vec2(0.0, e));
	v_n = normalize(vec3(hl - hr, 2.0 * e, hd - hu));
	v_h = h / max(disp, 1.0);
	float y = (VERTEX.y < -0.5) ? h - node_size * skirt : h;
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
	// beyond the walls' lat position -> never rendered at all (was a vertex-space sink before,
	// which folded into a visible "wall" of geometry at the tile straddling the boundary — clean
	// discard instead, per-fragment, no folded geometry).
	if (abs(v_world_pos.z) > ring_width * 0.5) {
		discard;
	}
	// hide the geometric underside. The first attempt at this (discard on !FRONT_FACING) had it
	// backwards — confirmed empirically: it discarded the wanted top surface and kept the underside
	// visible as a textured "ceiling". Flipped here: this mesh's wanted surface reports FRONT_FACING
	// == false for this winding, so the unwanted side is FRONT_FACING == true.
	if (FRONT_FACING) {
		discard;
	}
	vec3 base = mix(vec3(0.30, 0.40, 0.24), vec3(0.52, 0.52, 0.48), smoothstep(0.45, 0.85, v_h));
	// inside the mapped DEM patch: accurately-placed real imagery. Beyond it (but still within the
	// CDLOD bubble): the SAME imagery tiled, matching the far band's treatment — no more flat noise-
	// terrain gap between the real patch and the tiled band.
	bool in_dem = v_demuv.x > 0.0 && v_demuv.x < 1.0 && v_demuv.y > 0.0 && v_demuv.y < 1.0;
	if (has_sat) {
		vec2 uv = in_dem ? v_demuv : v_tile_uv;
		vec3 sat = texture(sat_tex, uv).rgb * sat_gain;
		base = mix(base, sat, smoothstep(0.015, 0.05, dot(sat, vec3(0.333))));
		if (has_roads) {
			float road = texture(road_tex, uv).r;
			base = mix(base, vec3(0.27, 0.27, 0.285), smoothstep(0.2, 0.75, road));
		}
	}
	if (show_lod) {
		vec3 lod_col = mix(vec3(0.1, 0.9, 0.2), vec3(0.95, 0.2, 0.1), lod_tint);
		base = mix(base, lod_col, 0.55);
	}
	// v_n comes from the height GRADIENT (hl-hr, 2e, hd-hu), not from triangle winding, so it always
	// points physically "up/outward" already — no FRONT_FACING flip needed (that was copy-pasted
	// from band/wall's winding-derived generate_normals() normals, where the flip IS correct; here
	// it was inverting an already-correct normal, which is what made day/night read backwards).
	vec3 n = normalize(v_n);
	float diffuse = max(dot(n, normalize(to_sun)), 0.0);
	vec3 lit = base * (0.16 + 0.84 * diffuse);   // floor raised (0.06->0.16); scene read "way too dark" overall
	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	ALBEDO = mix(lit, sky_color, fog);
}
