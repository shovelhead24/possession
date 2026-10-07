shader_type spatial;
uniform sampler2D skin_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
void fragment(){
 vec3 original=texture(skin_texture,UV).rgb;
 float detail=dot(original,vec3(.299,.587,.114));
 ALBEDO=mix(vec3(.48,.16,.64)*detail*1.9,original,.08);
 NORMAL_MAP=texture(skin_normal,UV).rgb;
 ROUGHNESS=.72;
}
