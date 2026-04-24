extends Node3D

const PANE_W    = 50.0
const PANE_H    = 80.0
const PANE_STEP = 60.0   # pane width + gap
const N_PANES   = 10
const BASE_Z    = -300.0
const BASE_Y    = 130.0
const LAYER_DZ  = 20.0
const MAX_LAYERS = 5

const LABELS = [
	"1.Opaque",
	"2.blnd_dflt",
	"3.blnd+opq",
	"4.blnd+nvr",
	"5.blnd+ush",
	"6.additive",
	"7.IGN_50%",
	"8.Bayer4x4",
	"9.FBM+IGN",
	"10.FBM+blnd",
]

const _FBM_GLSL = """
float _h2(vec2 p){
	p=fract(p*vec2(.1031,.1030));
	p+=dot(p,p.yx+33.33);
	return fract((p.x+p.y)*p.x);
}
float _vn(vec2 p){
	vec2 i=floor(p),f=fract(p);
	f=f*f*(3.-2.*f);
	return mix(mix(_h2(i),_h2(i+vec2(1,0)),f.x),
	           mix(_h2(i+vec2(0,1)),_h2(i+vec2(1,1)),f.x),f.y);
}
float _fbm(vec2 p){
	float v=0.,a=.5;
	for(int i=0;i<5;i++){v+=a*_vn(p);p*=2.1;a*=.5;}
	return v;
}
"""

var _layer_count : int = 1
var _cols        : Array = []
var _col_labels  : Array = []
var _lbl_info    : Label3D = null

func _ready():
	_build()
	print("PaneTest: built  |  [ ] = layers  |  Shift+P = toggle")

func toggle():
	visible = not visible

func _unhandled_input(ev: InputEvent):
	if not visible: return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_BRACKETLEFT:
			_layer_count = max(1, _layer_count - 1)
			_rebuild_layers()
		elif ev.keycode == KEY_BRACKETRIGHT:
			_layer_count = min(MAX_LAYERS, _layer_count + 1)
			_rebuild_layers()

# ------------------------------------------------------------------ #

func _build():
	var ox = -(N_PANES - 1) * 0.5 * PANE_STEP
	for pi in range(N_PANES):
		var px = ox + pi * PANE_STEP
		var col = Node3D.new()
		col.name = "Col%d" % pi
		add_child(col)
		_cols.append(col)
		_fill_col(col, pi, px, _layer_count)

		var lbl = Label3D.new()
		lbl.text = LABELS[pi]
		lbl.font_size = 52
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.outline_size = 6
		lbl.outline_modulate = Color.BLACK
		lbl.modulate = Color(1.0, 1.0, 0.2)
		lbl.position = Vector3(px, BASE_Y + PANE_H * 0.5 + 9.0, BASE_Z)
		add_child(lbl)
		_col_labels.append(lbl)

	_lbl_info = Label3D.new()
	_lbl_info.font_size = 44
	_lbl_info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lbl_info.outline_size = 5
	_lbl_info.outline_modulate = Color.BLACK
	_lbl_info.modulate = Color(0.9, 0.9, 0.9)
	_lbl_info.position = Vector3(0, BASE_Y - PANE_H * 0.5 - 14.0, BASE_Z)
	add_child(_lbl_info)
	_refresh_info()

func _rebuild_layers():
	for pi in range(_cols.size()):
		var col = _cols[pi]
		for c in col.get_children(): c.queue_free()
		var px = -(N_PANES - 1) * 0.5 * PANE_STEP + pi * PANE_STEP
		_fill_col(col, pi, px, _layer_count)
	_refresh_info()

func _fill_col(col: Node3D, pi: int, px: float, n: int):
	for li in range(n):
		col.add_child(_make_pane(pi, px, BASE_Y, BASE_Z - li * LAYER_DZ))

func _refresh_info():
	if is_instance_valid(_lbl_info):
		_lbl_info.text = "Layers: %d   [  decrease    ]  increase   Shift+P hide" % _layer_count

# ------------------------------------------------------------------ #

func _make_pane(pi: int, px: float, py: float, pz: float) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw = PANE_W * 0.5
	var hh = PANE_H * 0.5
	st.set_normal(Vector3(0, 0, 1))
	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-hw, -hh, 0))
	st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3( hw, -hh, 0))
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(-hw,  hh, 0))
	st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3( hw, -hh, 0))
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3( hw,  hh, 0))
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(-hw,  hh, 0))

	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.position = Vector3(px, py, pz)

	var mat = ShaderMaterial.new()
	var sh  = Shader.new()
	sh.code = _shader_code(pi)
	mat.shader = sh
	mi.material_override = mat
	return mi

# ------------------------------------------------------------------ #
#  TEN SHADER VARIANTS                                                #
# ------------------------------------------------------------------ #

func _shader_code(idx: int) -> String:
	match idx:
		# 1 — solid opaque reference
		0: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled;
void fragment(){ ALBEDO=vec3(.75,.85,1.); }
"""
		# 2 — blend_mix only (default depth_draw)
		1: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled,blend_mix;
void fragment(){ ALBEDO=vec3(.4,.6,1.); ALPHA=.5; }
"""
		# 3 — blend_mix + depth_draw_opaque  (what the cloud layer shader uses)
		2: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled,blend_mix,depth_draw_opaque;
void fragment(){ ALBEDO=vec3(1.,.5,.5); ALPHA=.5; }
"""
		# 4 — blend_mix + depth_draw_never
		3: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled,blend_mix,depth_draw_never;
void fragment(){ ALBEDO=vec3(1.,.85,.3); ALPHA=.5; }
"""
		# 5 — blend_mix + unshaded  (no lighting path)
		4: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled,blend_mix,unshaded;
void fragment(){ ALBEDO=vec3(.4,1.,.5); ALPHA=.5; }
"""
		# 6 — additive blend  (blend_add + unshaded)
		5: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled,blend_add,depth_draw_never,unshaded;
void fragment(){ ALBEDO=vec3(.3,.3,.7); ALPHA=1.; }
"""
		# 7 — IGN discard at 50% density  (current cloud approach)
		6: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled;
void fragment(){
	float t=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))));
	if(.5<t) discard;
	ALBEDO=vec3(.8,.9,1.);
}
"""
		# 8 — Bayer 4x4 ordered dither at 50%
		7: return """shader_type spatial;
render_mode cull_disabled,shadows_disabled;
void fragment(){
	int bx=int(mod(FRAGCOORD.x,4.)),by=int(mod(FRAGCOORD.y,4.)),bi=by*4+bx;
	float b=0.;
	if     (bi==0)  b=0.;  else if(bi==1)  b=8.;  else if(bi==2)  b=2.;  else if(bi==3)  b=10.;
	else if(bi==4)  b=12.; else if(bi==5)  b=4.;  else if(bi==6)  b=14.; else if(bi==7)  b=6.;
	else if(bi==8)  b=3.;  else if(bi==9)  b=11.; else if(bi==10) b=1.;  else if(bi==11) b=9.;
	else if(bi==12) b=15.; else if(bi==13) b=7.;  else if(bi==14) b=13.; else           b=5.;
	if(.5<b/16.) discard;
	ALBEDO=vec3(.8,.9,1.);
}
"""
		# 9 — FBM cloud noise + IGN discard  (noise-shaped opaque)
		8: return ("shader_type spatial;\nrender_mode cull_disabled,shadows_disabled;\n"
				+ _FBM_GLSL
				+ """void fragment(){
	float d=_fbm(UV*8.);
	float density=smoothstep(.35,.65,d);
	float ign=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))));
	if(density<ign) discard;
	ALBEDO=mix(vec3(.62,.68,.75),vec3(1.,1.,1.),density);
}
""")
		# 10 — FBM cloud noise + blend_mix  (holy grail: real alpha with cloud shape)
		9: return ("shader_type spatial;\nrender_mode cull_disabled,shadows_disabled,blend_mix,depth_draw_never;\n"
				+ _FBM_GLSL
				+ """void fragment(){
	float d=_fbm(UV*8.);
	ALBEDO=mix(vec3(.62,.68,.75),vec3(1.,1.,1.),d);
	ALPHA=smoothstep(.35,.65,d);
}
""")
	return ""
