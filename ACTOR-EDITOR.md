# Actor and patrol editor — 2026-10-12

Open **Rebuild Demo**, press **F1**, then choose **Actors + patrol routes**. Existing alien encounters and the larger T. rex become editable defaults on the first run. The original player Warthog remains available separately.

## Place and edit

- Choose Grunt, Captain, Squad (five aliens), T. rex or Warthog, then click loaded, walkable terrain. Placement pins identify authored spawns; actors begin running when you return to play.
- Select a pin or an entry in the list. Focus moves the editor camera to its spawn. G moves the spawn **and translates its route**. Copy waits for a new location; Esc cancels the copy. Delete removes the selection.
- The **Behavior** tab controls enabled state, facing, behavior and patrol speed. The **Patrol route** tab controls waypoints, wait time and looping.
- Add point: click successive terrain positions. Esc finishes. Select a waypoint in the list to move it, remove it, or move it earlier/later. Selected route points are numbered in the scene. Clear route removes all waypoints.
- With looping off, actors stop at the last point. An empty route holds at the spawn during patrol. Auto/combat responses can still interrupt a patrol.
- F1 resumes play and applies changed actor records. Changing an actor's authoring settings reconstructs that actor from its spawn. Unchanged encounters keep running state.
- Ctrl+S saves terrain, painted trees, construction and actors. Ctrl+Z/Y undo/redo the active tool. Reload actors restores the actor save; undo can reverse the reload.
- F7 resets encounters to the current authored layout. It does not discard edits or change the saved layout.

## Behaviors

| Actor | Modes |
| --- | --- |
| Grunt, captain, squad | Patrol with normal combat response; guard with combat response; patrol only without firing |
| T. rex | Auto patrol/hunt; patrol only; hunt; hold |
| Warthog | Parked/drivable; patrol/drivable |

Alien combat retains its existing sight, cover, hunting, dives, plasma fire and squad morale. A lone grunt operates independently rather than immediately fleeing because it lacks a captain. T. rexes retain the current size, terrain footing, attacks and tree-trunk exceptions.

Placed Warthogs use the existing vehicle model, Wishbone suspension, tuning, audio, collision damage and upward punts. E enters the closest Warthog within six metres when it is slow enough and entry is unobstructed. Player control takes over its patrol; exiting lets the assigned behavior resume. Exit an occupied authored Warthog before changing its spawn/settings.

Warthog routes steer real physics vehicles. Lay them along clear, drivable ground with room to turn; this is not obstacle-avoiding road navigation. They brake before unloaded terrain. Vehicle patrol speed is a target, not an instantaneous velocity.

## Saves and runtime cost

Actor layouts save separately to `%APPDATA%/Godot/app_userdata/Rebuild Demo/actors.json`, with a backup on replacement. Authored spawn positions and routes are saved, not the actors' transient gameplay positions or damage. Invalid records reject the entire load without replacing the current layout. `--actors-file=<absolute JSON path>` selects an isolated actor save for testing.

There is no placement-count limit. Nearby runtime activation is budgeted to 10 living aliens, two T. rexes and four authored Warthogs, in addition to the original player Warthog. Extra nearby actors wait for capacity. Distant actors unload; T. rex health, death state and waypoint progress persist until F7. Held victims and unfinished bites prevent unsafe unloading. Small alien navigation grids recenter for longer routes while retaining their bounded build budget.

These limits contain added simulation cost; they do not establish a 120 FPS result. F8 now includes authored actor state alongside the existing diagnostics.

## Developer validation

- `check_actor_data.gd`: save/reload, malformed-save rejection, undo/redo, waits and looping.
- `check_actor_world.gd`: rendered editor, placement, move/copy/delete, route edits, saved coordinates, live patrols, vehicle suspension and driving, vehicle entry, reset and streaming state.
- `check_rebuild_rex_impacts.gd`: original tactical, collision punt, rotated-ring footing and four-attack regression suite.

Always isolate **all four saves** when running the full scene: `--drive-edits-file`, `--tree-paint-file`, `--forge-file`, and `--actors-file`. Never run destructive editor tests on player saves.

## AI diagnostics and heavy crates / 2026-10-14
F4 toggles fixed screen-size AI labels; F8 records state and navigation snapshots. Heavy crate is now in the Actors palette: a 160 kg rigid body moved by vehicles and grenade blasts, with up to eight active nearby. See AI-DIAGNOSTICS-CRATES.md.

## Object placement cursors / 2026-10-16
Place, Move and Copy show the actual visual model for grunts, captains, squads, T. rex, Warthogs and heavy crates, preserving authored yaw. Previews have no collision bodies, AI or audio. Waypoint operations keep the small marker. Preview resources are reused while aiming and hidden on cancel, panel changes or return to play. Ctrl+F6 / Reload development changes rebuilds the editor and preview code while retaining actor layout, undo and the active operation; it does not respawn the encounter.

## Altay tank / 2026-10-16
Altay is available in the actor palette, with actual-model preview, parked/drivable or patrol/drivable modes and the existing route controls. Two authored tanks can stream nearby in addition to the starting showcase tank. See TANK-REBUILD-2026-10-16.md for controls and measured limits.
