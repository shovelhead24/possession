import bpy,json
from pathlib import Path
from mathutils import Vector
r=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\Bran the builder\Downloads\alienreptile1b.blend')
report=[]
for lod in ['High','Med','Low']:
    o=bpy.data.objects['AlienReptile1b'+lod]
    bpy.ops.object.select_all(action='DESELECT')
    o.hide_set(False);o.hide_viewport=False;o.hide_render=False;o.select_set(True)
    bpy.context.view_layer.objects.active=o
    m=bpy.data.materials.new('Reptile skin '+lod);m.use_nodes=True
    ns=m.node_tree.nodes;bs=ns.get('Principled BSDF');bs.inputs['Roughness'].default_value=.72
    tex=ns.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(r/'Alien4bDiffuse.png'))
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    n=ns.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(r/('Alien4Nrm'+lod+'.png')));n.image.colorspace_settings.name='Non-Color'
    nm=ns.new('ShaderNodeNormalMap');m.node_tree.links.new(n.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    o.data.materials.clear();o.data.materials.append(m)
    # Bake authoring transforms and provisionally normalize standing height to 2.4 m.
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    points=[o.matrix_world@Vector(c) for c in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    origin=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));scale=2.4/(hi.z-lo.z)
    for v in o.data.vertices:v.co=(o.matrix_world@v.co-origin)*scale
    o.matrix_world.identity()
    bpy.ops.export_scene.gltf(filepath=str(r/('alien_reptile_'+lod.lower()+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
    report.append({'lod':lod,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'uv_layers':len(o.data.uv_layers)})
(r/'prepared.json').write_text(json.dumps(report,indent=2))
