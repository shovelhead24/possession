import bpy
import math
import os
from mathutils import Vector


OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def mat(name, color, roughness=0.85, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def mesh_obj(name, verts, faces, materials, face_mats=None):
    me = bpy.data.meshes.new(name + "Mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for m in materials:
        me.materials.append(m)
    if face_mats:
        for p, i in zip(me.polygons, face_mats):
            p.material_index = i
    return ob


def create_stone(materials):
    # Hand-authored, asymmetric ring profile: broad palm body, raised impact ridge,
    # and a flattened resting heel. +Y is the throw/impact direction in Blender.
    rings = [
        (0.000, 0.042, 0.031, 0.000),
        (0.017, 0.071, 0.047, 0.010),
        (0.046, 0.085, 0.056, 0.004),
        (0.073, 0.070, 0.047, -0.002),
        (0.091, 0.039, 0.030, 0.004),
    ]
    n = 8
    verts = []
    phase = [0.00, 0.08, -0.04, 0.06, -0.03, 0.05, -0.06, 0.03]
    for ri, (y, rx, rz, zoff) in enumerate(rings):
        for i in range(n):
            a = 2 * math.pi * i / n
            wobble = 1.0 + phase[i] + (0.025 * math.sin(ri * 2.4 + i))
            x = rx * math.cos(a) * wobble
            z = 0.078 + zoff + rz * math.sin(a) * wobble
            # Bevel the heel into a stable, non-floating contact patch.
            if ri == 0:
                z = 0.018 + 0.010 * (1.0 + math.sin(a))
            verts.append((x, y, z))
    verts += [(0.0, 0.001, 0.078), (0.0, 0.091, 0.078)]
    faces, mids = [], []
    # Heel fan and top impact fan.
    for i in range(n):
        faces.append((len(verts) - 2, i, (i + 1) % n)); mids.append(0 if i % 3 else 1)
        a = 4 * n + i
        b = 4 * n + (i + 1) % n
        faces.append((len(verts) - 1, b, a)); mids.append(1 if i in (1, 2, 3, 4) else 0)
    for r in range(4):
        for i in range(n):
            a = r * n + i
            b = r * n + (i + 1) % n
            c = (r + 1) * n + (i + 1) % n
            d = (r + 1) * n + i
            # Split alternating quads to expose deliberate triangular planes.
            if (r + i) % 2:
                faces.extend([(a, b, d), (b, c, d)])
            else:
                faces.extend([(a, b, c), (a, c, d)])
            mids.extend([0 if (i + r) % 4 else 1, 0 if (i + r) % 3 else 2])
    return mesh_obj("Rock_Core", verts, faces, materials, mids)


def create_impact_face(materials):
    # A shallow, purposeful pale chipped face on the leading edge, not a decal.
    verts = [
        (-0.028, 0.090, 0.066), (0.029, 0.090, 0.067),
        (0.022, 0.095, 0.089), (-0.020, 0.095, 0.091),
        (0.000, 0.099, 0.079),
    ]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    return mesh_obj("Impact_Chipped_Face", verts, faces, [materials[3]], [0, 0, 0, 0])


def create_quarry_scar(materials):
    # Three small raised wedges suggest old quarry strikes and catch light in a render.
    verts = [
        (-0.052, 0.047, 0.108), (-0.027, 0.055, 0.113), (-0.046, 0.064, 0.116), (-0.041, 0.055, 0.128),
        (0.040, 0.030, 0.119), (0.057, 0.038, 0.113), (0.045, 0.047, 0.126), (0.044, 0.038, 0.137),
    ]
    faces = [(0, 1, 2), (0, 2, 3), (4, 5, 6), (4, 6, 7)]
    return mesh_obj("Quarry_Chips", verts, faces, [materials[2]], [0, 0, 0, 0])


def add_marker(name, location, direction=(0, 1, 0), size=0.018):
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=location)
    ob = bpy.context.object
    ob.name = name
    ob.empty_display_size = size
    ob["purpose"] = "attachment marker"
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized())
    return ob


def build():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)

    stone = mat("Stone_Slate", (0.18, 0.21, 0.20), 0.92)
    plane = mat("Stone_Facet", (0.27, 0.30, 0.28), 0.88)
    chip = mat("Fresh_Chips", (0.46, 0.43, 0.34), 0.82)
    impact = mat("Impact_Face", (0.56, 0.52, 0.42), 0.78)
    mats = [stone, plane, chip, impact]
    core = create_stone(mats)
    create_impact_face(mats)
    create_quarry_scar(mats)
    core["asset_role"] = "thrown rock core"
    core["catalogue_mass_g"] = 400.0
    core["forward_axis"] = "+Y"

    grip = add_marker("grip_marker", (0.0, 0.032, 0.039), (0, 1, 0), 0.014)
    grip["attachment"] = "palm/release reference"
    release = add_marker("release_marker", (0.0, 0.092, 0.079), (0, 1, 0), 0.014)
    release["attachment"] = "throw release point"
    muzzle = add_marker("muzzle_marker", (0.0, 0.099, 0.079), (0, 1, 0), 0.012)
    muzzle["attachment"] = "impact/forward reference for thrown weapon"

    # Stable origin at world zero; stone rests on z=0 and remains easy to place in hand.
    bpy.context.scene["asset_name"] = "weapons-rock"
    bpy.context.scene["asset_scale_m"] = "0.17 x 0.10 x 0.14 m"
    bpy.context.scene["blender_convention"] = "Z-up, +Y forward"
    bpy.context.scene["godot_convention"] = "Y-up, +Z forward after glTF import"
    bpy.context.scene["triangle_budget"] = 4500
    bpy.context.scene["material_budget"] = 12

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "source.blend"))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT_DIR, "model.glb"),
        export_format='GLB',
        export_yup=True,
        export_apply=True,
        export_animations=False,
        export_materials='EXPORT',
        use_selection=True,
    )


if __name__ == "__main__":
    build()
