import bpy
import math
import os


ROOT = os.path.dirname(os.path.abspath(__file__))


def material(name, color, metallic=0.0, roughness=0.55):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m


def box(name, dims, location, mat, bevel=0.0, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    if rotation:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("purposeful edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def cylinder(name, radius, depth, location, mat, sides=8, rotation=(0.0, math.pi / 2.0, 0.0), bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("small edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def blade_mesh(name, steel, edge):
    # Compact broad single-edged cleaver. The changing five-sided sections create
    # the fuller/spine and edge facets without separate, buried decoration.
    stations = [
        (0.17, 0.080, 0.042, 0.012),
        (0.25, 0.165, 0.072, 0.025),
        (0.46, 0.205, 0.090, 0.034),
        (0.69, 0.188, 0.082, 0.031),
        (0.86, 0.126, 0.060, 0.023),
        (0.95, 0.050, 0.024, 0.010),
    ]
    cz = 0.18
    verts = []
    # bottom bevel, cutting edge, mid-flat, spine ridge, back bevel
    for x, half_w, ridge, bevel_z in stations:
        verts.extend([
            (x, -half_w, cz - bevel_z),
            (x, -half_w * 0.88, cz),
            (x, 0.0, cz + ridge),
            (x, half_w * 0.88, cz),
            (x, half_w, cz - bevel_z),
        ])
    tip = len(verts)
    verts.append((1.00, 0.0, cz - 0.002))
    base = len(verts)
    verts.append((0.17, 0.0, cz))
    faces, mids = [], []
    for i in range(len(stations) - 1):
        a, b = i * 5, (i + 1) * 5
        for side in range(5):
            nxt_side = (side + 1) % 5
            faces.append((a + side, b + side, b + nxt_side))
            faces.append((a + side, b + nxt_side, a + nxt_side))
            mids.extend([1 if side in (0, 4) else 0, 1 if side in (0, 4) else 0])
    last = (len(stations) - 1) * 5
    for side in range(5):
        nxt_side = (side + 1) % 5
        faces.append((last + side, tip, last + nxt_side))
        mids.append(1 if side in (0, 4) else 0)
        faces.append((base, (side + 1) % 5, side))
        mids.append(0)
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=True)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(steel)
    obj.data.materials.append(edge)
    for poly, idx in zip(obj.data.polygons, mids):
        poly.material_index = idx
        poly.use_smooth = False
    return obj


def extruded_outline(name, points, z_min, z_max, mat, bevel=0.0):
    """Closed low-poly prism from a deliberate top-view silhouette."""
    count = len(points)
    verts = [(x, y, z_min) for x, y in points] + [(x, y, z_max) for x, y in points]
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=True)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("purposeful edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def marker(name, location, rotation=(0.0, 0.0, 0.0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.10
    obj.location = location
    obj.rotation_euler = rotation
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

    dark = material("Frame black polymer", (0.012, 0.018, 0.019), 0.10, 0.55)
    grip = material("Grip charcoal rubber", (0.018, 0.012, 0.010), 0.0, 0.88)
    bronze = material("Utility bronze", (0.32, 0.15, 0.035), 0.72, 0.40)
    steel = material("Blade dark steel", (0.20, 0.25, 0.25), 0.88, 0.32)
    edge = material("Blade edge facets", (0.58, 0.67, 0.65), 0.94, 0.22)

    root = bpy.data.objects.new("WEAPON_BLADE", None)
    bpy.context.collection.objects.link(root)

    tang = cylinder("Tang_Frame", 0.052, 0.16, (0.10, 0.0, 0.18), dark, sides=8, bevel=0.005)
    tang.parent = root
    grip_core = cylinder("Grip_Core", 0.074, 0.30, (-0.07, 0.0, 0.18), grip, sides=8, bevel=0.008)
    grip_core.parent = root
    # Three broad grip ribs remain readable at gameplay distance.
    for i, x in enumerate((-0.16, -0.07, 0.02)):
        rib = cylinder("Grip_Rib_%02d" % i, 0.081, 0.020, (x, 0.0, 0.18), bronze, sides=8, bevel=0.003)
        rib.parent = root
    pommel = cylinder("Pommel_Cap", 0.086, 0.065, (-0.245, 0.0, 0.18), bronze, sides=8, bevel=0.008)
    pommel.parent = root
    pommel_tip = cylinder("Pommel_Tip", 0.052, 0.020, (-0.2875, 0.0, 0.18), dark, sides=8, bevel=0.004)
    pommel_tip.parent = root

    # A single swept knuckle guard replaces the old stack of blocky lugs. The
    # concave waist and forward shoulders visually lock it into the blade collar.
    guard_points = [
        (0.205, -0.090), (0.145, -0.135), (0.055, -0.225),
        (-0.005, -0.205), (0.030, -0.105), (0.085, 0.0),
        (0.030, 0.105), (-0.005, 0.205), (0.055, 0.225),
        (0.145, 0.135), (0.205, 0.090),
    ]
    guard = extruded_outline("Guard_Swept_Crosspiece", guard_points, 0.125, 0.235, bronze, bevel=0.012)
    guard.parent = root
    guard_core = box("Guard_Central_Block", (0.13, 0.19, 0.155), (0.135, 0.0, 0.18), dark, bevel=0.010)
    guard_core.parent = root

    blade = blade_mesh("Blade_Assembly", steel, edge)
    blade.parent = root
    collar = cylinder("Blade_Collar", 0.098, 0.105, (0.17, 0.0, 0.18), bronze, sides=8, bevel=0.008)
    collar.parent = root
    # Short tapered reinforcement terminates at the broad blade belly; it does
    # not chase the point and needs no decorative tip tab.
    spine_points = [(0.205, -0.025), (0.205, 0.025), (0.64, 0.015), (0.70, 0.0), (0.64, -0.015)]
    spine = extruded_outline("Blade_Spine_Rail", spine_points, 0.246, 0.273, dark, bevel=0.004)
    spine.parent = root

    marker("ATTACH_GRIP", (-0.07, 0.0, 0.18), rotation=(0.0, math.pi / 2.0, 0.0), parent=root)
    marker("ATTACH_MUZZLE", (1.00, 0.0, 0.18), rotation=(0.0, math.pi / 2.0, 0.0), parent=root)
    marker("ATTACH_BLADE", (0.17, 0.0, 0.18), rotation=(0.0, math.pi / 2.0, 0.0), parent=root)

    root["catalogue_id"] = "blade"
    root["catalogue_reach_m"] = 1.3
    root["forward_axis"] = "+X"
    root["design_note"] = "One-handed close-range military cleaver: broad single-edge blade, short tapered reinforcement, and swept bronze hand guard."

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "source.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "model.glb"), export_format="GLB",
                              use_selection=True, export_apply=True, export_animations=False,
                              export_yup=True, export_materials="EXPORT")


if __name__ == "__main__":
    build()
