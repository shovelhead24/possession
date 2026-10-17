shader_type canvas_item;
render_mode blend_add;
void fragment() {
 vec2 p=UV*2.0-1.0;float r=dot(p,p);
 vec3 tex=texture(TEXTURE,vec2(UV.x,UV.y+sin(TIME*17.0+UV.x*8.0)*.04)).rgb;
 float cloud=max(tex.g,tex.b);float core=exp(-r*24.0);
 COLOR=vec4(vec3(.04,.75,1.0)*(.3+cloud*1.8)+vec3(1.0)*core*3.0,pow(max(0.0,1.0-r),1.7)*COLOR.a);
}
