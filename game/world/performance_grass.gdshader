shader_type spatial;
global uniform vec3 ring_origin_offset;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D satellite : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D biome_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 home_origin;
uniform vec2 home_span;
uniform float ring_radius;
varying vec2 ground_metres;
varying vec3 spin_view;
varying vec3 lateral_view;
varying vec3 local_point;
varying vec3 ring_up_view;
varying float ground_height;
void vertex() {
 local_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec3 p=local_point+ring_origin_offset;
 float angle=atan(p.x,ring_radius-p.y);
 ground_metres=vec2(angle*ring_radius,p.z);
 ground_height=ring_radius-length(p.xy-vec2(0.0,ring_radius));
 ring_up_view=(VIEW_MATRIX*vec4(-sin(angle),cos(angle),0.0,0.0)).xyz;
 spin_view=(VIEW_MATRIX*vec4(cos(angle),sin(angle),0.0,0.0)).xyz;
 lateral_view=(VIEW_MATRIX*vec4(0.0,0.0,1.0,0.0)).xyz;
}
void fragment() {
 vec2 sat_uv=home_origin+vec2(ground_metres.x,-ground_metres.y)/home_span;
 float local_weight=1.0-smoothstep(1536.0,1600.0,max(abs(ground_metres.x),abs(ground_metres.y)));
 vec2 uv=ground_metres/4.0;
 // Saved low-resolution colour controls survive distance and origin shifts.
 vec3 controls=texture(biome_mask,ground_metres/3200.0+0.5).rgb;
 float dry=smoothstep(0.32,0.68,controls.r+0.14*(controls.g-0.5));
 vec3 tint=mix(vec3(0.15,0.17,0.075),vec3(0.28,0.225,0.125),dry);
 float distance_m=length(local_point-CAMERA_POSITION_WORLD);
 vec3 blades=texture(grass,uv).rgb;
 float blade_value=dot(blades,vec3(0.299,0.587,0.114));
 // Fade recognizable 4 m repeats; retain the baked landscape-scale patches.
 float blade_detail=1.0-smoothstep(18.0,110.0,distance_m);
 vec3 grass_colour=tint*mix(1.0,clamp(blade_value/0.16,0.45,1.65),blade_detail);
 grass_colour*=mix(0.82,1.16,controls.g)*mix(0.73,1.27,controls.b);
 // A weak larger-scale texture bridges blades and the metre-scale saved mask.
 vec3 coarse_grass=texture(grass,ground_metres/29.0+vec2(0.37,0.13)).rgb;
 float coarse_value=dot(coarse_grass,vec3(0.299,0.587,0.114));
 grass_colour*=mix(1.0,clamp(coarse_value/0.16,0.55,1.5),0.3*(1.0-smoothstep(180.0,650.0,distance_m)));
 // Ring-relative slope is measured before adding fine bump detail.
 vec3 n=normalize(NORMAL);
 float steepness=1.0-clamp(dot(n,normalize(ring_up_view)),0.0,1.0);
 float rock_weight=smoothstep(0.16,0.43,steepness+(controls.g-0.5)*0.15);
 vec3 rock_colour=vec3(0.22,0.235,0.25);
 if(rock_weight>0.001){
  // Two vertical projections avoid stretching grass UVs down cliff faces.
  vec2 side_weights=pow(abs(vec2(dot(n,normalize(spin_view)),dot(n,normalize(lateral_view)))),vec2(4.0));
  side_weights/=max(side_weights.x+side_weights.y,0.0001);
  vec3 stone=texture(rock,vec2(ground_metres.y,ground_height)/7.0).rgb*side_weights.x;
  stone+=texture(rock,vec2(ground_metres.x,ground_height)/7.0).rgb*side_weights.y;
  float stone_value=dot(stone,vec3(0.299,0.587,0.114));
  rock_colour*=mix(0.85+controls.g*0.3,clamp(stone_value/0.35,0.5,1.5),1.0-smoothstep(45.0,220.0,distance_m));
 }
 ALBEDO=mix(texture(satellite,sat_uv).rgb,mix(grass_colour,rock_colour,rock_weight),local_weight);
 float detail=(1.0-smoothstep(25.0,65.0,length(local_point-CAMERA_POSITION_WORLD)))*local_weight;
 if(detail>0.001){
  float h=texture(grass_height,uv).r;
  vec2 slope=vec2(texture(grass_height,uv+vec2(.002,0.0)).r-h,texture(grass_height,uv+vec2(0.0,.002)).r-h);
  NORMAL=normalize(NORMAL-(spin_view*slope.x+lateral_view*slope.y)*1.5*detail*(1.0-rock_weight));
 }
 ROUGHNESS=1.0;
 METALLIC=0.0;
}
