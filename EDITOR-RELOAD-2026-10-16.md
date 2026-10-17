# Object cursors, edge snapping and development reload

Implemented in forge_parts, forge_world, forge_editor, actor_editor, actor_preview, rebuild_dev_reload and rebuild_demo. Heavy crates share visual construction with the preview so it needs no physics-body setup.

## Controls and scope
F1 Construction > Snap: camera-nearest edge alignment (default on). Face-centre hover overrides edge alignment. Rotation stays unchanged. Edges use bounding-box projected boundaries, including for ramps and prefabs. Actor place/move/copy uses actual models; route points retain small markers. Runtime encounter state is untouched by previews.

Ctrl+F6 with F1 open, or the Reload development changes buttons in Construction > Layout and Actors. One initial restart installs the hook. Reload scope is forge_parts, forge_world, actor_preview, forge_editor and actor_editor. It does not reload AI, weapons, terrain, base terrain/tree editors or external imported model files. Construction meshes and resident collision are rebuilt. Parser validation runs in a separate headless process before live script replacement. Source reads are staged; a reload failure restores previous script sources. In-memory construction/actor stores and undo stacks remain owned by existing managers; no save/load is performed. Active terrain strokes/painting/measurements block a reload until finished.

## Validation
- check_forge_snap.gd: six face directions, preserved arbitrary rotation, centre coincidence, aimed position, front/back camera edge choice, nonoverlap rejection, oriented-box overlap candidate detection and moving-ID exclusion.
- preview_actor_cursors.gd: all six kinds rendered and visually inspected. No physics bodies or audio nodes in any preview. Models are built once per palette-kind change, not each frame.
- check_dev_reload_source.gd: changed method implementations loaded from disk twice on a live instance; instance state retained.
- check_editor_reload.gd: three successive reloads in the real Rebuild scene, using four isolated save paths. World/streamer/tree/store identities, unsaved records, undo, camera, move draft, hidden selection and settings preserved. Final run: 2.91 / 2.57 / 3.03 seconds per reload. These small isolated layouts are not a large-layout timing guarantee.
- Construction preview/UI screenshot and updated briefing visually inspected. Existing Warthog material conversion warnings remain; no script errors in final integration.

No player layout files were loaded or written by the integration. No ZIP rebuilt. This is not an FPS benchmark.
