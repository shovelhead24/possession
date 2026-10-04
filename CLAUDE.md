# Possession — Claude Instructions

## Workflow

**Always commit after making code changes.** The dev pipeline is: Codespaces edit → git push → PowerShell watcher on the laptop auto-pulls and relaunches Godot. Changes are not testable until they are committed and pushed.

Commit message style: short imperative summary, no body needed.

## Docs Layout

Replaces the old `.planning/` GSD framework (abandoned — too token-heavy for this project).

- `docs/brief.md` — master design brief and decision backlog; the entry point for planning. Decisions hydrate from it down into area docs, then `.decisions/`, then code.
- `docs/` — high-level, mostly-static: vision, stack, per-system area docs, `moments/` director's notes, `research/` source material.
- `.decisions/` — per-system technical decisions, tuned over time (see below).
- GitHub Issues/Projects — day-to-day task tracking.
- `TODO.md` (repo root) — cross-session scratchpad for loose ends without a home yet (blocked items, mid-conversation open threads). Not a duplicate of area docs' own Open Questions sections. Prune as things resolve.

Don't lock volatile tuning values (render distance, LOD tables, shader thresholds) into either `docs/` or `.decisions/` while they're still being matched to a naive/prototype implementation — those get recorded once an implementation pass actually settles them, not during planning.

## Decision Log

Decisions live in `.decisions/`, one file per system (`terrain.md`, `combat.md`, etc.), flat — no nested folders. `.decisions/INDEX.md` is a one-line-per-file map; read that first, then open only the area file(s) relevant to the current task. Never grep/load the whole directory.

Each entry:
```
### <slug> — <short title>
**Date:** YYYY-MM-DD
**Status:** active | SUPERSEDED <date> by <slug>
**Decision:** ...
**Why:** ...
```

Supersession is a status tag on the old entry, not a new file or folder — hierarchy is temporal/textual, not structural.

If a file's whole approach hinges on a non-obvious decision, add one pointer comment at the top of that file: `# see .decisions/<area>.md#<slug>`. Never per-function — those rot silently when code moves and bloat every read.

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

### Standing launch rule
After changing an iteration, always launch the newest relevant playable scene
for the user before handing it back, unless explicitly told otherwise. Automated
or headless tests alone are not the user-facing launch. Use a fresh process, not
scene reload, and say which scene was launched. Never close an existing session
with potentially unsaved work without permission. If launching fails or requires
unavailable approval, report that explicitly rather than claiming it is running.
Keep `game/world/workshop_brief.json` current with the iteration's test goal,
changes and controls; the workshop loading screen presents this on launch.

### Standing terrain cache rule
The user accepted the simple hold-to-sculpt Raise/Lower controls on 2026-10-04.
Preserve that behaviour as the baseline when expanding other authoring tools;
do not redesign or replace it incidentally while changing tunnel controls.

Unless the user explicitly directs otherwise, retain generated terrain meshes on
disk and stream valid cached results when appropriate. RAM eviction is not disk
deletion. Do not introduce automatic disk purging or disable persistence by
default; purging is an explicit housekeeping task, with shipping policy revisited
later. Recipes remain authoritative; stale caches must never be reused after an
edit. This does not require generating unvisited areas. See
`.decisions/terrain.md#sdf-recipe-persistent-cache` and
`docs/sdf-authoring-plan.md` for the authoring and performance backlog.
