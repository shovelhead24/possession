import bpy
import json
import math
import os
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))

def material(name, color, metallic=0.0, roughness=0.6):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat

def mesh_object(name, vertices, faces, mat):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=False)
    mesh.update()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def box(name, location, dimensions, mat, bevel=0.0, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name + "Mesh"
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("purposeful edge break", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
    return obj

def cylinder_between(name, a, b, radius, mat, sides=8):
    start, end = Vector(a), Vector(b)
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=direction.length,
        location=(start + end) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name + "Mesh"
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    obj.data.materials.append(mat)
    return obj

def tube_polyline(name, points, radius, mat, sides=8, radii=None):
    """Closed low-poly tube following a planar centreline, with true bent continuity."""
    points = [Vector(p) for p in points]
    radii = radii or [radius] * len(points)
    vertices = []
    for index, point in enumerate(points):
        if index == 0:
            tangent = (points[1] - point).normalized()
        elif index == len(points) - 1:
            tangent = (point - points[index - 1]).normalized()
        else:
            tangent = (points[index + 1] - points[index - 1]).normalized()
        lateral = Vector((0, 1, 0))
        planar_normal = tangent.cross(lateral).normalized()
        for side in range(sides):
            angle = 2.0 * math.pi * side / sides
            offset = lateral * math.cos(angle) + planar_normal * math.sin(angle)
            vertices.append(tuple(point + offset * radii[index]))
    faces = []
    for ring_index in range(len(points) - 1):
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((ring_index*sides + side, ring_index*sides + nxt,
                          (ring_index+1)*sides + nxt, (ring_index+1)*sides + side))
    faces.append(tuple(range(sides - 1, -1, -1)))
    last = (len(points) - 1) * sides
    faces.append(tuple(last + side for side in range(sides)))
    return mesh_object(name, vertices, faces, mat)

def ring(name, z0, z1, radius, mat, sides=8, center_x=0.0):
    vertices = []
    for z in (z0, z1):
        for side in range(sides):
            angle = 2.0 * math.pi * side / sides
            vertices.append((center_x + radius * math.cos(angle), radius * math.sin(angle), z))
    faces = []
    for side in range(sides):
        nxt = (side + 1) % sides
        faces.append((side, nxt, sides+nxt, sides+side))
    faces.extend([tuple(range(sides-1, -1, -1)), tuple(sides+i for i in range(sides))])
    return mesh_object(name, vertices, faces, mat)

def extruded_xz(name, profile, width, mat):
    """Extrude a clockwise X/Z profile across Y; useful for visibly cut scrap plate."""
    half = width * 0.5
    vertices = [(x, -half, z) for x, z in profile] + [(x, half, z) for x, z in profile]
    count = len(profile)
    faces = [tuple(range(count - 1, -1, -1)), tuple(count + i for i in range(count))]
    for i in range(count):
        nxt = (i + 1) % count
        faces.append((i, nxt, count+nxt, count+i))
    return mesh_object(name, vertices, faces, mat)

def folded_sheet_xz(name, centreline, widths, thickness, mat):
    """Thin battered sheet following bends in X/Z, extruded across irregular Y edges."""
    points = [Vector((x, 0, z)) for x, z in centreline]
    vertices = []
    for index, point in enumerate(points):
        if index == 0:
            tangent = (points[1] - point).normalized()
        elif index == len(points) - 1:
            tangent = (point - points[index - 1]).normalized()
        else:
            tangent = (points[index + 1] - points[index - 1]).normalized()
        normal = Vector((-tangent.z, 0, tangent.x)).normalized() * (thickness * 0.5)
        half_width = widths[index] * 0.5
        vertices.extend([tuple(point - normal + Vector((0, -half_width, 0))),
                         tuple(point - normal + Vector((0, half_width, 0))),
                         tuple(point + normal + Vector((0, -half_width, 0))),
                         tuple(point + normal + Vector((0, half_width, 0)))])
    faces = []
    for index in range(len(points) - 1):
        a, b = index * 4, (index + 1) * 4
        faces.extend([(a, b, b+1, a+1), (a+2, a+3, b+3, b+2),
                      (a, a+2, b+2, b), (a+1, b+1, b+3, a+3)])
    faces.extend([(0, 1, 3, 2), (len(vertices)-4, len(vertices)-2,
                                  len(vertices)-1, len(vertices)-3)])
    return mesh_object(name, vertices, faces, mat)

def plate_yz(name, x, profile, mat, thickness=0.003):
    """Small irregular patch on a +X-facing sheet; used for local paint loss."""
    vertices = [(x-thickness/2, y, z) for y, z in profile]
    vertices += [(x+thickness/2, y, z) for y, z in profile]
    count = len(profile)
    faces = [tuple(range(count-1, -1, -1)), tuple(count+i for i in range(count))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count+nxt, count+index))
    return mesh_object(name, vertices, faces, mat)

def claw_prong(name, side, mat):
    """One flattened, splayed pry tine with an unmistakably sharp cut end."""
    # The slit runs diagonally through the flattened pipe end. Separating in Z
    # as well as slightly in Y keeps the deep V legible in both profile and
    # three-quarter views. `side` -1 is the lower tine, +1 the upper.
    base_z = [0.968, 0.970, 0.950, 0.918, 0.878]
    split_z = [0.000, 0.009, 0.020, 0.030, 0.039]
    stations = [
        (-0.080, side*0.006, base_z[0] + side*split_z[0], 0.040, 0.034),
        (-0.145, side*0.010, base_z[1] + side*split_z[1], 0.037, 0.030),
        (-0.215, side*0.014, base_z[2] + side*split_z[2], 0.033, 0.025),
        (-0.276, side*0.017, base_z[3] + side*split_z[3], 0.028, 0.018),
        (-0.320, side*0.020, base_z[4] + side*split_z[4], 0.017, 0.008),
    ]
    vertices = []
    for x, y, z, half_width, thickness in stations:
        # Broad Y faces preserve the flattened pry-tool character.
        vertices.extend([(x, y-half_width, z-thickness/2),
                         (x, y+half_width, z-thickness/2),
                         (x, y-half_width, z+thickness/2),
                         (x, y+half_width, z+thickness/2)])
    faces = []
    for index in range(len(stations) - 1):
        a, b = index*4, (index+1)*4
        faces.extend([(a, b, b+1, a+1), (a+2, a+3, b+3, b+2),
                      (a, a+2, b+2, b), (a+1, b+1, b+3, a+3)])
    last = (len(stations) - 1) * 4
    faces.extend([(0, 1, 3, 2), (last, last+2, last+3, last+1)])
    return mesh_object(name, vertices, faces, mat)

def empty(name, location, purpose, display="ARROWS", size=0.07):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.empty_display_type = display
    obj.empty_display_size = size
    obj["purpose"] = purpose
    return obj

def bounds_and_triangles():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points, triangles = [], 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        triangles += sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons)
        points.extend(obj.matrix_world @ vertex.co for vertex in mesh.vertices)
        evaluated.to_mesh_clear()
    mins = Vector(tuple(min(point[i] for point in points) for i in range(3)))
    maxs = Vector(tuple(max(point[i] for point in points) for i in range(3)))
    return mins, maxs, maxs - mins, triangles

def setup_render(filepath, camera_location, mats):
    bpy.ops.object.camera_add(location=camera_location)
    camera = bpy.context.object
    camera.name = "REVIEW_CAMERA"
    target = Vector((0.0, 0.0, 0.52))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 58
    bpy.context.scene.camera = camera
    for name, location, energy, size in (("REVIEW_KEY", (2.2, -2.8, 3.2), 620, 4.0),
                                         ("REVIEW_FILL", (-2.3, 1.7, 2.1), 360, 3.0),
                                         ("REVIEW_RIM", (0.0, 2.2, -0.2), 180, 2.0)):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.035, 0.055, 0.070, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = filepath
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)

def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mats = {
        "pipe": material("Oxidised blue-black pipe", (0.050, 0.085, 0.095), 0.72, 0.48),
        "tape": material("Tar-black cloth tape", (0.012, 0.016, 0.014), 0.0, 0.94),
        "cloth": material("Faded safety-yellow tape", (0.58, 0.32, 0.035), 0.0, 0.88),
        "sign": material("Faded orange sign steel", (0.52, 0.105, 0.026), 0.28, 0.68),
        "raw": material("Raw battered steel", (0.38, 0.44, 0.43), 0.88, 0.34),
        "rust": material("Deep rust and weld burn", (0.22, 0.045, 0.014), 0.28, 0.92),
        "paint": material("Chipped cream road paint", (0.68, 0.63, 0.43), 0.05, 0.78),
    }
    root = empty("IMPROVISED_ROOT", (0, 0, 0), "asset root / floor contact", "CUBE", 0.08)
    root["asset"] = "weapons-improvised"
    root["design"] = "bent plumbing bar with bolted road-sign shoe and forked pry claw"
    root["forward_source"] = "+X primary impact direction / +Z length"
    root["triangle_budget"] = 4500

    tube_polyline("Continuous bent load-bearing pipe",
        [(0.0, 0, 0.065), (0.0, 0, 0.54), (0.012, 0, 0.67),
         (0.060, 0, 0.790), (0.060, 0, 0.885), (0.010, 0, 0.945), (-0.090, 0, 0.970)],
        0.042, mats["pipe"], 8, [0.038, 0.040, 0.041, 0.043, 0.044, 0.043, 0.041])
    ring("Pipe pommel cap", 0.030, 0.090, 0.052, mats["raw"], 8)

    ring("Grip underwrap", 0.145, 0.615, 0.054, mats["tape"], 8)
    for index, z in enumerate((0.185, 0.265, 0.345, 0.425, 0.505, 0.575)):
        band = ring("Overlapping cloth wrap %02d" % index, z, z + 0.030, 0.058, mats["cloth"], 8)
        band.rotation_euler[2] = (index % 2) * 0.08
    ring("Grip heel wrap", 0.125, 0.175, 0.061, mats["tape"], 8)
    ring("Grip choke wrap", 0.590, 0.642, 0.061, mats["tape"], 8)

    # One thin, hand-cut sign panel kinked into an open C. Its uneven stations make
    # real dents and torn corners part of the silhouette; the pipe remains visible
    # through the wide rear opening rather than disappearing inside a casing.
    folded_sheet_xz("Bent road-sign U shoe",
        [(0.091, 0.931), (0.145, 0.954), (0.207, 0.947),
         (0.241, 0.918), (0.231, 0.894), (0.247, 0.870),
         (0.226, 0.829), (0.166, 0.803), (0.096, 0.821)],
        [0.094, 0.116, 0.105, 0.119, 0.098, 0.114, 0.101, 0.120, 0.090],
        0.006, mats["sign"])
    # Irregular exposed steel patches sit on the strike fold as localized paint loss.
    plate_yz("Bare metal impact chip upper", 0.250,
        [(-0.050, 0.902), (-0.017, 0.916), (0.009, 0.906), (0.003, 0.884),
         (-0.030, 0.878), (-0.057, 0.887)], mats["raw"])
    plate_yz("Bare metal impact chip lower", 0.250,
        [(0.027, 0.861), (0.063, 0.870), (0.057, 0.841), (0.039, 0.829),
         (0.015, 0.838)], mats["raw"])
    plate_yz("Surviving cream road paint", 0.251,
        [(-0.008, 0.878), (0.036, 0.874), (0.048, 0.891), (0.026, 0.904),
         (-0.003, 0.896)], mats["paint"], 0.002)
    # Raw cut lips are structural edge faces, not decorative strips.
    extruded_xz("Torn upper cut lip", [(0.139, 0.952), (0.207, 0.945),
        (0.218, 0.936), (0.151, 0.945)], 0.108, mats["raw"])
    extruded_xz("Torn lower cut lip", [(0.157, 0.802), (0.222, 0.827),
        (0.213, 0.837), (0.151, 0.814)], 0.112, mats["raw"])
    for index, (x, z, side) in enumerate(((0.112, 0.933, -1), (0.115, 0.823, 1))):
        cylinder_between("Mismatched shoe fastener %02d" % index,
            (x, side*0.054, z), (x, side*0.073, z), 0.012, mats["raw"], 6)
    extruded_xz("Crude weld bead upper", [(0.065, 0.922), (0.105, 0.932),
        (0.111, 0.941), (0.070, 0.936)], 0.105, mats["rust"])
    extruded_xz("Crude weld bead lower", [(0.069, 0.811), (0.108, 0.815),
        (0.111, 0.825), (0.071, 0.822)], 0.100, mats["rust"])

    claw_prong("Pry claw tine left", -1, mats["pipe"])
    claw_prong("Pry claw tine right", 1, mats["pipe"])
    # Bright, slightly mismatched cut ends outline both teeth at gameplay scale.
    box("Raw cut tip lower", (-0.321, -0.020, 0.839), (0.012, 0.036, 0.013), mats["raw"], 0.001,
        rotation=(0.0, -0.28, 0.0))
    box("Raw cut tip upper", (-0.321, 0.020, 0.917), (0.012, 0.036, 0.013), mats["raw"], 0.001,
        rotation=(0.0, -0.28, 0.0))
    box("Pipe scrape long", (0.043, -0.040, 0.708), (0.010, 0.008, 0.074), mats["raw"], 0.0015,
        rotation=(0.0, 0.18, -0.08))
    box("Pipe rust scar", (0.014, 0.041, 0.675), (0.015, 0.007, 0.040), mats["rust"], 0.0015,
        rotation=(0.1, -0.12, 0.10))

    empty("marker_grip_rear", (0, 0, 0.285), "operative hand attachment")
    empty("marker_grip_lead", (0, 0, 0.525), "optional lead hand attachment")
    empty("marker_strike", (0.267, 0, 0.875), "primary impact face / +X strike direction")
    empty("marker_hook", (-0.320, 0, 0.914), "secondary forked pry contact at V-slot")
    empty("marker_swing_pivot", (0, 0, 0.320), "committed melee swing pivot")

    mins, _, _, _ = bounds_and_triangles()
    for obj in bpy.context.scene.objects:
        if obj != root:
            obj.location.z -= mins.z
    for obj in list(bpy.context.scene.objects):
        if obj != root and obj.parent is None:
            obj.parent = root
    mins, maxs, dimensions, triangles = bounds_and_triangles()
    root["overall_dimensions_m"] = "%.3f x %.3f x %.3f" % tuple(dimensions)
    root["functional_reach_m"] = round(maxs.z, 3)
    root["triangle_count"] = triangles
    root["material_count"] = len(mats)
    invalid_meshes = []
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.data.validate(verbose=False):
            invalid_meshes.append(obj.name)
    if invalid_meshes:
        raise RuntimeError("Invalid mesh data: " + ", ".join(invalid_meshes))
    if triangles > 4500 or len(mats) > 12:
        raise RuntimeError("Asset budget exceeded")

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "source.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "model.glb"), export_format="GLB",
        use_selection=True, export_apply=True, export_yup=True, export_cameras=False, export_lights=False)
    metrics = {"asset": "weapons-improvised", "triangles": triangles, "materials": len(mats),
        "dimensions_m": [round(v, 3) for v in dimensions], "functional_reach_m": round(maxs.z, 3),
        "mesh_objects": len([o for o in bpy.context.scene.objects if o.type == "MESH"]),
        "named_markers": ["marker_grip_rear", "marker_grip_lead", "marker_strike",
                          "marker_hook", "marker_swing_pivot"]}
    with open(os.path.join(ROOT, "metrics.json"), "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)
        handle.write("\n")

    setup_render(os.path.join(ROOT, "preview.png"), (1.05, -1.70, 1.15), mats)
    # Recreate the camera between views so EEVEE cannot reuse temporal samples
    # from the three-quarter projection in the profile evidence image.
    old_camera = bpy.data.objects["REVIEW_CAMERA"]
    bpy.data.objects.remove(old_camera, do_unlink=True)
    bpy.ops.object.camera_add(location=(0.18, -1.90, 0.74))
    camera = bpy.context.object
    camera.name = "REVIEW_CAMERA_SIDE"
    camera.data.lens = 58
    camera.rotation_euler = (Vector((0.0, 0.0, 0.52)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    bpy.context.scene.render.filepath = os.path.join(ROOT, "side.png")
    bpy.ops.render.render(write_still=True)
    print("IMPROVISED_BUILD_OK triangles=%d materials=%d dimensions=%s reach=%.3f" %
          (triangles, len(mats), [round(v, 3) for v in dimensions], maxs.z))

if __name__ == "__main__":
    main()
