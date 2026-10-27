shader_type spatial;
render_mode diffuse_burley, specular_disabled;
#include "res://world/showcase_tree_bend.gdshaderinc"
uniform sampler2D bark_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform bool bark_has_texture=false;
uniform vec4 bark_colour : source_color=vec4(1.0);
uniform vec3 bark_uv_scale=vec3(1.0);
uniform vec3 bark_uv_offset=vec3(0.0);
void vertex(){bend_tree(VERTEX,NORMAL,MODEL_MATRIX,TIME,INSTANCE_CUSTOM.x,distance(MODEL_MATRIX[3].xyz,CAMERA_POSITION_WORLD));}
void fragment(){
 ALBEDO=bark_colour.rgb;
 if(bark_has_texture){ALBEDO*=texture(bark_tex,UV*bark_uv_scale.xy+bark_uv_offset.xy).rgb;}
 ROUGHNESS=1.0;
}
