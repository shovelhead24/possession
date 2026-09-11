import bpy
import math
import os
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))


def mat(name, color, metallic=0.0, roughness=0.55):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m


def cylinder(name, radius, length, x, material, sides=8, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=length,
                                        location=(x, 0.0, 0.16), rotation=(0.0, math.pi / 2.0, 0.0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("small deliberate edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, dims, location, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def spearhead(name, steel, edge):
    # Narrow diamond-section leaf blade. Each station has a left cutting edge,
    # raised top ridge, right cutting edge, and lower ridge. All four profiles
    # converge on ONE vertex, so the thrust end is a point rather than a chisel.
    stations = [
        (0.77, 0.070, 0.038),
        (0.89, 0.125, 0.048),
        (1.08, 0.150, 0.055),
        (1.27, 0.105, 0.043),
        (1.42, 0.042, 0.022),
    ]
    centre_z = 0.16
    verts = []
    for x, half_width, ridge_height in stations:
        verts.extend([
            (x, -half_width, centre_z),
            (x, 0.0, centre_z + ridge_height),
            (x, half_width, centre_z),
            (x, 0.0, centre_z - ridge_height),
        ])
    tip_index = len(verts)
    verts.append((1.50, 0.0, centre_z))
    base_index = len(verts)
    verts.append((0.77, 0.0, centre_z))

    faces = []
    material_indices = []
    for station in range(len(stations) - 1):
        here = station * 4
        nxt = (station + 1) * 4
        for side in range(4):
            # Broad panels remain steel; the left/right cutting facets catch a
            # brighter value without adding decorative geometry.
            faces.append((here + side, nxt + side, nxt + ((side + 1) % 4)))
            material_indices.append(1 if side in (1, 3) else 0)
            faces.append((here + side, nxt + ((side + 1) % 4), here + ((side + 1) % 4)))
            material_indices.append(1 if side in (1, 3) else 0)
    last = (len(stations) - 1) * 4
    for side in range(4):
        faces.append((last + side, tip_index, last + ((side + 1) % 4)))
        material_indices.append(1 if side in (1, 3) else 0)
        faces.append((base_index, (side + 1) % 4, side))
        material_indices.append(0)
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=True)
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(steel)
    obj.data.materials.append(edge)
    for poly, material_index in zip(obj.data.polygons, material_indices):
        poly.material_index = material_index
    return obj


def grip_wrap(name, material):
    # One continuous low-poly leather wrap with an honest helical seam. This
    # reads as a manufactured hand grip instead of a stack of loose washers.
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = 0.008
    curve.bevel_resolution = 0
    curve.resolution_v = 0
    curve.use_fill_caps = True
    points = 41
    turns = 4.25
    spline = curve.splines.new("POLY")
    spline.points.add(points - 1)
    for i, point in enumerate(spline.points):
        t = i / (points - 1)
        angle = turns * math.tau * t
        point.co = (-1.205 + 0.49 * t,
                    0.083 * math.cos(angle),
                    0.16 + 0.083 * math.sin(angle), 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def marker(name, location, rotation=(0.0, 0.0, 0.0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.12
    obj.location = location
    obj.rotation_euler = rotation
    if parent:
        obj.parent = parent
    bpy.context.collection.objects.link(obj)
    return obj


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)

    dark = mat("Shaft dark polymer", (0.012, 0.018, 0.020), metallic=0.05, roughness=0.58)
    body = mat("Shaft blackened steel", (0.035, 0.050, 0.052), metallic=0.62, roughness=0.38)
    grip = mat("Grip charcoal", (0.012, 0.009, 0.007), metallic=0.0, roughness=0.88)
    band = mat("Grip leather wrap", (0.095, 0.045, 0.020), metallic=0.0, roughness=0.82)
    bronze = mat("Utility bronze", (0.30, 0.145, 0.040), metallic=0.70, roughness=0.42)
    steel = mat("Head steel", (0.24, 0.31, 0.32), metallic=0.88, roughness=0.30)
    edge = mat("Head cutting facets", (0.62, 0.70, 0.69), metallic=0.95, roughness=0.20)

    root = bpy.data.objects.new("WEAPON_SPEAR", None)
    bpy.context.collection.objects.link(root)
    # The catalogue reach is 2.6 m; the authored silhouette is proportionally
    # compressed along its forward axis to land on that gameplay scale.
    root.scale.x = 0.830

    shaft = cylinder("Shaft_Main", 0.052, 1.76, -0.22, body, sides=8, bevel=0.006)
    shaft.parent = root
    rear = cylinder("Shaft_Rear_Tang", 0.062, 0.38, -1.29, dark, sides=8, bevel=0.008)
    rear.parent = root
    grip_core = cylinder("Grip_Core", 0.079, 0.50, -0.96, grip, sides=8, bevel=0.008)
    grip_core.parent = root
    wrap = grip_wrap("Grip_Wrap_Helix", band)
    wrap.parent = root
    for name, x in (("Grip_Ferrule_Rear", -1.215), ("Grip_Ferrule_Front", -0.705)):
        ferrule = cylinder(name, 0.088, 0.025, x, bronze, sides=8, bevel=0.003)
        ferrule.parent = root
    butt = cylinder("Butt_Cap", 0.082, 0.105, -1.525, bronze, sides=8, bevel=0.01)
    butt.parent = root
    butt_tip = cylinder("Butt_Pommel", 0.053, 0.06, -1.607, dark, sides=8, bevel=0.008)
    butt_tip.parent = root
    collar = cylinder("Head_Collar", 0.103, 0.16, 0.70, bronze, sides=8, bevel=0.01)
    collar.parent = root
    collar2 = cylinder("Head_Collar_Retainer", 0.116, 0.055, 0.79, dark, sides=8, bevel=0.006)
    collar2.parent = root
    head = spearhead("Spearhead_Assembly", steel, edge)
    head.parent = root
    # Two small side lugs make the head read as a manufactured assembly, not a primitive.
    lug_l = box("Head_Lug_L", (0.14, 0.030, 0.050), (0.84, -0.085, 0.16), bronze, 0.006)
    lug_l.parent = root
    lug_r = box("Head_Lug_R", (0.14, 0.030, 0.050), (0.84, 0.085, 0.16), bronze, 0.006)
    lug_r.parent = root

    marker("ATTACH_GRIP", (-0.96, 0.0, 0.16), rotation=(0.0, math.pi / 2.0, 0.0), parent=root)
    marker("ATTACH_MUZZLE", (1.49, 0.0, 0.16), rotation=(0.0, math.pi / 2.0, 0.0), parent=root)
    marker("ATTACH_SPEARHEAD", (0.76, 0.0, 0.16), rotation=(0.0, math.pi / 2.0, 0.0), parent=root)

    # Store production facts on the root for inspection in Blender/Godot tooling.
    root["catalogue_id"] = "spear"
    root["catalogue_reach_m"] = 2.6
    root["forward_axis"] = "+X"
    root["design_note"] = "Outside-reach thrust weapon; pointed ridged leaf blade and leather-wrapped rear grip."

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "source.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "model.glb"), export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True,
                              export_animations=False, export_materials="EXPORT")


if __name__ == "__main__":
    build()
