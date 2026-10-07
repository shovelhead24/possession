 vec3 ro=CAMERA_POSITION_WORLD;
 vec3 rd=normalize(world_position-ro);
 vec3 safe_rd=mix(vec3(-1.0),vec3(1.0),step(vec3(0.0),rd))*max(abs(rd),vec3(.000001));
 vec3 ta=(vec3(-768,-24,-768)-ro)/safe_rd;
 vec3 tb=(vec3(768,72,768)-ro)/safe_rd;
 vec3 lo=min(ta,tb);vec3 hi=max(ta,tb);
 float t=max(0.0,max(lo.x,max(lo.y,lo.z)));
 float end=min(hi.x,min(hi.y,hi.z));
 if(end<t){discard;}
 bool found=false;bool exhausted=true;
 vec3 p=ro+rd*t;
 float previous_t=t;
 float previous_f=arena_field(p);
 for(int i=0;i<4096;i++){
  if(i>=max_steps){break;}
  p=ro+rd*t;
  float f=arena_field(p);
  if(f<0.0 && previous_f>0.0){
   float a=previous_t;float b=t;
   for(int refine=0;refine<12;refine++){
    float m=(a+b)*.5;
    if(arena_field(ro+rd*m)>0.0){a=m;}else{b=m;}
   }
   t=(a+b)*.5;p=ro+rd*t;found=true;exhausted=false;break;
  }
  // Fixed metric tolerance keeps this initial comparison's geometry consistent.
  if(abs(f)<.025){found=true;exhausted=false;break;}
  previous_t=t;previous_f=f;t+=abs(f)/step_divisor;
  if(t>end){exhausted=false;break;}
 }
 if(!found && (!exhausted || !show_failures)){discard;}
 vec3 hit_normal=found?field_normal(p):vec3(0,1,0);
 vec4 hit_view=VIEW_MATRIX*vec4(p,1.0);
 LIGHT_VERTEX=hit_view.xyz;
 vec4 projected=PROJECTION_MATRIX*hit_view;
 DEPTH=projected.z/projected.w*.5+.5;
 if(!found){ALBEDO=vec3(1,0,1);EMISSION=vec3(.5,0,.5);ROUGHNESS=1.0;}
