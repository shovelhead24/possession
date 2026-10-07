import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
r=Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(r/'alien_reptile_high.glb'))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH');mesh.name='LizardSkin'
bpy.context.view_layer.objects.active=mesh;mesh.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Recenter the torso, rather than the tail-inclusive bounding box.
for v in mesh.data.vertices:v.co.y+=.7
def p(x,y,z):return Vector((x,y+.7,z))
bones={
 'Root':(p(0,-.7,0),p(0,-.7,.2),None),
 'Pelvis':(p(0,-.7,1.05),p(0,-.7,1.3),'Root'),
 'Spine':(p(0,-.7,1.3),p(0,-.7,1.75),'Pelvis'),
 'Neck':(p(0,-.7,1.75),p(0,-.7,2.02),'Spine'),
 'Head':(p(0,-.7,2.02),p(0,-.76,2.35),'Neck'),
 'Tail1':(p(0,-.58,1.08),p(0,-.08,.76),'Pelvis'),
 'Tail2':(p(0,-.08,.76),p(0,.45,.64),'Tail1'),
 'Tail3':(p(0,.45,.64),p(0,.97,.62),'Tail2'),
 'Rifle':(p(.26,-1.03,1.42),p(.26,-1.65,1.42),'Spine')}
for side,s in [('R',1),('L',-1)]:
 bones.update({
 'UpperArm.'+side:(p(s*.27,-.7,1.76),p(s*.47,-.72,1.4),'Spine'),
 'Forearm.'+side:(p(s*.47,-.72,1.4),p(s*.6,-.76,1.08),'UpperArm.'+side),
 'Hand.'+side:(p(s*.6,-.76,1.08),p(s*.64,-.84,.82),'Forearm.'+side),
 'Thigh.'+side:(p(s*.23,-.7,1.1),p(s*.4,-.77,.65),'Pelvis'),
 'Shin.'+side:(p(s*.4,-.77,.65),p(s*.4,-.64,.28),'Thigh.'+side),
 'Foot.'+side:(p(s*.4,-.64,.28),p(s*.4,-.88,.07),'Shin.'+side)})
arm=bpy.data.armatures.new('LizardSkeleton');rig=bpy.data.objects.new('LizardRig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
for name,(h,t,parent) in bones.items():
 b=arm.edit_bones.new(name);b.head=h;b.tail=t
 if parent:b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
def dist(v,a,b):
 d=b-a;return (v-(a+d*max(0,min(1,(v-a).dot(d)/d.length_squared)))).length
groups={n:mesh.vertex_groups.new(name=n) for n in bones if n not in ['Root','Rifle']}
# Surface distances keep neighbouring fingers and thighs on their own limbs.
import heapq
coords=[];lookup={};vertex_ids=[]
for v in mesh.data.vertices:
 key=tuple(round(c,5) for c in v.co)
 if key not in lookup:lookup[key]=len(coords);coords.append(v.co.copy())
 vertex_ids.append(lookup[key])
adj=[{} for v in coords]
for e in mesh.data.edges:
 a,b=[vertex_ids[i] for i in e.vertices]
 if a!=b:
  d=(coords[a]-coords[b]).length;adj[a][b]=d;adj[b][a]=d
fields={}
for name in groups:
 h,t,parent=bones[name];middle=(h+t)*.5
 seeds=sorted(range(len(coords)),key=lambda i:(coords[i]-middle).length)[:3]
 distances=[1e9]*len(coords);queue=[]
 for i in seeds:distances[i]=dist(coords[i],h,t);heapq.heappush(queue,(distances[i],i))
 while queue:
  d,i=heapq.heappop(queue)
  if d>distances[i]:continue
  for j,step in adj[i].items():
   nd=d+step
   if nd<distances[j]:distances[j]=nd;heapq.heappush(queue,(nd,j))
 fields[name]=distances
for v,i in zip(mesh.data.vertices,vertex_ids):
 near=sorted((field[i],name) for name,field in fields.items())[:3]
 if near[0][0]>1e8:near=sorted((dist(v.co,*bones[n][:2]),n) for n in groups)[:3]
 weights=[1/max(d,.02)**5 for d,n in near];total=sum(weights)
 for (d,n),w in zip(near,weights):groups[n].add([v.index],w/total,'REPLACE')
mesh.parent=rig;mod=mesh.modifiers.new('Skin','ARMATURE');mod.object=rig
def material(name,color,metal=0,glow=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=.4
 if glow:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=3
 return m
purple=material('Plasma receiver',(.13,.035,.23),.55);steel=material('Barrel metal',(.045,.06,.075),.8);glow=material('Plasma coils',(.12,.9,.6),.1,True)
def gunbox(name,loc,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.data.materials.append(mat);bev=o.modifiers.new('Machined edges','BEVEL');bev.width=.018;bev.segments=2;bpy.ops.object.modifier_apply(modifier=bev.name);g=o.vertex_groups.new(name='Rifle');g.add(list(range(len(o.data.vertices))),1,'REPLACE');o.parent=rig;mod=o.modifiers.new('Weapon attachment','ARMATURE');mod.object=rig
gunbox('PlasmaRifle',(.26,-.52,1.45),(.22,.64,.23),purple)
gunbox('Barrel',(.26,-.95,1.46),(.12,.35,.12),steel)
gunbox('Stock',(.26,-.12,1.44),(.16,.22,.2),steel)
gunbox('Grip',(.26,-.33,1.29),(.1,.12,.23),steel)
for y in [-.5,-.61,-.72]:gunbox('Coil',(.26,y,1.45),(.235,.035,.17),glow)
# Explicit muzzle joint is exported as part of the skeleton.
bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT');b=arm.edit_bones.new('Muzzle');b.head=(.26,-1.13,1.46);b.tail=(.26,-1.23,1.46);b.parent=arm.edit_bones['Rifle'];bpy.ops.object.mode_set(mode='OBJECT')
def aim_bone(name,target):
 bpy.context.view_layer.update();b=rig.pose.bones[name];mat=(Vector(target)-b.head).to_track_quat('Y','Z').to_matrix().to_4x4();mat.translation=b.head;b.matrix=mat;bpy.context.view_layer.update()
def ready_pose():
 for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 aim_bone('UpperArm.R',(.48,-.03,1.42));aim_bone('Forearm.R',(.26,-.33,1.4));aim_bone('Hand.R',(.26,-.47,1.4))
 aim_bone('UpperArm.L',(-.28,-.1,1.43));aim_bone('Forearm.L',(.15,-.65,1.42));aim_bone('Hand.L',(.26,-.75,1.42))
ready_pose();base={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
rig.animation_data_create();clips={}
for clip,length in [('Idle',60),('Run',24),('Fire',12),('Death',30),('Flee',24),('Walk',48),('Strafe',32),('Jump',24),('Crouch',48),('Dive',49),('Check',64),('Scratch',64),('Look',80),('Talk',64)]:
 act=bpy.data.actions.new(clip);rig.animation_data.action=act
 for f in range(1,length+1):
  t=(f-1)/(length-1);phase=t*math.tau
  for b in rig.pose.bones:b.matrix_basis=base[b.name].copy()
  if clip in ['Run','Flee','Walk','Strafe']:
   for side,s in [('R',1),('L',-1)]:
    rig.pose.bones['Thigh.'+side].rotation_euler.x+=math.sin(phase)*(.28 if clip=='Walk' else .55)*s
    rig.pose.bones['Shin.'+side].rotation_euler.x+=max(0,-math.sin(phase)*s)*.7
   rig.pose.bones['Pelvis'].location.y=abs(math.sin(phase))*.035
  elif clip=='Idle':rig.pose.bones['Spine'].rotation_euler.x+=math.sin(phase)*.018
  elif clip=='Fire':
   kick=math.sin(t*math.pi)*.13;rig.pose.bones['Spine'].rotation_euler.x-=kick;rig.pose.bones['Rifle'].location.y-=kick*.2
  elif clip=='Death':
   rig.pose.bones['Root'].rotation_euler.z=min(1,t*1.5)*1.5
  if clip=='Flee':
   for side,s in [('R',1),('L',-1)]:
    aim_bone('UpperArm.'+side,(s*.4,0,2.2));aim_bone('Forearm.'+side,(s*.5,.04,2.65));aim_bone('Hand.'+side,(s*.5,-.08,2.9))
    rig.pose.bones['Forearm.'+side].rotation_euler.z+=math.sin(phase)*.15
  elif clip=='Strafe':
   for side,s in [('R',1),('L',-1)]:rig.pose.bones['Thigh.'+side].rotation_euler.z+=math.sin(phase)*.3*s
  elif clip in ['Crouch','Jump']:
   fold=1 if clip=='Crouch' else math.sin(t*math.pi)
   rig.pose.bones['Pelvis'].location.y=(-.62 if clip=='Crouch' else -.42)*fold
   rig.pose.bones['Spine'].rotation_euler.x+=.2*fold
   for side in ['R','L']:
    rig.pose.bones['Thigh.'+side].rotation_euler.x-=.7*fold;rig.pose.bones['Shin.'+side].rotation_euler.x+=1.1*fold
  elif clip=='Dive':
   def smooth(a,b,v):
    u=max(0,min(1,(v-a)/(b-a)));return u*u*(3-2*u)
   extension=smooth(.06,.20,t)*(1-smooth(.30,.48,t))
   coil=math.sin(min(1,t/.14)*math.pi)*.25 if t<.14 else 0
   rig.pose.bones['Pelvis'].location.y=-coil
   # Reach forward with both arms and the rifle as the body leaves the ground.
   for side,s in [('R',1),('L',-1)]:
    aim_bone('UpperArm.'+side,(s*.3,0,2.15));aim_bone('Forearm.'+side,(s*.25,-.12,2.48));aim_bone('Hand.'+side,(s*.25,-.1,2.7))
   weapon=rig.pose.bones['Rifle'];mat=Vector((0,0,1)).to_track_quat('Y','Z').to_matrix().to_4x4();mat.translation=Vector((.25,-.12,2.38));weapon.matrix=mat
   bpy.context.view_layer.update()
   for name in ['UpperArm.R','UpperArm.L','Forearm.R','Forearm.L','Hand.R','Hand.L','Rifle']:
    rig.pose.bones[name].matrix_basis=base[name].lerp(rig.pose.bones[name].matrix_basis,extension)
   roll=smooth(.30,.84,t)
   pitch=1.4*smooth(.06,.24,t) if t<.30 else 1.4+(math.tau-1.4)*roll
   rig.pose.bones['Root'].rotation_euler.x=pitch
   rig.pose.bones['Root'].location.y=.12*extension
   tuck=smooth(.26,.43,t)*(1-smooth(.76,1,t))
   for side in ['R','L']:
    rig.pose.bones['Thigh.'+side].rotation_euler.x-=1.05*tuck
    rig.pose.bones['Shin.'+side].rotation_euler.x+=1.55*tuck+.25*extension
   rig.pose.bones['Spine'].rotation_euler.x+=.45*tuck
   rig.pose.bones['Head'].rotation_euler.x+=.35*tuck
   for name in ['Tail1','Tail2','Tail3']:
    rig.pose.bones[name].rotation_euler.x+=1.3*tuck
  elif clip=='Check':
   rig.pose.bones['Head'].rotation_euler.x+=.3*math.sin(t*math.pi)
   aim_bone('Forearm.L',(.18,-.4,1.5));rig.pose.bones['Hand.L'].rotation_euler.y+=math.sin(phase*2)*.15
  elif clip=='Scratch':
   aim_bone('UpperArm.L',(-.4,0,2.05));aim_bone('Forearm.L',(-.1,-.05,2.28));aim_bone('Hand.L',(-.05,-.06,2.38))
   rig.pose.bones['Hand.L'].rotation_euler.x+=math.sin(phase*3)*.25
  elif clip=='Look':rig.pose.bones['Head'].rotation_euler.y+=math.sin(phase)*.65
  elif clip=='Talk':
   rig.pose.bones['Head'].rotation_euler.y+=math.sin(phase)*.25
   aim_bone('Forearm.L',(-.35,-.6,1.65));rig.pose.bones['Forearm.L'].rotation_euler.z+=math.sin(phase*2)*.15
  if clip=='Crouch':
   # Solve each knee around a planted ankle, instead of pulling the feet underground.
   bpy.context.view_layer.update()
   for side,s in [('R',1),('L',-1)]:
    thigh=rig.pose.bones['Thigh.'+side];shin=rig.pose.bones['Shin.'+side]
    hip=thigh.head.copy();ankle=p(s*.4,-.64,.28);axis=(ankle-hip).normalized();d=(ankle-hip).length
    l1=arm.bones['Thigh.'+side].length;l2=arm.bones['Shin.'+side].length
    along=(l1*l1-l2*l2+d*d)/(2*d);bend=Vector((0,-1,0));bend=(bend-axis*bend.dot(axis)).normalized()
    knee=hip+axis*along+bend*math.sqrt(max(0,l1*l1-along*along))
    aim_bone('Thigh.'+side,knee);aim_bone('Shin.'+side,ankle);aim_bone('Foot.'+side,p(s*.4,-.88,.07))
  for n in ['Tail1','Tail2','Tail3']:rig.pose.bones[n].rotation_euler.z+=math.sin(phase+len(n))*.09
  if clip=='Death' or (clip=='Dive' and t>=.30):
   # Keep the collapsed skin above the ground throughout the fall.
   bpy.context.view_layer.update()
   evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
   lowest=min((evaluated.matrix_world@v.co).z for v in evaluated.data.vertices)
   rig.pose.bones['Root'].location.y+=.02-lowest
  for b in rig.pose.bones:
   b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert('rotation_euler',frame=f,group=b.name);b.keyframe_insert('scale',frame=f,group=b.name)
 act.use_fake_user=True;clips[clip]=act
 rig.animation_data.action=None
 track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,act)
for tr in rig.animation_data.nla_tracks:tr.mute=True
rig.animation_data.action=clips['Idle'];bpy.context.scene.frame_set(1)
rig.scale=(1.3/2.4,)*3
bpy.ops.wm.save_as_mainfile(filepath=str(r/'lizard_rig.blend'))
bpy.ops.export_scene.gltf(filepath=str(r/'lizard_rig.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
(r/'rig-report.json').write_text(json.dumps({'bones':len(arm.bones),'clips':list(clips),'height':1.3,'vertices':len(mesh.data.vertices)},indent=2))
