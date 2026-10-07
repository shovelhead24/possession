import bpy, math, os
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=r'C:\Games\possession\game\soldier.fbx')
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');rig.animation_data_clear()
def bone(n): return rig.pose.bones['mixamorig:'+n]
def aim(n,target):
 b=bone(n);bpy.context.view_layer.update();m=b.matrix.copy();direction=Vector(target)-b.head
 q=m.to_3x3().col[1].normalized().rotation_difference(direction.normalized());posed=q.to_matrix().to_4x4()@m;posed.translation=m.translation;b.matrix=posed;bpy.context.view_layer.update()
def solve(upper,lower,target,pole):
 bpy.context.view_layer.update();a=bone(upper).head.copy();target=Vector(target);axis=(target-a).normalized();d=(target-a).length
 l1=bone(upper).length;l2=bone(lower).length;d=min(d,l1+l2-.01);along=(l1*l1-l2*l2+d*d)/(2*d)
 bend=Vector(pole);bend=(bend-axis*bend.dot(axis)).normalized();joint=a+axis*along+bend*math.sqrt(max(0,l1*l1-along*along))
 aim(upper,joint);aim(lower,target)
rig.animation_data_create();action=bpy.data.actions.new('GunnerCrouch');rig.animation_data.action=action
for frame in range(1,62):
 t=(frame-1)/60;angle=math.radians(-30+60*t)
 for b in rig.pose.bones:b.matrix_basis.identity();b.rotation_mode='QUATERNION'
 bpy.context.view_layer.update();hips=bone('Hips');m=hips.matrix.copy();m.translation.y-=12+35*t;hips.matrix=m;bpy.context.view_layer.update()
 for side,s in [('Left',1),('Right',-1)]:
  solve(side+'UpLeg',side+'Leg',(s*19,10,-5),(0,0,1));aim(side+'Foot',(s*23,1,8))
  # Grip offsets relative to the pitch pivot: rearward .45 m, upward .2 m.
  hand_y=(1.75-.85+.20*math.cos(angle)-.45*math.sin(angle))*100
  hand_z=(1.64-(.67+.45*math.cos(angle)+.20*math.sin(angle)))*100
  solve(side+'Arm',side+'ForeArm',(s*12,hand_y,hand_z),(s,0,-1))
  aim(side+'Hand',(s*12,hand_y,hand_z+9))
  for finger in ['Index','Middle','Ring','Pinky']:
   for seg in ['1','2','3']:
    b=bone(side+'Hand'+finger+seg);b.rotation_mode='XYZ';b.rotation_euler.x=-.55
 for b in rig.pose.bones:
  b.keyframe_insert('location',frame=frame);b.keyframe_insert('rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler',frame=frame);b.keyframe_insert('scale',frame=frame)
for o in bpy.context.scene.objects:
 if o.type=='MESH' and len(o.data.polygons)>20000:
  bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Gunner budget','DECIMATE');mod.ratio=20000/len(o.data.polygons);bpy.ops.object.modifier_apply(modifier=mod.name)
for img in bpy.data.images:
 if max(img.size)>1024:
  ratio=1024/max(img.size);img.scale(round(img.size[0]*ratio),round(img.size[1]*ratio))
bpy.context.scene.render.fps=60;bpy.context.scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=os.path.join(os.path.dirname(__file__),'gunner.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
print('GUNNER_EXPORTED')
