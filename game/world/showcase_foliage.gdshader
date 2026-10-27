shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform float sway=0.0;
#include "res://world/showcase_wind.gdshaderinc"
uniform sampler2D detail_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void vertex(){VERTEX+=wind_displacement(MODEL_MATRIX,TIME,UV.y*UV.y,.48,.22,INSTANCE_CUSTOM.x);}
void fragment(){
 float grain=dot(texture(detail_tex,vec2(UV.x*.18,UV.y*.65)).rgb,vec3(.299,.587,.114));
 vec3 straw=mix(vec3(.10,.085,.035),vec3(.38,.29,.135),smoothstep(0.0,1.0,UV.y));
 ALBEDO=straw*mix(.7,1.3,clamp(grain/.13,0.0,1.0));ROUGHNESS=1.0;
 if(!FRONT_FACING){NORMAL=-NORMAL;}
}
