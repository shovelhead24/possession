shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,blend_mix,depth_draw_never;
uniform sampler2D cloud_atlas:filter_linear_mipmap,repeat_disable;
uniform bool geometry_oriented=false;
uniform float cloud_brightness=1.0;
uniform float exclude_near=0.0;
uniform vec4 distance_fade=vec4(0);
varying float tile_index;
varying float range_alpha;
void vertex(){
 vec3 delta=CAMERA_POSITION_WORLD-MODEL_MATRIX[3].xyz;
 float dist=length(delta);
 if(!geometry_oriented){
  vec3 local_up=normalize(MODEL_MATRIX[1].xyz);
  vec3 front=dist>0.01?delta/dist:-local_up;
  vec3 right=cross(local_up,front);
  if(length(right)<0.001){right=MODEL_MATRIX[0].xyz;}
  right=normalize(right-front*dot(right,front));vec3 up=normalize(cross(front,right));
  MODELVIEW_MATRIX[0]=VIEW_MATRIX*vec4(right*length(MODEL_MATRIX[0].xyz),0);
  MODELVIEW_MATRIX[1]=VIEW_MATRIX*vec4(up*length(MODEL_MATRIX[1].xyz),0);
  MODELVIEW_MATRIX[2]=VIEW_MATRIX*vec4(front,0);
 }
 tile_index=min(63.0,floor(INSTANCE_CUSTOM.a*64.0));range_alpha=1.0;
 if(distance_fade.y>distance_fade.x){range_alpha*=smoothstep(distance_fade.x,distance_fade.y,dist);}
 if(distance_fade.w>distance_fade.z){range_alpha*=1.0-smoothstep(distance_fade.z,distance_fade.w,dist);}
 if(exclude_near>0.0){range_alpha*=smoothstep(exclude_near-200.0,exclude_near+200.0,dist);}
}
void fragment(){
 if(range_alpha<0.001){discard;}
 vec2 cell=vec2(mod(tile_index,8.0),floor(tile_index/8.0));
 vec2 uv=(cell+(UV*255.0+0.5)/256.0)/8.0;
 vec4 tex=texture(cloud_atlas,uv);
 if(tex.a<0.008){discard;}
 ALBEDO=tex.rgb*vec3(0.94,0.96,1.0)*cloud_brightness;
 ALPHA=tex.a*range_alpha;
}
