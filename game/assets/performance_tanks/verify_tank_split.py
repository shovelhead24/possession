from collections import Counter
from pathlib import Path
import split_tank_glb as g

def triangles(path):
    doc,blob=g.read_glb(path)
    out=Counter()
    # Traverse only meshes referenced by the default scene.
    pending=list(doc['scenes'][doc.get('scene',0)]['nodes'])
    while pending:
        node=doc['nodes'][pending.pop()];pending.extend(node.get('children',[]))
        if 'mesh' not in node:continue
        for p in doc['meshes'][node['mesh']]['primitives']:
            attrs={k:g.accessor_raw(doc,blob,a) for k,a in p['attributes'].items()}
            indices=[v[0] for v in g.accessor_values(doc,blob,p['indices'])]
            for i in range(0,len(indices),3):
                out[(p.get('material'),tuple(tuple((k,attrs[k][j]) for k in sorted(attrs)) for j in indices[i:i+3]))]+=1
    return out
original=triangles(g.SRC);derived=triangles(g.OUT)
assert original==derived,'Triangle attributes/materials differ'
assert sum(derived.values())==2796
print('PASS 2796 exact triangles, normals, UVs and material assignments conserved')
