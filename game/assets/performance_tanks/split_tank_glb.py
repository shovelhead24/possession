#!/usr/bin/env python3
"""Split Tank.glb's disconnected triangle components into named rig groups.

Offline only. The source GLB is never modified. Run with the Python runtime
bundled with the workspace, or ordinary Python 3.10+.
"""
import json, math, struct
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "game/assets/performance_tanks/Tank.glb"
OUT = ROOT / "game/assets/performance_tanks/Tank-articulated.glb"
REPORT = Path(__file__).with_name("Tank-articulated-components.json")

COMPONENT_INDEX = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}
VALUE_FORMAT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
TYPE_SIZE = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}

def read_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2 and length == len(data)
    pos = 12
    json_chunk = None
    bin_chunk = None
    while pos < len(data):
        size, kind = struct.unpack_from("<I4s", data, pos)
        chunk = data[pos + 8:pos + 8 + size]
        if kind == b"JSON": json_chunk = json.loads(chunk.decode("utf-8"))
        elif kind == b"BIN\x00": bin_chunk = chunk
        pos += 8 + size
    return json_chunk, bin_chunk

def accessor_raw(doc, blob, accessor_id):
    a = doc["accessors"][accessor_id]
    assert "sparse" not in a, "Sparse accessors need explicit expansion"
    view = doc["bufferViews"][a["bufferView"]]
    n = TYPE_SIZE[a["type"]]
    fmt = VALUE_FORMAT[a["componentType"]]
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", size * n)
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [blob[start + i * stride:start + i * stride + size * n] for i in range(a["count"])]

def accessor_values(doc, blob, accessor_id):
    a = doc["accessors"][accessor_id]
    fmt = VALUE_FORMAT[a["componentType"]]
    n = TYPE_SIZE[a["type"]]
    return [struct.unpack("<" + fmt * n, row) for row in accessor_raw(doc, blob, accessor_id)]

def append_accessor(doc, blob_builder, values_raw, template, *, position_values=None):
    comp = template["componentType"]
    fmt, comp_size = VALUE_FORMAT[comp], struct.calcsize("<" + VALUE_FORMAT[comp])
    n = TYPE_SIZE[template["type"]]
    raw = b"".join(values_raw)
    while len(blob_builder) % 4: blob_builder.append(0)
    offset = len(blob_builder)
    blob_builder.extend(raw)
    view = {"buffer": 0, "byteOffset": offset, "byteLength": len(raw)}
    doc["bufferViews"].append(view)
    acc = {"bufferView": len(doc["bufferViews"]) - 1, "byteOffset": 0,
           "componentType": comp, "count": len(values_raw), "type": template["type"]}
    if template.get("normalized"): acc["normalized"] = True
    if position_values is not None:
        acc["min"] = [min(v[d] for v in position_values) for d in range(n)]
        acc["max"] = [max(v[d] for v in position_values) for d in range(n)]
    doc["accessors"].append(acc)
    return len(doc["accessors"]) - 1

def primitive_components(doc, blob, primitive, primitive_id):
    pos_accessor = primitive["attributes"]["POSITION"]
    positions = accessor_values(doc, blob, pos_accessor)
    index_accessor = primitive.get("indices")
    if index_accessor is None:
        indices = [(i,) for i in range(len(positions))]
    else:
        indices = accessor_values(doc, blob, index_accessor)
    flat = [x[0] for x in indices]
    assert len(flat) % 3 == 0, "Expected triangle primitive"
    triangles = [flat[i:i + 3] for i in range(0, len(flat), 3)]
    parent = list(range(len(triangles)))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    def union(a, b):
        a, b = find(a), find(b)
        if a != b: parent[b] = a
    seen = {}
    for ti, tri in enumerate(triangles):
        for vi in tri:
            key = tuple(round(float(v), 7) for v in positions[vi][:3])
            if key in seen: union(ti, seen[key])
            else: seen[key] = ti
    groups = defaultdict(list)
    for ti, tri in enumerate(triangles): groups[find(ti)].append(tri)
    result = []
    for ordinal, tris in enumerate(sorted(groups.values(), key=lambda ts: (min(ts[0]), len(ts)))):
        vids = sorted({v for tri in tris for v in tri})
        points = [positions[i] for i in vids]
        bounds = [[min(float(v[d]) for v in points), max(float(v[d]) for v in points)] for d in range(3)]
        result.append({"primitive_id": primitive_id, "component_id": ordinal, "triangles": tris,
                       "vertex_ids": vids, "bounds_src": bounds, "triangle_count": len(tris),
                       "material": primitive.get("material"), "attributes": primitive["attributes"]})
    return result

def classify(c):
    x, y, z = c["bounds_src"]
    p, t = c["primitive_id"], c["triangle_count"]
    # The 236-triangle, centerline green island is the complete narrow cannon tube.
    if p == 1 and t >= 150 and x[0] > -0.0012 and x[1] < 0.0012 and (y[1] - y[0]) > 0.015 and (z[1] - z[0]) < 0.003:
        c["role"] = "Barrel"
        return
    # Primitive 3 has the 14 repeated, isolated road-wheel solids (seven on each side).
    if p == 3 and t == 108 and (x[1] - x[0]) < 0.0012 and abs((x[0] + x[1]) / 2) > 0.007:
        c["role"] = "Wheel"
        c["side"] = "L" if (x[0] + x[1]) / 2 < 0 else "R"
        c["forward_coord"] = -((y[0] + y[1]) / 2) # +Z is forward after source transform
        return
    # Reviewed semantic overrides: headlights remain on hull; roof, rear turret
    # stowage and its antennas follow yaw. Preserve complete component geometry.
    identity = (p, c["component_id"])
    if identity in {(1, 0), (1, 3)}:
        c["role"] = "Hull"
        return
    if identity in {(0, 4), (0, 5), (1, 6), (3, 0)}:
        c["role"] = "Turret"
        return
    # All triangles stay whole. This region encloses the raised central turret shell
    # (large green island) and its small attached detail islands, excluding the barrel.
    xmid, ymid = (x[0] + x[1]) / 2, (y[0] + y[1]) / 2
    if (abs(xmid) <= 0.0076 and y[0] >= -0.0115 and y[1] <= 0.0155
        and z[1] >= 0.0040 and (z[1] - z[0]) >= 0.0002):
        c["role"] = "Turret"
        return
    c["role"] = "Hull"

def main():
    doc, source_blob = read_glb(SRC)
    mesh = doc["meshes"][0]
    comps = []
    for pi, prim in enumerate(mesh["primitives"]): comps.extend(primitive_components(doc, source_blob, prim, pi))
    for c in comps: classify(c)
    # Stable wheel names from front (+Z) to rear (−Z), independently on each side.
    wheels = [c for c in comps if c["role"] == "Wheel"]
    for side in ("L", "R"):
        ordered = sorted((c for c in wheels if c["side"] == side), key=lambda c: -c["forward_coord"])
        assert len(ordered) == 7, f"Expected seven {side} road wheels, got {len(ordered)}"
        for num, c in enumerate(ordered, 1): c["node_name"] = f"Wheel_{side}_{num:02d}"
    assert sum(c["triangle_count"] for c in comps if c["role"] == "Barrel") == 236, "Unexpected barrel component"
    assert len([c for c in comps if c["role"] == "Turret"]) > 0

    # New mesh for each whole connected component. Copy every vertex attribute byte
    # unchanged for its used vertices; remap only the component's triangle indices.
    binary = bytearray(source_blob)
    doc["meshes"] = []
    doc["nodes"][1].pop("mesh", None)
    root_children = []
    group_indices = {}
    for group_name in ("Hull", "Turret", "Barrel"):
        idx = len(doc["nodes"])
        doc["nodes"].append({"name": group_name, "children": []})
        root_children.append(idx)
        group_indices[group_name] = idx
    # Keep groups beneath original Super_Tank node (whose transform is untouched).
    doc["nodes"][1]["children"] = root_children

    def add_component_node(c, node_name):
        p = mesh["primitives"][c["primitive_id"]]
        vertex_ids = c["vertex_ids"]
        remap = {old: new for new, old in enumerate(vertex_ids)}
        attrs = {}
        pos_values = None
        for semantic, source_acc in p["attributes"].items():
            raw = accessor_raw(source_doc, source_blob, source_acc)
            template = source_doc["accessors"][source_acc]
            selected = [raw[v] for v in vertex_ids]
            vals = accessor_values(source_doc, source_blob, source_acc) if semantic == "POSITION" else None
            attrs[semantic] = append_accessor(doc, binary, selected, template,
                                               position_values=vals and [vals[v] for v in vertex_ids])
        idx_template = source_doc["accessors"][p["indices"]]
        index_type = idx_template["componentType"]
        if index_type not in COMPONENT_INDEX: index_type = 5125
        fmt = VALUE_FORMAT[index_type]
        remapped = [remap[v] for tri in c["triangles"] for v in tri]
        index_raw = [struct.pack("<" + fmt, v) for v in remapped]
        index_acc = append_accessor(doc, binary, index_raw,
                                    {"componentType": index_type, "type": "SCALAR"})
        prim_out = {"attributes": attrs, "indices": index_acc, "mode": p.get("mode", 4)}
        if c["material"] is not None: prim_out["material"] = c["material"]
        new_mesh = len(doc["meshes"])
        doc["meshes"].append({"name": node_name, "primitives": [prim_out]})
        node_index = len(doc["nodes"])
        doc["nodes"].append({"name": node_name, "mesh": new_mesh})
        return node_index

    source_doc = json.loads(json.dumps(doc))
    # source_doc must retain the original mesh/accessor structure for the component copies.
    source_doc["meshes"] = json.loads(json.dumps(meshes_original))
    for c in comps:
        if c["role"] == "Wheel":
            node_name = c["node_name"]
            child = add_component_node(c, node_name)
            doc["nodes"].append({"name": node_name, "children": [child]})
            root_children.append(len(doc["nodes"]) - 1)
        else:
            node_name = f"{c['role']}_p{c['primitive_id']}_c{c['component_id']:03d}"
            child = add_component_node(c, node_name)
            doc["nodes"][group_indices[c["role"]]]["children"].append(child)
    # All wheel pivots share the same preserved Super_Tank transform and exact source-space bounds.
    # Keep scene roots unchanged; update only root node 1's new children above.
    doc["buffers"][0]["byteLength"] = len(binary)
    # Pad BIN chunk to four-byte alignment; buffer byteLength excludes padding.
    while len(binary) % 4: binary.append(0)
    raw_json = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    while len(raw_json) % 4: raw_json += b" "
    total_len = 12 + 8 + len(raw_json) + 8 + len(binary)
    out = bytearray(struct.pack("<4sII", b"glTF", 2, total_len))
    out.extend(struct.pack("<I4s", len(raw_json), b"JSON")); out.extend(raw_json)
    out.extend(struct.pack("<I4s", len(binary), b"BIN\x00")); out.extend(binary)
    OUT.write_bytes(out)

    by_role = defaultdict(list)
    for c in comps:
        x,y,z=c["bounds_src"]
        # Converted world coordinates under original source node: (100*x, 100*z, -100*y).
        bbox_godot = [[100*x[0],100*z[0],-100*y[1]],[100*x[1],100*z[1],-100*y[0]]]
        record={"primitive":c["primitive_id"],"component":c["component_id"],"triangles":c["triangle_count"],
                "material":c["material"],"role":c["role"],"bounds_source_xyz":c["bounds_src"],
                "bounds_after_original_node_xyz":bbox_godot,"vertices":len(c["vertex_ids"])}
        if c.get("role")=="Wheel":record.update({"node":c["node_name"],"forward_order_coordinate":c["forward_coord"]})
        by_role[c["role"]].append(record)
    report={"source":str(SRC),"derivative":str(OUT),"classification_rules":{
        "barrel":"primitive 1 centerline island, >=150 tris, narrow X, long source-Y extent, source-Z thickness <0.003; exact island has 236 triangles",
        "wheels":"primitive 3 repeated 108-triangle islands, narrow X at either side; seven per side, numbered front (+Godot Z) to rear",
        "turret":"whole components centered within source X +/-0.0076 and source Y [-0.0115,0.0155], reaching source Z >=0.004; includes raised central shell and detail islands",
        "hull":"all remaining whole disconnected components"},
        "source_node_transform":doc["nodes"][1].get("rotation"),"source_node_scale":doc["nodes"][1].get("scale"),
        "source_materials":len(doc.get("materials",[])),"source_triangles":sum(c["triangle_count"] for c in comps),
        "output_triangles":sum(c["triangle_count"] for c in comps),"all_triangles_conserved":True,
        "component_count":len(comps),"by_role":{k:sorted(v,key=lambda r:(r["primitive"],r["component"])) for k,v in by_role.items()},
        "notes":["The turret mask is geometric, not semantic; inspect Turret component bounds in the preview before gameplay integration.",
                 "Continuous tread bands and small lamps/antenna-like pieces remain hull because they are not articulated in this derivative.",
                 "All surfaces preserve their original material and attribute values; component triangles are not cut."]}
    REPORT.write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps({"output":str(OUT),"report":str(REPORT),"triangles":report["source_triangles"],"components":len(comps),
                      "roles":{k:{"components":len(v),"triangles":sum(c["triangles"] for c in v)} for k,v in by_role.items()}},indent=2))

if __name__ == "__main__":
    source_doc, source_blob = read_glb(SRC)
    meshes_original = json.loads(json.dumps(source_doc["meshes"]))
    main()



