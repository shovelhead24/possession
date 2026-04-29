# Possession — Claude Instructions

## Workflow

**Always commit after making code changes.** The dev pipeline is: Codespaces edit → git push → PowerShell watcher on the laptop auto-pulls and relaunches Godot. Changes are not testable until they are committed and pushed.

Commit message style: short imperative summary, no body needed.

## Getting Godot Logs

The PowerShell watcher on the laptop has a key binding: pressing **L** in the watcher/run script window pushes the current Godot log to git. After asking the user to test something, they can press L to share the log — check `git log` and `git show` on the latest commit to read it.

## Project Context

Scifi FPS set on a ringworld. Godot 4, targeting potato hardware. Player uses a carbine (FP arms). Enemy soldiers use the same carbine model attached via BoneAttachment3D to mixamorig_RightHand, rotation `Vector3(90, -90, 0)`.

### Character Pipeline (`game/pipeline/`, `game/addons/char_pipeline/`)
Modular character part system. `PartDef` resource → `CharacterRecipe` → `CharacterAssembler` builds BoneAttachment3D per part on a skeleton. EditorPlugin dock scans `res://pipeline/parts/` for .tres files.

### Cage Mesh Editor (`game/addons/cage_editor/`)
EditorPlugin for sculpting low-poly cage meshes with live Catmull-Clark subdivision preview. Enable it in Project → Project Settings → Plugins.

**Workflow:** Click Head/Hand/Foot/Torso in the dock → CageMesh node appears in scene.
- **Orange handles** = vertices — drag to sculpt
- **Teal "+" crosses** = face centers — click to select (turns green), drag to move whole face
- **Symmetry (X)** toggle (default on) — all edits mirror across X=0
- **Extrude Face** — duplicates selected face + side quads; drag new face out to create protrusions
- **Inset** — shrinks face inward with a ring of quads (amount spinbox, default 0.25)
- **Scale +/−** — grows/shrinks face around centroid
- **Bake → PartDef** — subdivides and saves to `res://pipeline/parts/baked/`

Key files: `cage_mesh.gd`, `cage_mesh_gizmo.gd`, `cage_panel.gd`, `cage_subdivider.gd`, `cage_templates.gd`

### Workflow change
User now runs Claude Code natively on Windows laptop (direct file access — no more git push/pull loop needed for edits). Godot project root is `game/` inside the repo.
