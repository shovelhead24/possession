shader_type spatial;
render_mode cull_disabled;   // double-sided while prototyping so surface orientation is never the confusion
// CDLOD terrain node. One shared unit grid ([0,1] on X/Z) is drawn per quadtree node, scaled to
// the node's size. Vertices are displaced by a heightmap (vertex texture fetch) and MORPHED toward
// the next-coarser grid as they approach the node's far LOD range — so when a node flips to a
// coarser level the geometry already matches: no pop, no cracks. This is the whole point.

uniform sampler2D heightmap : repeat_enable;
uniform float terrain_size = 4096.0;
uniform float feature = 3500.0;   // heightmap tiling period (mountain spacing)
uniform float disp = 300.0;
uniform float ring_radius = 0.0;  // 0 = flat; >0 bends terrain onto the cylinder
uniform bool curve = true;
uniform vec2 node_origin = vec2(0.0);   // world XZ of this node's corner
uniform float node_size = 128.0;         // world size of this node
uniform float morph_start = 0.0;         // distance where morph-to-coarser begins
uniform float morph_end = 1.0;           // distance where it's fully coarse
uniform vec3 cam_pos = vec3(0.0);
uniform float grid = 16.0;               // quads per node side (matches GD GRID)
uniform float lod_tint = 0.0;            // 0(fine)..1(coarse) for the LOD colour view
uniform bool show_lod = false;
uniform bool morph_horizontal = false;   // morph distance: horizontal vs 3D (incl. cam height)
uniform float skirt = 0.15;               // skirt depth as fraction of node size (verts marked y<-0.5)

varying float v_h;
varying vec3 v_n;

float sample_h(vec2 wxz) {
	return texture(heightmap, wxz / feature).r * disp;   // tiled (repeat) so mountains recur
}

void vertex() {
	vec2 uv01 = vec2(VERTEX.x, VERTEX.z);          // grid vertex in [0,1]
	vec2 wxz = node_origin + uv01 * node_size;
	float d = morph_horizontal ? distance(cam_pos.xz, wxz) : distance(cam_pos, vec3(wxz.x, 0.0, wxz.y));
	float morph = clamp((d - morph_start) / max(morph_end - morph_start, 0.001), 0.0, 1.0);
	// morph target: snap to the coarser (every-other) grid line — collapses odd verts onto even
	vec2 g = uv01 * grid;
	vec2 g_coarse = g - mod(g, 2.0);
	vec2 uvm = mix(uv01, g_coarse / grid, morph);
	wxz = node_origin + uvm * node_size;
	float h = sample_h(wxz);
	// cheap gradient normal from the heightmap so terrain shape reads
	float e = max(node_size / grid, 2.0);
	float hl = sample_h(wxz + vec2(-e, 0.0));
	float hr = sample_h(wxz + vec2(e, 0.0));
	float hd = sample_h(wxz + vec2(0.0, -e));
	float hu = sample_h(wxz + vec2(0.0, e));
	v_n = normalize(vec3(hl - hr, 2.0 * e, hd - hu));
	v_h = h / disp;
	// skirt verts (marked y=-1 in the unit grid) hang below the edge to hide residual cracks
	float y = (VERTEX.y < -0.5) ? h - node_size * skirt : h;
	if (curve && ring_radius > 0.0) {
		// bend flat (arc = wxz.x, lat = wxz.y, height = y) onto the cylinder interior
		float theta = wxz.x / ring_radius;
		float rr = ring_radius - y;
		float ct = cos(theta), stt = sin(theta);
		VERTEX = vec3(rr * stt, ring_radius - rr * ct, wxz.y);
		// rotate the flat normal about the ring axis (Z) by theta so lighting stays correct
		v_n = vec3(v_n.x * ct - v_n.y * stt, v_n.x * stt + v_n.y * ct, v_n.z);
	} else {
		VERTEX = vec3(wxz.x, y, wxz.y);   // flat: node instance is identity, output world position
	}
	NORMAL = v_n;
}

void fragment() {
	float nl = clamp(dot(normalize(v_n), normalize(vec3(0.4, 0.8, 0.3))), 0.0, 1.0);
	vec3 base = mix(vec3(0.30, 0.40, 0.24), vec3(0.52, 0.52, 0.48), smoothstep(0.45, 0.85, v_h));
	if (show_lod) {
		vec3 lod_col = mix(vec3(0.1, 0.9, 0.2), vec3(0.95, 0.2, 0.1), lod_tint);
		base = mix(base, lod_col, 0.55);
	}
	ALBEDO = base * (0.25 + 0.75 * nl);
	ROUGHNESS = 0.95;
}
