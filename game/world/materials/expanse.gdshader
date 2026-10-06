shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D limestone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sparse_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sparse_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sparse_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool nature_surface = false;
uniform bool textured = true;
uniform bool bridge_enabled = true;
uniform bool overpass_enabled = false;
uniform bool compound_floors = false;
uniform bool coarse_surface = false;
uniform bool detail_surface = false;
uniform float coarse_inner_extent = 0.0;
uniform sampler2D detail_mask : filter_nearest, repeat_disable;
uniform float local_extent = 384.0;
uniform bool cached_surface_normals = false;
uniform sampler2D surface_normal_texture : filter_linear_mipmap, repeat_disable;
uniform vec4 surface_normal_rect;
uniform bool satellite_enabled = false;
uniform bool satellite_preview_ready = false;
uniform sampler2D satellite_preview : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2DArray satellite_pages_0 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2DArray satellite_pages_1 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2DArray satellite_pages_2 : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 satellite_origin;
uniform vec2 satellite_span;
uniform vec4 satellite_rects[9];
uniform int satellite_levels[9];
// Tile coverage in metres; limestone aspect ratio preserves the source image.
uniform float grass_metres = 2.0;
uniform float rock_metres = 3.0;
uniform vec2 stone_metres = vec2(1.656, 1.27144);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 n, vec3 w, vec2 metres) {
	vec3 s = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), n));
	return texture(tex, vec2(-s.x * p.z, p.y) / metres) * w.x
		+ texture(tex, vec2(p.x, -s.y * p.z) / metres) * w.y
		+ texture(tex, vec2(s.z * p.x, p.y) / metres) * w.z;
}

// Project tangent perturbations into world space. A flat normal map leaves
// the original mesh normal unchanged, including on undersides and blends.
vec3 detail_normal(sampler2D tex, vec3 p, vec3 n, vec3 w, float metres) {
	vec3 s = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), n));
	vec2 x = texture(tex, vec2(-s.x * p.z, p.y) / metres).rg * 2.0 - 1.0;
	vec2 y = texture(tex, vec2(p.x, -s.y * p.z) / metres).rg * 2.0 - 1.0;
	vec2 z = texture(tex, vec2(s.z * p.x, p.y) / metres).rg * 2.0 - 1.0;
	vec3 bump = vec3(0.0, x.y, -s.x * x.x) * w.x
		+ vec3(y.x, 0.0, -s.y * y.y) * w.y
		+ vec3(s.z * z.x, z.y, 0.0) * w.z;
	return normalize(n + 0.55 * (bump - n * dot(bump, n)));
}

float bridge_field(vec3 p) {
	vec3 q = abs(p - vec3(-65.0, 6.0, 45.0)) - vec3(28.0, 10.0, 10.0);
	float block = length(max(q, vec3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
	float arch = (length(vec2((p.x + 65.0) / 18.0, (p.y - 1.0) / 11.0)) - 1.0) * 11.0;
	return max(block, -arch);
}

float patch_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float patch_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(patch_hash(i),patch_hash(i+vec2(1,0)),f.x),mix(patch_hash(i+vec2(0,1)),patch_hash(i+vec2(1,1)),f.x),f.y);
}

vec3 ground_normal(sampler2D tex, vec2 uv, vec3 n) {
	vec2 bump=texture(tex,uv).rg*2.0-1.0;
	vec3 world_bump=vec3(bump.x,0.0,-bump.y);
	return normalize(n+0.45*(world_bump-n*dot(world_bump,n)));
}

vec3 satellite_color(vec3 p, vec3 fallback) {
	float radius=3000000.0/6.28318530718;
	float arc=atan(p.x,radius-p.y)*radius;
	vec2 uv=satellite_origin+vec2(arc,-p.z)/satellite_span;
	vec3 color=satellite_preview_ready ? texture(satellite_preview,uv).rgb : fallback;
	vec2 pixel=uv*8192.0;
	for (int i=0;i<9;i++) {
		if (satellite_levels[i]<0) { continue; }
		vec2 local=pixel-satellite_rects[i].xy;
		if (min(local.x,local.y)<0.0 || max(local.x,local.y)>=256.0) { continue; }
		float scale=exp2(float(satellite_levels[i]));
		vec3 tuv=vec3((local/scale+vec2(1.0))/(256.0/scale+2.0),float(i));
		if (satellite_levels[i]==0) { color=texture(satellite_pages_0,tuv).rgb; }
		else if (satellite_levels[i]==1) { color=texture(satellite_pages_1,tuv).rgb; }
		else { color=texture(satellite_pages_2,tuv).rgb; }
		break;
	}
	return color;
}

void fragment() {
	vec3 p = world_position;
	if (coarse_surface && max(abs(p.x),abs(p.z))<coarse_inner_extent) { discard; }
	// Screen-space ordered dither: the same threshold gives complementary
	// opaque coverage, avoiding alpha sorting and keeping the coarse fallback.
	if (coarse_surface || detail_surface) {
		float coverage = texture(detail_mask,(p.xz+vec2(local_extent))/(2.0*local_extent)).r;
		vec2 cell = mod(floor(FRAGCOORD.xy),4.0);
		float ranks[16] = float[16](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);
		float threshold = (ranks[int(cell.y)*4+int(cell.x)]+0.5)/16.0;
		if (coarse_surface && threshold < coverage) { discard; }
		if (detail_surface && threshold >= coverage) { discard; }
	}
	// The two recovered buildings retain floors at their original terrain datum.
	// Reserve those footprints visually to prevent coincident grass/floor surfaces.
	if (compound_floors && abs(p.y-5.0)<0.1 &&
		((abs(p.x-46.0)<6.0 && abs(p.z+197.0)<7.0) || (abs(p.x-83.0)<6.0 && abs(p.z+203.0)<7.0))) { discard; }
	vec3 n = normalize(world_normal);
	if (cached_surface_normals) {
		vec2 normal_uv=((p.xz-surface_normal_rect.xy)/surface_normal_rect.zw*32.0+vec2(0.5))/33.0;
		n=normalize(texture(surface_normal_texture,normal_uv).rgb*2.0-1.0);
	}
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	bool stone_bridge = false;
	if (bridge_enabled && abs(p.x + 65.0) < 29.0 && abs(p.z - 45.0) < 11.0) {
		float broad = smoothstep(28.0, 60.0, length(p.xz)) * (1.5 * sin(p.x * 0.035) * cos(p.z * 0.028));
		float basin = 5.0 * exp(-dot((p.xz - vec2(45.0, -80.0)) / vec2(24.0, 28.0), (p.xz - vec2(45.0, -80.0)) / vec2(24.0, 28.0)));
		stone_bridge = bridge_field(p) < p.y - broad + basin;
	}
	ROUGHNESS = 0.95;
	if (!textured) {
		ALBEDO = vec3(0.48, 0.55, 0.40);
	} else if (stone_bridge
		|| (overpass_enabled && abs(p.x+154.0)<44.0 && abs(p.z+80.0)<12.0 && (p.y>5.0 || abs(abs(p.x+154.0)-32.0)<3.2))) {
		ALBEDO = triplanar(limestone, p, n, w, stone_metres).rgb * (overpass_enabled ? 0.72 : 1.0);
	} else {
		float grass = smoothstep(0.55, 0.85, n.y);
		// A shared world-space cover field: metre-scale material detail, broad
		// irregular dry patches, and more exposed stone on steep/high ground.
		float macro=patch_noise(p.xz/43.0);
		float patches=0.7*macro+0.3*patch_noise(p.xz/11.0);
		float sparse=smoothstep(0.38,0.7,patches+smoothstep(12.0,52.0,p.y)*0.16);
		if (nature_surface) { grass*=1.0-smoothstep(0.68,0.88,patches)*0.55; }
		float near_detail=1.0-smoothstep(35.0,90.0,distance(p,INV_VIEW_MATRIX[3].xyz));
		vec3 detailed = n;
		vec3 color = vec3(0.0);
		vec3 rock_detail = n;
		// Most pixels are wholly grass or rock; only sample both in transitions.
		if (grass < 1.0) {
			color = triplanar(rock_albedo, p, n, w, vec2(rock_metres)).rgb;
			ROUGHNESS = mix(triplanar(rock_roughness, p, n, w, vec2(rock_metres)).r, 0.95, grass);
			if (!nature_surface || near_detail>0.0) { rock_detail = normalize(mix(n,detail_normal(rock_normal,p,n,w,rock_metres),nature_surface ? near_detail : 1.0)); }
			detailed = rock_detail;
		}
		if (grass > 0.0) {
			if (nature_surface) {
				// Ground cover only exists on upward slopes: one planar lookup
				// per map, not three triplanar projections per grass layer.
				vec2 uv=vec2(p.x,-p.z)/grass_metres;
				vec2 sparse_uv=vec2(p.x,-p.z)/2.0+vec2(0.37,0.19);
				vec3 cover=vec3(0.0);vec3 cover_normal=n;float rough=0.95;
				if (sparse<1.0) {
					cover=mix(texture(grass_albedo,uv).rgb,texture(grass_albedo,uv*0.731+vec2(0.31,0.67)).rgb,0.4);
					cover*=vec3(0.68,1.04,0.64);rough=texture(grass_roughness,uv).r;
					if (near_detail>0.0) { cover_normal=ground_normal(grass_normal,uv,n); }
				}
				if (sparse>0.0) {
					cover=mix(cover,texture(sparse_albedo,sparse_uv).rgb,sparse);
					rough=mix(rough,texture(sparse_roughness,sparse_uv).r,sparse);
					if (near_detail>0.0) { cover_normal=normalize(mix(cover_normal,ground_normal(sparse_normal,sparse_uv,n),sparse)); }
				}
				cover*=mix(vec3(0.82,0.86,0.75),vec3(1.06,1.02,0.91),macro);
				color=mix(color,cover,grass);ROUGHNESS=mix(ROUGHNESS,rough,grass);
				detailed=normalize(mix(rock_detail,normalize(mix(n,cover_normal,near_detail)),grass));
			} else {
				color = mix(color, triplanar(grass_albedo, p, n, w, vec2(grass_metres)).rgb, grass);
				detailed = normalize(mix(rock_detail, detail_normal(grass_normal, p, n, w, grass_metres), grass));
			}
		}
		if (satellite_enabled) {
			float amount=smoothstep(768.0,1024.0,max(abs(p.x),abs(p.z)))*smoothstep(0.1,0.65,n.y);
			if (amount>0.0) {
				vec3 satellite=satellite_color(p,color)*1.15;
				color=mix(color,satellite*mix(vec3(1.0),color*1.5,near_detail*0.35),amount);
			}
		}
		ALBEDO = color;
		NORMAL = normalize((VIEW_MATRIX * vec4(detailed, 0.0)).xyz);
	}
}
