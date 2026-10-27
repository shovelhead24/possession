shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 local_up=vec3(0.0,1.0,0.0);
uniform float camera_altitude=0.0;
uniform float mist_ceiling=25.0;
uniform float density=0.018;
uniform vec3 mist_color=vec3(0.86,0.89,0.91);
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
float integrated_fill(float h,float lower){
 float x=clamp((h-lower)/24.0,0.0,1.0);
 return min(h-lower,0.0)+24.0*(x-x*x*x+0.5*x*x*x*x);
}
void fragment(){
 float depth=texture(depth_texture,SCREEN_UV).r;
 vec3 ndc=vec3(SCREEN_UV,depth)*2.0-1.0;
 vec4 view=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
 vec3 endpoint=view.xyz/view.w;
 float distance_to_surface=min(length(endpoint),4000.0);
 vec3 ray=(INV_VIEW_MATRIX*vec4(normalize(endpoint),0.0)).xyz;
 float slope=dot(ray,local_up);
 // Clip the integration to the layer, including its soft upper boundary.
 float begin=0.0;float finish=distance_to_surface;
 if(abs(slope)>0.0001){
  float a=(-300.0-camera_altitude)/slope;
  float b=(mist_ceiling+40.0-camera_altitude)/slope;
  begin=max(0.0,min(a,b));finish=min(finish,max(a,b));
 }else if(camera_altitude>mist_ceiling+40.0){finish=0.0;}
 float segment=max(0.0,finish-begin);
 // Evaluate the bank near its upper surface once, then integrate the soft
 // height profile analytically. No per-pixel ray-marching loop.
 float top_distance=abs(slope)>0.0001 ? (mist_ceiling-camera_altitude)/slope : segment*0.5;
 vec3 point=INV_VIEW_MATRIX[3].xyz+ray*clamp(top_distance,begin,max(begin,finish));
 float bank=sin(point.x*0.009+TIME*0.012)*sin(point.z*0.011)*6.0
            +sin(point.x*0.023+point.z*0.017)*2.0;
 float lower=mist_ceiling-16.0+bank;
 float spin=dot(ray,vec3(local_up.y,-local_up.x,0.0));
 float curve=spin*spin/(2.0*477464.8293);
 float h0=camera_altitude+slope*begin-curve*begin*begin;
 float h1=camera_altitude+slope*finish-curve*finish*finish;
 float fill=abs(h1-h0)>0.01 ? (integrated_fill(h1,lower)-integrated_fill(h0,lower))/(h1-h0)
                         : 1.0-smoothstep(lower,lower+24.0,(h0+h1)*0.5);
 float optical_depth=clamp(fill,0.0,1.0)*segment*density;
 ALBEDO=mist_color;
 ALPHA=1.0-exp(-min(optical_depth,12.0));
}
