import bpy
import bmesh
import json
import math
import os
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))
CZ = 0.014


def material(name, color, metallic=0.0, roughness=0.55):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    # Keep viewport and exported glTF values in lockstep.  The earlier revision
    # had plausible shader names but failed visually because all four finishes
    # collapsed to nearly the same pale value in the review render.
    mat.diffuse_color = (*color, 1.0)
    return mat


def prism(name, points, z_min, z_max, mat, bevel=0.0):
    """Make a closed prism from a deliberately authored XY outline."""
    count = len(points)
    verts = [(x, y, z_min) for x, y in points]
    verts += [(x, y, z_max) for x, y in points]
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
        mod = obj.modifiers.new("subtle manufactured edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, dimensions, location, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("subtle manufactured edge break", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def cylinder_z(name, radius, depth, location, mat, sides=10):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=sides, radius=radius, depth=depth, location=location
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def ring(name, center, outer_radius, inner_radius, z_min, z_max, mat, segments=12):
    """Low-poly extruded annulus with a real opening."""
    cx, cy = center
    verts = []
    for z in (z_min, z_max):
        for radius in (outer_radius, inner_radius):
            for i in range(segments):
                angle = math.tau * i / segments
                verts.append((cx + math.cos(angle) * radius,
                              cy + math.sin(angle) * radius, z))
    ob = 0
    ib = segments
    ot = segments * 2
    it = segments * 3
    faces = []
    for i in range(segments):
        j = (i + 1) % segments
        faces.extend([
            (ob + i, ob + j, ot + j, ot + i),
            (ib + j, ib + i, it + i, it + j),
            (ot + i, ot + j, it + j, it + i),
            (ob + j, ob + i, ib + i, ib + j),
        ])
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=True)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def tapered_strip_to_tip(name, inner_points, outer_points, z_center,
                         inner_half_thickness, outer_half_thickness, mat):
    """Closed planar wedge between two XY rails that meet at one thin tip."""
    if len(inner_points) != len(outer_points) or len(inner_points) < 2:
        raise ValueError("Tapered strip rails must have the same useful length")
    if inner_points[-1] != outer_points[-1]:
        raise ValueError("Tapered strip rails must meet at the final tip")

    verts = []
    last = len(inner_points) - 1
    for i in range(last):
        ix, iy = inner_points[i]
        ox, oy = outer_points[i]
        verts.extend([
            (ix, iy, z_center + inner_half_thickness),
            (ix, iy, z_center - inner_half_thickness),
            (ox, oy, z_center + outer_half_thickness),
            (ox, oy, z_center - outer_half_thickness),
        ])
    tx, ty = inner_points[-1]
    tip_top = len(verts)
    tip_bottom = tip_top + 1
    verts.extend([
        (tx, ty, z_center + outer_half_thickness),
        (tx, ty, z_center - outer_half_thickness),
    ])

    faces = [(0, 2, 3, 1)]
    for i in range(last - 1):
        a = i * 4
        b = (i + 1) * 4
        faces.extend([
            (a, b, b + 2, a + 2),
            (a + 3, b + 3, b + 1, a + 1),
            (a + 1, b + 1, b, a),
            (a + 2, b + 2, b + 3, a + 3),
        ])
    a = (last - 1) * 4
    faces.extend([
        (a, tip_top, a + 2),
        (a + 3, tip_bottom, a + 1),
        (a + 1, tip_bottom, tip_top, a),
        (a + 2, tip_top, tip_bottom, a + 3),
    ])

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=True)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def marker(name, location, parent, size=0.025):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = size
    obj.location = location
    obj.rotation_euler = (0.0, math.pi / 2.0, 0.0)
    obj.parent = parent
    bpy.context.collection.objects.link(obj)
    return obj


def recalc_normals():
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)


def look_at(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_evidence(asset_objects):
    world = bpy.context.scene.world
    # Neutral charcoal surroundings keep clean-import evidence readable without
    # tinting the material comparison toward a stylized presentation.
    world.color = (0.120, 0.120, 0.120)
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.120, 0.120, 0.120, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.40

    bpy.ops.object.light_add(type="AREA", location=(0.05, -0.36, 0.42))
    key = bpy.context.object
    key.name = "RENDER_Key"
    key.data.energy = 8.0
    key.data.shape = "RECTANGLE"
    key.data.size = 0.45
    key.data.color = (1.0, 1.0, 1.0)
    look_at(key, (0.07, 0.0, CZ))

    bpy.ops.object.light_add(type="AREA", location=(0.02, 0.30, 0.23))
    fill = bpy.context.object
    fill.name = "RENDER_Fill"
    fill.data.energy = 1.5
    fill.data.size = 0.35
    fill.data.color = (1.0, 1.0, 1.0)
    look_at(fill, (0.07, 0.0, CZ))

    bpy.ops.object.camera_add(location=(0.12, -0.43, 0.30))
    camera = bpy.context.object
    camera.name = "RENDER_Camera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 0.52
    look_at(camera, (0.07, 0.0, CZ))
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = os.path.join(ROOT, "preview.png")
    bpy.ops.render.render(write_still=True)

    camera.location = (0.07, 0.0, 0.62)
    camera.data.ortho_scale = 0.50
    look_at(camera, (0.07, 0.0, CZ))
    scene.render.filepath = os.path.join(ROOT, "side.png")
    bpy.ops.render.render(write_still=True)

    for obj in (camera, key, fill):
        bpy.data.objects.remove(obj, do_unlink=True)


def validate_export_and_render(expected_triangles, expected_materials):
    """Re-import the GLB into a clean scene and render that exported result."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    # Remove orphaned source datablocks as well as their objects so this is a
    # genuinely clean import and exported material/node names are tested intact.
    for mesh_block in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh_block)
    for material_block in list(bpy.data.materials):
        bpy.data.materials.remove(material_block)

    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "model.glb"))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    imported_triangles = 0
    imported_degenerate = 0
    imported_non_manifold = 0
    imported_missing_material_assignments = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        imported_triangles += len(obj.data.loop_triangles)
        imported_degenerate += sum(
            1 for poly in obj.data.polygons if poly.area < 1e-10
        )
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        # glTF preserves flat shading by splitting coincident vertices. Weld a
        # temporary audit copy so topology is assessed geometrically without
        # changing the imported mesh or its authored normals.
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
        imported_non_manifold += sum(1 for edge in bm.edges if not edge.is_manifold)
        bm.free()
        imported_missing_material_assignments += sum(
            1 for poly in obj.data.polygons
            if not obj.material_slots or poly.material_index >= len(obj.material_slots)
        )
    imported_materials = sorted({
        slot.material.name for obj in meshes for slot in obj.material_slots
        if slot.material
    })
    required_nodes = {"WEAPON_BLADE", "ATTACH_GRIP", "ATTACH_BLADE", "ATTACH_TIP"}
    missing_nodes = sorted(required_nodes.difference(bpy.context.scene.objects.keys()))

    corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    xs = [corner.x for corner in corners]
    ys = [corner.y for corner in corners]
    zs = [corner.z for corner in corners]
    dimensions = [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)]

    if imported_triangles != expected_triangles:
        raise RuntimeError("GLB triangle mismatch: %d != %d" %
                           (imported_triangles, expected_triangles))
    if len(imported_materials) != expected_materials:
        raise RuntimeError("GLB material mismatch: %d != %d" %
                           (len(imported_materials), expected_materials))
    if imported_degenerate:
        raise RuntimeError("GLB degenerate polygon count: %d" % imported_degenerate)
    if imported_non_manifold:
        raise RuntimeError("GLB non-manifold edge count: %d" % imported_non_manifold)
    if imported_missing_material_assignments:
        raise RuntimeError("GLB polygons missing materials: %d" %
                           imported_missing_material_assignments)
    if missing_nodes:
        raise RuntimeError("GLB missing required nodes: %s" % ", ".join(missing_nodes))

    metrics = {
        "triangles": imported_triangles,
        "materials": len(imported_materials),
        "material_names": imported_materials,
        "mesh_objects": len(meshes),
        "dimensions_glb_m": dimensions,
        "nodes": sorted(obj.name for obj in meshes),
        "required_attachment_nodes_present": True,
        "degenerate_polygons": imported_degenerate,
        "non_manifold_edges": imported_non_manifold,
        "polygons_missing_materials": imported_missing_material_assignments,
        "passed": True,
    }
    with open(os.path.join(ROOT, "metrics.json"), "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)
        handle.write("\n")

    for mat_name in imported_materials:
        mat = bpy.data.materials[mat_name]
        bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.use_nodes else None
        if bsdf:
            rgba = tuple(round(v, 4) for v in bsdf.inputs["Base Color"].default_value)
            print("GLB_MATERIAL %s base=%s metallic=%.3f roughness=%.3f" %
                  (mat_name, rgba, bsdf.inputs["Metallic"].default_value,
                   bsdf.inputs["Roughness"].default_value))

    print("GLB_VALIDATION triangles=%d materials=%d meshes=%d degenerates=%d non_manifold=%d missing_materials=%d" %
          (imported_triangles, len(imported_materials), len(meshes), imported_degenerate,
           imported_non_manifold, imported_missing_material_assignments))
    print("GLB_DIMENSIONS_M %.6f x %.6f x %.6f" % tuple(dimensions))
    render_evidence(meshes)


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes, bpy.data.curves, bpy.data.materials,
        bpy.data.cameras, bpy.data.lights
    ):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)

    # Restrained but deliberately distinct PBR values: matte rubber, blackened
    # fittings, satin blade steel, and a brighter ground edge.
    blade_steel = material("Satin carbon steel", (0.120, 0.155, 0.175), 0.78, 0.40)
    edge_steel = material("Ground cutting edge", (0.360, 0.410, 0.430), 0.88, 0.23)
    oxide_steel = material("Black oxide fittings", (0.016, 0.021, 0.024), 0.55, 0.66)
    grip_rubber = material("Charcoal rubber scales", (0.010, 0.014, 0.012), 0.0, 0.91)

    root = bpy.data.objects.new("WEAPON_BLADE", None)
    bpy.context.collection.objects.link(root)

    # Full tang is visible around the hand-scale grip. The small annular pommel
    # is joined into the tang envelope; it is not a protruding external loop.
    tang_points = [
        (-0.124, -0.014), (-0.116, -0.017), (-0.030, -0.017),
        (0.007, -0.015), (0.009, 0.015), (-0.030, 0.017),
        (-0.116, 0.017), (-0.124, 0.014),
    ]
    tang = prism("Full_Tang", tang_points, CZ - 0.003, CZ + 0.003, oxide_steel)
    tang.parent = root
    lanyard = ring("Integrated_Lanyard_Eye", (-0.128, 0.0), 0.0100, 0.0035,
                   CZ - 0.003, CZ + 0.003, oxide_steel, segments=12)
    lanyard.parent = root

    scale_points = [
        (-0.121, -0.012), (-0.113, -0.016), (-0.030, -0.018),
        (0.004, -0.015), (0.004, 0.015), (-0.030, 0.018),
        (-0.113, 0.016), (-0.121, 0.012),
    ]
    lower_scale = prism("Grip_Scale_Lower", scale_points, 0.001, CZ - 0.003,
                        grip_rubber, bevel=0.0015)
    upper_scale = prism("Grip_Scale_Upper", scale_points, CZ + 0.003, 0.027,
                        grip_rubber, bevel=0.0015)
    lower_scale.parent = root
    upper_scale.parent = root

    for index, x in enumerate((-0.090, -0.038)):
        pin = cylinder_z("Grip_Pin_%02d" % (index + 1), 0.0033, 0.027,
                         (x, 0.0, CZ), edge_steel, sides=10)
        pin.parent = root

    # A compact asymmetrical guard gives the index finger a stop without a
    # swollen crosspiece or decorative quillon.
    guard_points = [
        (-0.003, -0.026), (0.007, -0.025), (0.010, -0.018),
        (0.008, -0.014), (0.007, 0.015), (0.003, 0.022),
        (-0.004, 0.021), (-0.006, 0.014), (-0.006, -0.018),
    ]
    guard = prism("Guard_Black_Oxide", guard_points, 0.004, 0.024,
                  oxide_steel, bevel=0.001)
    guard.parent = root

    # Three adjoining, closed sections form the blade without a hidden full-size
    # slab: a full-stock spine, a broad planar primary grind, and a thin final
    # cutting bevel. Their changing Z thickness makes the wedge construction
    # readable from oblique views while retaining the restrained drop point.
    blade_points = [
        (0.004, 0.018), (0.175, 0.018), (0.230, 0.010), (0.275, 0.000),
        (0.229, -0.001), (0.150, 0.005), (0.028, 0.005),
        (0.008, 0.008),
    ]
    blade = prism("Blade_Spine", blade_points, CZ - 0.003, CZ + 0.003,
                  blade_steel, bevel=0.0006)
    blade.parent = root

    ridge_rail = [
        (0.008, 0.008), (0.028, 0.005), (0.150, 0.005),
        (0.229, -0.001), (0.275, 0.000),
    ]
    grind_rail = [
        (0.008, -0.014), (0.028, -0.017), (0.150, -0.016),
        (0.229, -0.010), (0.275, 0.000),
    ]
    primary_grind = tapered_strip_to_tip(
        "Blade_Primary_Grind", ridge_rail, grind_rail, CZ,
        0.0030, 0.00135, blade_steel,
    )
    primary_grind.parent = root

    edge_rail = [
        (0.012, -0.020), (0.032, -0.025), (0.155, -0.026),
        (0.231, -0.015), (0.275, 0.000),
    ]
    cutting_edge = tapered_strip_to_tip(
        "Blade_Cutting_Bevel", grind_rail, edge_rail, CZ,
        0.00135, 0.00025, edge_steel,
    )
    cutting_edge.parent = root

    # A small exposed ricasso communicates how the blade seats into the full
    # tang while keeping the guard and scales useful as separate pieces.
    ricasso = box("Blade_Ricasso", (0.014, 0.034, 0.006),
                  (0.007, 0.000, CZ), blade_steel, bevel=0.0005)
    ricasso.parent = root

    marker("ATTACH_GRIP", (-0.058, 0.0, CZ), root)
    marker("ATTACH_BLADE", (0.008, 0.0, CZ), root)
    marker("ATTACH_TIP", (0.275, 0.0, CZ), root, size=0.018)

    root["catalogue_id"] = "blade"
    root["catalogue_reach_m"] = 1.3
    root["physical_model_note"] = "Gameplay reach is not physical mesh length."
    root["forward_axis"] = "+X"
    root["design_note"] = "Human-scale full-tang military utility/fighting knife."

    recalc_normals()

    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    tri_count = 0
    degenerate = 0
    non_manifold = 0
    missing_material_assignments = 0
    negative_scale_objects = 0
    for obj in mesh_objects:
        obj.data.calc_loop_triangles()
        tri_count += len(obj.data.loop_triangles)
        degenerate += sum(1 for poly in obj.data.polygons if poly.area < 1e-10)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        non_manifold += sum(1 for edge in bm.edges if not edge.is_manifold)
        bm.free()
        missing_material_assignments += sum(
            1 for poly in obj.data.polygons
            if not obj.material_slots or poly.material_index >= len(obj.material_slots)
        )
        negative_scale_objects += int(any(component < 0.0 for component in obj.scale))
    material_count = len({slot.material.name for obj in mesh_objects
                          for slot in obj.material_slots if slot.material})
    if tri_count > 4500:
        raise RuntimeError("Triangle budget exceeded: %d" % tri_count)
    if material_count > 12:
        raise RuntimeError("Material budget exceeded: %d" % material_count)
    if degenerate:
        raise RuntimeError("Degenerate polygon count: %d" % degenerate)
    if non_manifold:
        raise RuntimeError("Non-manifold edge count: %d" % non_manifold)
    if missing_material_assignments:
        raise RuntimeError("Polygons missing materials: %d" % missing_material_assignments)
    if negative_scale_objects:
        raise RuntimeError("Negative-scale mesh objects: %d" % negative_scale_objects)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "source.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "model.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_yup=True,
        export_materials="EXPORT",
    )

    world_corners = [obj.matrix_world @ Vector(corner)
                     for obj in mesh_objects for corner in obj.bound_box]
    xs = [corner.x for corner in world_corners]
    ys = [corner.y for corner in world_corners]
    zs = [corner.z for corner in world_corners]
    print("VALIDATION triangles=%d materials=%d meshes=%d degenerates=%d non_manifold=%d missing_materials=%d negative_scales=%d" %
          (tri_count, material_count, len(mesh_objects), degenerate, non_manifold,
           missing_material_assignments, negative_scale_objects))
    print("VALIDATION dimensions_m=%.6f x %.6f x %.6f" %
          (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))

    validate_export_and_render(tri_count, material_count)


if __name__ == "__main__":
    build()
