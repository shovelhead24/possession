# Tactical valley — first playable layout

Open **Launch-valley.vbs**. The original **Launch-study.vbs** still opens the earlier material/map study.

Walk from the FOB to the relay compound roughly 300 metres away. The western ridge offers height; the eastern gully provides terrain concealment and a marked approach. Central low walls interrupt exposure. The compound has a broad front entrance, a side gap and two enterable buildings with open windows. E at the relay console advances the existing test connection sequence; this is not yet an enemy capture encounter.

## Controls

- WASD: walk. Hold right mouse to look. Shift: sprint. Space: jump.
- 1: FOB; 2: ridge; 3: gully; 4: compound entrance.
- V: switch between walking and inspection flight. Q/Z raise/lower in flight.
- E: use a nearby station. R: select the approach at the FOB table.
- F: compare skies. Tab: hide guide. L/B: debug link loss/support availability.

## Terrain contract and scope

This bounded 360 × 460 metre layout is an authored procedural fixture, not an imported DEM patch or the production terrain generator. It separates broad ridge/gully forms from small cover and buildings, with quiet flat ground at both sites. Collision is generated from the exact visible mesh; the player uses capsule collision and gravity. There is no collision beyond the local test patch; falling out returns the player to the FOB.

The distant ring is still a visual proxy. A gap in its near strip prevents it from occluding the tactical terrain. The main ringworld renderer and DEM data are unchanged.

Next integration work remains explicit: existing first-person arms and held weapons; vehicle driving and model comparisons; adaptation to the latest ringworld height/LOD representation; field/road metadata, trees and buildings sharing that terrain; enemy roles and combat. Medieval assets remain eligible for the test sandbox without reinstating a medieval campaign progression requirement. Do not call this a combat-tested encounter or a finished biome.

## Verified

Run Godot headless with `--path` pointing here and `--script res://test_tactical.gd`. Checks cover route collision/height agreement, open doorway and solid adjacent wall, ridge/gully height separation, a blocked cross-valley sightline, and the player settling on the ground. Existing mission-state tests remain in `test_state.gd`.

Six rendered views cover the route, ridge, gully, compound, interior and overview. These establish geometry visibility, not fresh-player navigation or combat quality. Material fidelity and encounter pacing remain review questions.
