"""Fixed background validation and preview renderer; imports GLB, never source scripts."""
import bpy, sys, json, math
from pathlib import Path
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
folder = Path(args[0]).resolve()
category = args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / 'model.glb'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if not meshes:
    raise RuntimeError('No meshes in exported GLB')
triangles = 0
materials = set()
points = []
for obj in meshes:
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
    materials.update(m.name for m in obj.data.materials if m)
    points.extend(obj.matrix_world @ Vector(p) for p in obj.bound_box)
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
size = hi - lo
limit = 4500 if category == 'weapons' else 14000
if not all(math.isfinite(v) for v in (*lo, *hi)) or min(size) < 0.001:
    raise RuntimeError('Invalid or degenerate model bounds')
if triangles < 12 or triangles > limit:
    raise RuntimeError(f'Triangle count {triangles} outside 12..{limit}')
if len(materials) > 12:
    raise RuntimeError('More than 12 materials')
if not materials:
    raise RuntimeError('No assigned materials')
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 16
scene.render.resolution_x = 800
scene.render.resolution_y = 600
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
world = bpy.data.worlds.new('Studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.12, 0.15, 0.20, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.65
scene.world = world
center = (lo + hi) * 0.5
span = max(size)
for name, offset, energy, scale in [('Key', (1,-2,3), 1100, 2), ('Fill', (-2,-1,1), 650, 3), ('Rim', (0,2,2), 1000, 2)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = energy * span * span
    data.shape = 'DISK'
    data.size = scale * span
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = center + Vector(offset) * span
    light.rotation_euler = (center - light.location).to_track_quat('-Z','Y').to_euler()
camera_data = bpy.data.cameras.new('ReviewCamera')
camera = bpy.data.objects.new('ReviewCamera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
camera_data.ortho_scale = span * 1.65
camera_data.clip_end = max(1000, span * 20)
side_direction = (0,-1,0.15) if size.x >= size.y else (1,0,0.15)
for filename, direction in [('preview.png', (1.3,-1.8,1.1)), ('side.png', side_direction)]:
    camera.location = center + Vector(direction).normalized() * span * 4
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(folder / filename)
    bpy.ops.render.render(write_still=True)
metrics = {'triangles': triangles, 'materials': len(materials), 'mesh_objects': len(meshes),
           'dimensions_blender_m': list(size), 'nodes': [o.name for o in meshes], 'passed': True}
(folder / 'metrics.json').write_text(json.dumps(metrics, indent=2), encoding='utf-8')
print('MODEL_VALIDATION_PASSED')
