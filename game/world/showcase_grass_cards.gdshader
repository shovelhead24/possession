shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://world/showcase_wind.gdshaderinc"
uniform sampler2D card_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float variety;
void vertex(){
 variety=INSTANCE_CUSTOM.x;
 float height=clamp(VERTEX.y/1.2,0.0,1.0);
 VERTEX+=wind_displacement(MODEL_MATRIX,TIME,height*height,.48,.22,variety);
}
void fragment(){
 vec4 sample_colour=texture(card_tex,UV);
 if(sample_colour.a<.4){discard;}
 float value=dot(sample_colour.rgb,vec3(.299,.587,.114));
 vec3 palette=mix(vec3(.12,.16,.065),vec3(.27,.215,.12),variety);
 ALBEDO=palette*clamp(value/.3,.35,1.65)*mix(vec3(1.0),sample_colour.rgb/max(value,.02),.25);
 ROUGHNESS=1.0;
 if(!FRONT_FACING){NORMAL=-NORMAL;}
}
void light(){
 float wrapped=clamp(dot(normalize(NORMAL),normalize(LIGHT))*.55+.45,0.0,1.0);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*wrapped;
}
