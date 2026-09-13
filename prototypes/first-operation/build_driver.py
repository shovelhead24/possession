import bpy, math, os
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=r'C:\Games\possession\game\soldier.fbx')
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data_clear()
# Aim each limb in armature space, retaining its length and inherited joint position.
def aim(name, direction):
    b=rig.pose.bones['mixamorig:'+name]
    bpy.context.view_layer.update()
    m=b.matrix.copy()
    q=m.to_3x3().col[1].normalized().rotation_difference(Vector(direction).normalized())
    posed=q.to_matrix().to_4x4() @ m
    posed.translation=m.translation
    b.matrix=posed
    bpy.context.view_layer.update()
for side,sign in [('Left',1),('Right',-1)]:
    aim(side+'UpLeg',(sign*.10,-.12,1))
    aim(side+'Leg',(0,-1,.22))
    aim(side+'Foot',(sign*.08,-.1,1))
    aim(side+'Arm',(sign*.15,-.85,.5))
    aim(side+'ForeArm',(-sign*.1,.15,1))
    aim(side+'Hand',(0,0,1))
for key in ['LeftArm','LeftForeArm','LeftUpLeg','LeftLeg']:
    b=rig.pose.bones['mixamorig:'+key]
    print('POSE',key,list(b.head),list(b.tail),list(b.rotation_quaternion))
# Bake the seated reference pose; source FBX and its skeleton remain untouched.
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        print('MODIFIERS',[(m.name,m.type) for m in o.modifiers])
        bpy.context.view_layer.objects.active=o
        for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        world=o.matrix_world.copy()
        o.parent=None
        o.matrix_world=world
        print('DRIVER_VERTICES',len(o.data.vertices))
        if len(o.data.polygons)>20000:
            mod=o.modifiers.new('Sandbox budget','DECIMATE');mod.ratio=20000/len(o.data.polygons)
            bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.data.objects.remove(rig,do_unlink=True)
for img in bpy.data.images:
    if img.size[0]>1024 or img.size[1]>1024:
        ratio=1024/max(img.size)
        img.scale(round(img.size[0]*ratio),round(img.size[1]*ratio))
out=os.path.join(os.path.dirname(__file__),'seated_driver.glb')
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_animations=False)
print('DRIVER_EXPORTED',out)
