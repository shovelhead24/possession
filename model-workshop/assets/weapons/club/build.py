import bpy
import bmesh
import json
import math
import os
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))


def material(name, colour, metallic=0.0, roughness=0.6):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*colour, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


def finish_mesh(obj, mat, bevel=0.0):
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.material_index = 0
        polygon.use_smooth = False
    if bevel:
        modifier = obj.modifiers.new("small manufactured edge break", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
    return obj


def cylinder(name, radius, depth, location, mat, vertices=8, scale=(1.0, 1.0, 1.0), rotation=(0.0, 0.0, 0.0), bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, bevel)


def box(name, location, dimensions, mat, bevel=0.0, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, bevel)


def ring_form(name, rings, sides, mat):
    # Each ring is (z, x_radius, y_radius, x_offset). Closed, convex sections avoid hidden cores.
    vertices = []
    faces = []
    for z, rx, ry, x_offset in rings:
        for index in range(sides):
            angle = 2.0 * math.pi * index / sides
            vertices.append((x_offset + rx * math.cos(angle), ry * math.sin(angle), z))
    for ring in range(len(rings) - 1):
        for index in range(sides):
            a = ring * sides + index
            b = ring * sides + (index + 1) % sides
            c = (ring + 1) * sides + (index + 1) % sides
            d = (ring + 1) * sides + index
            faces.append((a, b, c, d))
    faces.append(tuple(range(sides - 1, -1, -1)))
    start = (len(rings) - 1) * sides
    faces.append(tuple(start + index for index in range(sides)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=True)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish_mesh(obj, mat)


def rail_form(name, sections, half_depth, mat):
    # Tapered closed rectangular sections create one unmistakable continuous contact rail.
    vertices = []
    faces = []
    for z, inner_x, outer_x in sections:
        vertices.extend(((inner_x, -half_depth, z), (outer_x, -half_depth, z),
                         (outer_x, half_depth, z), (inner_x, half_depth, z)))
    for section in range(len(sections) - 1):
        a = section * 4
        b = (section + 1) * 4
        faces.extend(((a, a + 1, b + 1, b), (a + 1, a + 2, b + 2, b + 1),
                      (a + 2, a + 3, b + 3, b + 2), (a + 3, a, b, b + 3)))
    faces.extend(((3, 2, 1, 0), tuple(range((len(sections) - 1) * 4, len(sections) * 4))))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=True)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish_mesh(obj, mat, 0.004)


def marker(name, location, purpose, size=0.055, rotation=(0.0, 0.0, 0.0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = size
    obj["purpose"] = purpose
    return obj


def evaluated_metrics(asset_objects, material_count, markers):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    points = []
    non_manifold_edges = 0
    degenerate_faces = 0
    for obj in asset_objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        points.extend(obj.matrix_world @ vertex.co for vertex in mesh.vertices)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        non_manifold_edges += sum(1 for edge in bm.edges if not edge.is_manifold)
        degenerate_faces += sum(1 for face in bm.faces if face.calc_area() < 1.0e-9)
        bm.free()
        evaluated.to_mesh_clear()
    minima = [min(point[index] for point in points) for index in range(3)]
    maxima = [max(point[index] for point in points) for index in range(3)]
    dimensions = [maxima[index] - minima[index] for index in range(3)]
    return {
        "asset": "weapons-club",
        "triangles": triangles,
        "materials": material_count,
        "dimensions_m": [round(value, 3) for value in dimensions],
        "bounds_min_m": [round(value, 3) for value in minima],
        "bounds_max_m": [round(value, 3) for value in maxima],
        "physical_overall_length_m": round(dimensions[2], 3),
        "catalogue_attack_reach_m": 1.5,
        "non_manifold_edges": non_manifold_edges,
        "degenerate_faces": degenerate_faces,
        "mesh_parts": len([obj for obj in asset_objects if obj.type == "MESH"]),
        "markers": {
            obj.name: {
                "location_m": [round(value, 4) for value in obj.location],
                "rotation_euler_rad": [round(value, 4) for value in obj.rotation_euler],
                "purpose": obj["purpose"],
            }
            for obj in markers
        },
    }


def validate_export(filepath, expected_markers):
    # Re-import the actual GLB into a clean scene. This catches missing marker nodes,
    # export failures, and selection/parenting mistakes rather than trusting source data.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=filepath)
    imported = {obj.name: obj for obj in bpy.context.scene.objects}
    missing = [name for name in expected_markers if name not in imported]
    if missing:
        raise RuntimeError(f"Exported GLB is missing markers: {missing}")
    mesh_nodes = [obj for obj in imported.values() if obj.type == "MESH"]
    if not mesh_nodes:
        raise RuntimeError("Exported GLB contains no mesh nodes")
    return {
        "verified": True,
        "mesh_nodes": len(mesh_nodes),
        "marker_nodes": {
            name: {
                "type": imported[name].type,
                "location_m": [round(value, 4) for value in imported[name].matrix_world.translation],
                "local_z_world": [round(value, 4) for value in (imported[name].matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized()],
            }
            for name in expected_markers
        },
    }


def render_review(asset_objects, path, camera_location, lens):
    bpy.ops.object.camera_add(location=camera_location)
    camera = bpy.context.object
    camera.name = "REVIEW_CAMERA"
    direction = Vector((0.0, 0.0, 0.65)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = lens
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(2.4, -3.0, 3.1))
    key = bpy.context.object
    key.name = "REVIEW_KEY"
    key.data.energy = 850
    key.data.shape = "DISK"
    key.data.size = 2.7
    bpy.ops.object.light_add(type="AREA", location=(-2.3, -0.8, 1.7))
    fill = bpy.context.object
    fill.name = "REVIEW_FILL"
    fill.data.energy = 500
    fill.data.size = 2.2
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0.0, 0.0, -0.003))
    ground = bpy.context.object
    ground.name = "REVIEW_GROUND"
    ground.data.materials.append(material("Review ground", (0.105, 0.12, 0.13), 0.0, 0.86))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 700
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    # Blender's image writer is more reliable with normalized forward-slash paths on Windows.
    scene.render.filepath = os.path.abspath(path).replace("\\", "/")
    scene.render.film_transparent = False
    scene.world.color = (0.035, 0.045, 0.055)
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)
    for obj in (camera, key, fill, ground):
        bpy.data.objects.remove(obj, do_unlink=True)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    mats = {
        "rubber": material("M_Rubber_Dark", (0.018, 0.022, 0.020), 0.0, 0.92),
        "steel": material("M_Steel_Blackened", (0.055, 0.065, 0.064), 0.82, 0.38),
        "paint": material("M_Paint_Worn_Oxide", (0.19, 0.105, 0.055), 0.08, 0.72),
        "impact": material("M_Steel_Impact_Bright", (0.44, 0.47, 0.46), 0.88, 0.25),
        "fastener": material("M_Steel_Fasteners", (0.12, 0.135, 0.13), 0.84, 0.34),
    }

    parts = []
    # Human-scaled two-hand grip: two uninterrupted sleeves separated by one tactile index band.
    parts.append(cylinder("Pommel plate", 0.043, 0.025, (0.0, 0.0, 0.0125), mats["impact"], 8, bevel=0.002))
    parts.append(cylinder("Pommel body", 0.046, 0.050, (0.0, 0.0, 0.050), mats["steel"], 8, bevel=0.003))
    parts.append(cylinder("Rear hand grip", 0.033, 0.220, (0.0, 0.0, 0.185), mats["rubber"], 10, scale=(1.04, 0.96, 1.0), bevel=0.002))
    for index, z in enumerate((0.095, 0.165, 0.235, 0.305)):
        parts.append(cylinder(f"Rear grip wrap {index + 1}", 0.035, 0.008, (0.0, 0.0, z), mats["rubber"], 10, bevel=0.001))
    parts.append(cylinder("Grip separator", 0.036, 0.025, (0.0, 0.0, 0.323), mats["steel"], 8, bevel=0.002))
    parts.append(cylinder("Lead hand grip", 0.033, 0.215, (0.0, 0.0, 0.445), mats["rubber"], 10, scale=(1.04, 0.96, 1.0), bevel=0.002))
    for index, z in enumerate((0.365, 0.430, 0.495, 0.550)):
        parts.append(cylinder(f"Lead grip wrap {index + 1}", 0.035, 0.008, (0.0, 0.0, z), mats["rubber"], 10, bevel=0.001))
    parts.append(cylinder("Grip front ferrule", 0.041, 0.040, (0.0, 0.0, 0.580), mats["steel"], 8, bevel=0.003))

    # The full-diameter steel haft visibly enters the head, while twin external spine
    # plates continue that load path almost to the crown.
    parts.append(cylinder("Full tang steel haft", 0.030, 0.365, (0.0, 0.0, 0.7425), mats["steel"], 8, bevel=0.002))
    parts.append(cylinder("Reinforced head socket", 0.047, 0.155, (0.0, 0.0, 0.7475), mats["fastener"], 8, scale=(1.10, 0.96, 1.0), bevel=0.004))

    # Compact forged mass: shorter and thicker than the rejected housing-like slab.
    parts.append(ring_form("Weighted steel shell", [
        (0.715, 0.042, 0.042, -0.002),
        (0.755, 0.060, 0.052, -0.004),
        (0.825, 0.073, 0.058, -0.006),
        (1.055, 0.077, 0.060, -0.007),
        (1.125, 0.068, 0.055, -0.005),
        (1.165, 0.047, 0.045, -0.002),
    ], 10, mats["paint"]))

    parts.append(box("Front structural spine", (-0.012, -0.061, 0.950), (0.070, 0.010, 0.390), mats["steel"], 0.003))
    parts.append(box("Rear structural spine", (-0.012, 0.061, 0.950), (0.070, 0.010, 0.390), mats["steel"], 0.003))
    parts.append(box("Socket flare front", (-0.004, -0.058, 0.765), (0.092, 0.012, 0.090), mats["fastener"], 0.003))
    parts.append(box("Socket flare rear", (-0.004, 0.058, 0.765), (0.092, 0.012, 0.090), mats["fastener"], 0.003))

    # One continuous blunt wear bar is the dominant +X striking silhouette.
    parts.append(rail_form("Continuous impact rail", [
        (0.770, 0.052, 0.093),
        (0.815, 0.067, 0.112),
        (1.075, 0.070, 0.118),
        (1.130, 0.060, 0.108),
        (1.160, 0.043, 0.088),
    ], 0.041, mats["impact"]))
    for index, z in enumerate((0.835, 1.085)):
        parts.append(cylinder(f"Rail retaining bolt {index + 1}", 0.010, 0.140, (0.073, 0.0, z), mats["fastener"], 8,
                              rotation=(math.pi / 2.0, 0.0, 0.0), bevel=0.001))
    parts.append(cylinder("Forged crown cap", 0.050, 0.025, (-0.002, 0.0, 1.1775), mats["steel"], 8,
                          scale=(1.18, 1.02, 1.0), bevel=0.003))

    root = bpy.data.objects.new("CLUB_ROOT", None)
    bpy.context.collection.objects.link(root)
    root.empty_display_type = "CUBE"
    root.empty_display_size = 0.07
    root["asset"] = "weapons-club"
    root["source_axes"] = "+Z length, +X primary strike"
    root["catalogue_attack_reach_m"] = 1.5
    root["triangle_budget"] = 4500
    markers = [
        marker("marker_grip_rear", (0.0, 0.0, 0.185), "rear hand attachment; local +Z follows haft"),
        marker("marker_grip_lead", (0.0, 0.0, 0.445), "lead hand attachment; local +Z follows haft"),
        marker("marker_strike", (0.118, 0.0, 1.020), "primary contact point; local +Z points outward along +X", rotation=(0.0, math.pi / 2.0, 0.0)),
        marker("marker_sweep_pivot", (0.0, 0.0, 0.185), "committed swing reference; local +Z follows haft"),
    ]
    for obj in parts + markers:
        obj.parent = root

    metrics = evaluated_metrics(parts, len(mats), markers)
    root["dimensions_m"] = " x ".join(f"{value:.3f}" for value in metrics["dimensions_m"])
    root["physical_overall_length_m"] = metrics["physical_overall_length_m"]

    if metrics["triangles"] > 4500 or metrics["materials"] > 12:
        raise RuntimeError("Asset exceeds production budget")
    if metrics["non_manifold_edges"] or metrics["degenerate_faces"]:
        raise RuntimeError(f"Mesh audit failed: {metrics}")
    if abs(metrics["bounds_min_m"][2]) > 0.001:
        raise RuntimeError(f"Pommel is not grounded: {metrics['bounds_min_m'][2]}")

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "source.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts + markers + [root]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "model.glb"), export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    render_review(parts, os.path.join(ROOT, "preview.png"), (1.35, -1.80, 1.35), 58)
    render_review(parts, os.path.join(ROOT, "side.png"), (0.02, -2.25, 0.78), 58)
    metrics["export_validation"] = validate_export(os.path.join(ROOT, "model.glb"), [obj.name for obj in markers])
    with open(os.path.join(ROOT, "metrics.json"), "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)
        handle.write("\n")
    print("CLUB_BUILD_OK " + json.dumps(metrics, sort_keys=True))


if __name__ == "__main__":
    main()
