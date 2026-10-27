shader_type spatial;
#include "res://world/performance_ring_light.gdshaderinc"
varying vec3 regional_tint;
global uniform vec3 ring_origin_offset;
render_mode unshaded,cull_disabled,shadows_disabled,blend_mix,depth_draw_never;
uniform sampler2D cloud_atlas:filter_linear_mipmap,repeat_disable;
uniform bool geometry_oriented=false;
uniform float cloud_brightness=1.0;
uniform float exclude_near=0.0;
uniform vec4 distance_fade=vec4(0);
uniform float cloud_time=0.0;
uniform bool drift_enabled=false;
uniform bool evolution_enabled=false;
uniform float card_fraction=1.0;
uniform float weather_darkness=1.0;
uniform vec3 cloud_tint=vec3(1.0);
varying vec2 evolution_offset;
varying float evolution_scale;
varying float tile_index;
varying float range_alpha;
void vertex(){
 vec3 centre=MODEL_MATRIX[3].xyz;
 float wrap_alpha=1.0;
 if(drift_enabled){
  // Each card crosses a finite wind cell. Fade out before recycling, staggered
  // by its persisted seed. No geometry regeneration or unbounded world offsets.
  float cycle=fract(cloud_time*3.0/4096.0+INSTANCE_CUSTOM.a);
  float travel=(cycle-0.5)*4096.0;
  wrap_alpha=smoothstep(0.0,0.04,cycle)*(1.0-smoothstep(0.96,1.0,cycle));
  float angle=travel/477464.8293;
  vec2 radial=centre.xy+ring_origin_offset.xy-vec2(0.0,477464.8293);
  centre.xy=vec2(cos(angle)*radial.x-sin(angle)*radial.y,sin(angle)*radial.x+cos(angle)*radial.y)+vec2(0.0,477464.8293)-ring_origin_offset.xy;
  centre.z+=travel*0.3;
  MODELVIEW_MATRIX[3]=VIEW_MATRIX*vec4(centre,1.0);
 }
 regional_tint=ring_cycle_enabled?ring_cloud_light(ring_sun_height(centre)):cloud_tint;
 float phase=cloud_time*0.025+INSTANCE_CUSTOM.a*6.283185;
 evolution_offset=evolution_enabled?vec2(sin(phase),cos(phase*0.7))*0.018:vec2(0.0);
 evolution_scale=evolution_enabled?1.0+sin(phase*0.83)*0.035:1.0;
 vec3 delta=CAMERA_POSITION_WORLD-centre;
 float dist=length(delta);
 if(!geometry_oriented || drift_enabled){
  vec3 local_up=drift_enabled?normalize(vec3(-centre.x-ring_origin_offset.x,477464.8293-centre.y-ring_origin_offset.y,0.0)):normalize(MODEL_MATRIX[1].xyz);
  vec3 front=dist>0.01?delta/dist:-local_up;
  vec3 right=cross(local_up,front);
  if(length(right)<0.001){right=MODEL_MATRIX[0].xyz;}
  right=normalize(right-front*dot(right,front));vec3 up=normalize(cross(front,right));
  MODELVIEW_MATRIX[0]=VIEW_MATRIX*vec4(right*length(MODEL_MATRIX[0].xyz),0);
  MODELVIEW_MATRIX[1]=VIEW_MATRIX*vec4(up*length(MODEL_MATRIX[1].xyz),0);
  MODELVIEW_MATRIX[2]=VIEW_MATRIX*vec4(front,0);
 }
 tile_index=min(63.0,floor(INSTANCE_CUSTOM.a*64.0));range_alpha=wrap_alpha;
 if(fract(INSTANCE_CUSTOM.a*97.13+0.17)>=card_fraction){VERTEX=vec3(0.0);range_alpha=0.0;}
 if(distance_fade.y>distance_fade.x){range_alpha*=smoothstep(distance_fade.x,distance_fade.y,dist);}
 if(distance_fade.w>distance_fade.z){range_alpha*=1.0-smoothstep(distance_fade.z,distance_fade.w,dist);}
 if(exclude_near>0.0){range_alpha*=smoothstep(exclude_near-200.0,exclude_near+200.0,dist);}
}
void fragment(){
 if(range_alpha<0.001){discard;}
 vec2 cell=vec2(mod(tile_index,8.0),floor(tile_index/8.0));
 vec2 shape_uv=clamp((UV-0.5)*evolution_scale+0.5+evolution_offset,vec2(0.0),vec2(1.0));
 vec2 uv=(cell+(shape_uv*255.0+0.5)/256.0)/8.0;
 vec4 tex=texture(cloud_atlas,uv);
 if(tex.a<0.008){discard;}
 ALBEDO=tex.rgb*vec3(0.94,0.96,1.0)*cloud_brightness*regional_tint*weather_darkness;
 ALPHA=tex.a*range_alpha;
}
