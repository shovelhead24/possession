# Rebuild Demo handover — 2026-10-12

## Latest user direction and current state

User stopped the proposed in-game shadow tuning panel. Their playtest showed the aggressive canopy-overlap rule removed almost all shadows at a forest edge, contrary to the intended appearance. They requested reverting the last changes and handing off to the next agent. The tuning panel was never implemented: that turn only read source files.

Completed a scoped rollback of the aggressive obstructed-tree shadow experiment AND its subsequent CPU-cache optimization pass. Do not re-enable the any-overlap rule. Camera occlusion of a tree is not evidence that its ground shadow is unimportant. Forest-edge shadow appearance must be an acceptance criterion for future optimization.

## Workspace and launcher

- Repository: C:/Users/Bran the builder/Documents/Codex/2026-10-08/tree-demo
- Project: game/project.godot; scene: res://world/rebuild_demo.tscn
- Launcher: C:/Users/Bran the builder/Desktop/Rebuild Demo.lnk. This is the user-requested separate rebuild launcher. Keep Tree demo.lnk and Terrain Demo.lnk untouched.
- Godot: C:/Godot/Godot_v4.5.1-stable_win64_console.exe (GUI executable alongside it).
- Read AGENTS.md, TREE-DEMO-HANDOVER.md and REBUILD-DEMO.md in the repository.
- Many pre-existing modified/untracked files. No commit was made. Never use a broad git reset/restore/clean to recover this state.
- game/mocks/dem is a junction to shared original DEM assets; read-only.

## Precisely what was reverted

- tree_shadow_proxy.gd and tree_daylight.gd restored to their reviewed HEAD versions, which contain the earlier normal shadow implementation. Their diff was inspected: daylight changes were solely the rejected pass; proxy baseline predates overlap suppression.
- Removed default overlap enablement from rebuild_demo.gd, the forest-review suppression checkbox and related report/F8 fields.
- Archived tree_shadow_overlap.gd and its dedicated overlap/CPU-cache benchmark scripts outside the active project.
- Reversed the latest tree shadow-revision/LOD separation, caster registry hooks in tree/terrain publication, and changed-group cache work.
- Restored aliens/cover.gd to the original tactical implementation from the local installation source. Cover grounding/clearance are live again; cache telemetry removed.
- Loading briefing now says forest shadows restored and describes the rollback.

The rejected implementation and changed-file backups are preserved at:
C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/work/rejected-shadow-experiment
Rollback script, for audit ONLY (do not rerun):
C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/work/rollback_shadow_experiment.py

Normal shadow support remains grouped by 96 x 96 m cell and species, using 48-triangle proxy silhouettes and the earlier 650 m support range. The 96 m value is cell width, not radius. Detailed mode retains its original detailed tree casters. Normal renderer shadow culling applies; no camera canopy-overlap suppression remains.

## Preserved features

- Authored canopy-density field: 24 m cells, neighbouring-cell update after tree edits, sidecar density cache and explicit editor bake. It is separate from shadow grouping.
- F1 > Forest density & performance: bake/report dense areas, measure editor view, optional density-based detail budget. Experimental detail budget stays OFF by default because FPS gains were inconsistent.
- Five weapons, plasma effects/projectile collision, tactical aliens with patrol/combat, near alien body shadows and combined rifle meshes.
- Forge-style construction, rotation/snap/join/colour controls, terrain and tree editing, collision inspection.
- Tab hides HUD while retaining FPS. F8 records performance diagnostics. F2 opens briefing. F11 toggles frame cap.
- Existing Rebuild launcher and all player save data.

Relevant repository guides: FOLIAGE-SLICE.md, ALIEN-PERFORMANCE.md, TACTICAL-ALIENS.md, CONSTRUCTION-EDITOR.md, COLLISION-INSPECTION.md, WEAPONS-REBUILD.md, PLASMA-EFFECTS.md. SHADOW-OVERLAP.md and CPU-CACHE-UPDATE.md are now explicitly superseded historical reports.

## Validation of rollback

- Rebuild script --check-only passed.
- check_tree_shadow_proxy.gd passed: idle cache, terrain re-grounding, invalidation, visibility and erase cleanup.
- Searched active world scripts for removed suppression/registry/cache references; none remained.
- Rendered the actual workshop_loading.gd component with rebuild_demo_brief.json and visually checked it. Screenshot: rollback-loading.png beside this handover. This was a briefing-only render, not a complete post-rollback gameplay benchmark.
- No new full-world FPS or forest-edge visual playtest was performed after rollback. User should restart Rebuild Demo to load restored code. The 120 FPS target remains unmet; no current FPS claim is made.

Before rollback, the cache pass showed 7.946 -> 6.901 ms for classify/group work and fewer group arrays, with identical output to the rejected rule. That correctness result did NOT validate the desired appearance. Isolated rendered samples ranged 56.6–69 FPS; these are historical and not a matched old/new FPS result.

## Safe test configuration

Player saves live under C:/Users/Bran the builder/AppData/Roaming/Godot/app_userdata/Rebuild Demo. Some diagnostics/cache files use Tree Demo user-data. Never run mutation/performance fixtures against live player saves.

For full-world benchmarks pass ALL THREE overrides after --:
--drive-edits-file=C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/work/collision-saves/terrain-drive-edits.json
--tree-paint-file=C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/work/collision-saves/painted-trees.json
--forge-file=C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/work/collision-saves/construction.json

These fixtures contain 455 terrain edits, 3,668 trees and 26 construction parts. Avoid concurrent gameplay and benchmarks. Do not stop the user's running game without permission.

## Recommended next work, pending user direction

Start by observing restored forest-edge shadows and comparing close-foliage costs with the same view and lighting. Preserve visible ground-shadow coverage. Dense-forest gameplay is out of scope for the first vertical slice; the user explicitly preferred not to over-engineer it. Do not resume the cancelled tuning panel automatically. Any new optimization needs appearance validation as well as timing. Independent cover/caster caching could be reconsidered separately, but it is currently reverted as requested.

SOP: every feature change updates game/world/rebuild_demo_brief.json; set brief_path BEFORE adding the Loading node and verify the rendered text. Keep the separate Rebuild shortcut. Existing documents below their rollback notice are historical, not active requirements.
