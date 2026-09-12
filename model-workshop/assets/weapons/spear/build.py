import bpy
import math
import os
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))
# In the horizontal source pose the decagonal head socket is the lowest part.
# This height puts it on Z=0 without burying any geometry below the floor.
CENTER_Z = 0.024727


def material(name, color, metallic=0.0, roughness=0.6):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def axis_cylinder(name, radius, length, x, mat, sides=10, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=sides,
        radius=radius,
        depth=length,
        end_fill_type="NGON",
        location=(x, 0.0, CENTER_Z),
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Practical edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def axis_cone(name, radius_left, radius_right, length, x, mat, sides=10):
    # Blender's cone points along local Z. Rotation maps its bottom (-Z) to -X.
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides,
        radius1=radius_left,
        radius2=radius_right,
        depth=length,
        end_fill_type="NGON",
        location=(x, 0.0, CENTER_Z),
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def haft_mesh(wood, wood_dark):
    # A very slight hand-made taper and twelve broad sides keep the haft credible
    # without turning low-poly faceting into decoration.
    rings = [
        (-0.940, 0.0158),
        (-0.700, 0.0170),
        (-0.280, 0.0178),
        (0.180, 0.0174),
        (0.590, 0.0155),
    ]
    sides = 12
    verts = []
    for x, radius in rings:
        for i in range(sides):
            angle = math.tau * i / sides
            verts.append((x, radius * math.cos(angle), CENTER_Z + radius * math.sin(angle)))
    faces = []
    mat_indices = []
    faces.append(tuple(range(sides - 1, -1, -1)))
    mat_indices.append(0)
    for ring in range(len(rings) - 1):
        a = ring * sides
        b = (ring + 1) * sides
        for side in range(sides):
            faces.append((a + side, a + (side + 1) % sides,
                          b + (side + 1) % sides, b + side))
            mat_indices.append(1 if side in (2, 7) else 0)
    last = (len(rings) - 1) * sides
    faces.append(tuple(last + i for i in range(sides)))
    mat_indices.append(0)
    mesh = bpy.data.meshes.new("Haft_AshMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=True)
    mesh.materials.append(wood)
    mesh.materials.append(wood_dark)
    for poly, index in zip(mesh.polygons, mat_indices):
        poly.material_index = index
        poly.use_smooth = False
    mesh.update()
    obj = bpy.data.objects.new("Haft_Ash", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def spearhead_mesh(steel, edge):
    # Closed diamond-section leaf blade. Widths are practical for a thrusting
    # spear; the ridge adds stiffness while the edge converges to near-zero.
    stations = [
        (0.700, 0.018, 0.0060),
        (0.765, 0.034, 0.0075),
        (0.875, 0.051, 0.0090),
        (0.965, 0.039, 0.0075),
        (1.035, 0.018, 0.0045),
    ]
    verts = []
    for x, half_width, half_thickness in stations:
        verts.extend([
            (x, -half_width, CENTER_Z),
            (x, 0.0, CENTER_Z + half_thickness),
            (x, half_width, CENTER_Z),
            (x, 0.0, CENTER_Z - half_thickness),
        ])
    tip = len(verts)
    verts.append((1.075, 0.0, CENTER_Z))
    base = len(verts)
    verts.append((0.700, 0.0, CENTER_Z))
    faces = []
    indices = []
    for station in range(len(stations) - 1):
        a = station * 4
        b = (station + 1) * 4
        for side in range(4):
            faces.append((a + side, b + side, b + (side + 1) % 4))
            indices.append(1 if side in (0, 2) else 0)
            faces.append((a + side, b + (side + 1) % 4, a + (side + 1) % 4))
            indices.append(1 if side in (0, 2) else 0)
    last = (len(stations) - 1) * 4
    for side in range(4):
        faces.append((last + side, tip, last + (side + 1) % 4))
        indices.append(1 if side in (0, 2) else 0)
        faces.append((base, (side + 1) % 4, side))
        indices.append(0)
    mesh = bpy.data.meshes.new("Spearhead_BladeMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=True)
    mesh.materials.append(steel)
    mesh.materials.append(edge)
    for poly, index in zip(mesh.polygons, indices):
        poly.material_index = index
        poly.use_smooth = False
    mesh.update()
    obj = bpy.data.objects.new("Spearhead_Blade", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def rivet(name, x, steel):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=0.0042,
        depth=0.056,
        end_fill_type="NGON",
        location=(x, 0.0, CENTER_Z),
        rotation=(math.pi / 2.0, 0.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(steel)
    return obj


def marker(name, location, parent):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.08
    obj.location = location
    obj.rotation_euler = (0.0, math.pi / 2.0, 0.0)
    obj.parent = parent
    bpy.context.collection.objects.link(obj)
    return obj


def parent_to(obj, root):
    obj.parent = root
    return obj


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for group in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                  bpy.data.cameras, bpy.data.lights):
        for block in list(group):
            if block.users == 0:
                group.remove(block)


def mesh_stats():
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    world_points = []
    for obj in meshes:
        world_points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    mins = Vector((min(p.x for p in world_points), min(p.y for p in world_points),
                   min(p.z for p in world_points)))
    maxs = Vector((max(p.x for p in world_points), max(p.y for p in world_points),
                   max(p.z for p in world_points)))
    dims = maxs - mins
    return triangles, dims, mins, maxs


def render_review(filepath, camera_location, ortho_scale):
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=camera_location)
    camera = bpy.context.object
    camera.name = "REVIEW_CAMERA"
    direction = Vector((0.0, 0.0, CENTER_Z)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale
    scene.camera = camera
    for name, location, energy, size in (
        ("REVIEW_KEY", (-0.3, -2.4, 3.2), 850.0, 4.0),
        ("REVIEW_FILL", (1.8, 2.0, 1.8), 500.0, 3.0),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        direction = Vector((0.0, 0.0, CENTER_Z)) - light.location
        light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.035, 0.045, 0.055)
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.filepath = filepath
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    for name in ("REVIEW_KEY", "REVIEW_FILL"):
        obj = bpy.data.objects.get(name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)


def build():
    clean_scene()
    wood = material("Ash wood", (0.29, 0.17, 0.075), roughness=0.72)
    wood_dark = material("Ash grain shadow", (0.19, 0.095, 0.035), roughness=0.78)
    leather = material("Oiled dark leather", (0.075, 0.035, 0.018), roughness=0.82)
    binding = material("Leather binding", (0.115, 0.052, 0.023), roughness=0.86)
    steel = material("Forged steel", (0.18, 0.205, 0.21), metallic=0.78, roughness=0.46)
    edge = material("Honed steel edge", (0.42, 0.46, 0.46), metallic=0.90, roughness=0.28)

    root = bpy.data.objects.new("WEAPON_SPEAR", None)
    bpy.context.collection.objects.link(root)

    parent_to(haft_mesh(wood, wood_dark), root)
    # The sleeve and socket deliberately overlap the haft: both are functional
    # fitted components. Everything else meets cleanly end-to-end.
    parent_to(axis_cylinder("Grip_Leather_Sleeve", 0.0192, 0.350, -0.410,
                            leather, sides=12, bevel=0.0012), root)
    parent_to(axis_cylinder("Grip_Binding_Rear", 0.0202, 0.008, -0.589,
                            binding, sides=12), root)
    parent_to(axis_cylinder("Grip_Binding_Front", 0.0202, 0.008, -0.231,
                            binding, sides=12), root)
    parent_to(axis_cone("Head_Socket", 0.0190, 0.0260, 0.165, 0.6375,
                        steel, sides=10), root)
    parent_to(rivet("Head_Rivet", 0.605, steel), root)
    parent_to(spearhead_mesh(steel, edge), root)
    parent_to(axis_cone("Butt_Shoe", 0.0110, 0.0215, 0.105, -0.9925,
                        steel, sides=10), root)
    parent_to(axis_cylinder("Butt_Shoe_Rim", 0.0220, 0.008, -0.944,
                            steel, sides=10), root)

    marker("ATTACH_GRIP", (-0.410, 0.0, CENTER_Z), root)
    marker("ATTACH_SPEARHEAD", (0.700, 0.0, CENTER_Z), root)
    marker("ATTACH_TIP", (1.075, 0.0, CENTER_Z), root)
    marker("ATTACH_MUZZLE", (1.075, 0.0, CENTER_Z), root)

    root["catalogue_id"] = "spear"
    root["catalogue_reach_m"] = 2.6
    root["physical_length_m"] = 2.12
    root["forward_axis"] = "+X"
    root["design_note"] = "Practical socketed leaf spear; gameplay reach is not physical length."

    triangles, dims, mins, maxs = mesh_stats()
    print("SPEAR_TRIANGLES", triangles)
    print("SPEAR_DIMENSIONS", tuple(round(v, 6) for v in dims))
    print("SPEAR_BOUNDS_MIN", tuple(round(v, 6) for v in mins))
    print("SPEAR_BOUNDS_MAX", tuple(round(v, 6) for v in maxs))
    print("SPEAR_MATERIALS", len(bpy.data.materials))
    if triangles > 4500:
        raise RuntimeError("Weapon triangle budget exceeded")
    if len(bpy.data.materials) > 12:
        raise RuntimeError("Material budget exceeded")

    source_path = os.path.join(ROOT, "source.blend")
    glb_path = os.path.join(ROOT, "model.glb")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_materials="EXPORT",
    )
    # Dedicated filenames avoid collision with supervisor-owned review evidence.
    render_review(os.path.join(ROOT, "builder-preview.png"), (1.55, -2.65, 1.35), 2.45)
    # Broad-face orthographic evidence: a camera along -Y only shows the leaf
    # blade edge and cannot validate its silhouette.
    render_review(os.path.join(ROOT, "builder-side.png"), (0.0, 0.0, 3.0), 2.35)


if __name__ == "__main__":
    build()
