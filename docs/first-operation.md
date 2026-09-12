# First operation — frontier relay

Proposed validation slice, 2026-09-12. This is not the final opening or a committed story mission. Its job is to test [core conception](core-conception.md), [campaign agency](campaign-and-agency.md) and [information](information-and-companion.md) together.

## Playable sequence

1. At a small FOB, inspect a physical sector map. Choose between two approaches to a frontier relay and select a minimal kit.
2. Travel a short, legible route. Recognise the relay landmark and one threat signal without a floating objective marker.
3. Fight a small mixed group through movement and shooting. Candidate roles: a ranged pressure unit and a repositioning unit. These are test functions, not settled enemy species.
4. Secure the relay using available infantry/vehicle capabilities. Operate its physical console. Observe offline, linking and operational states and receive a support acknowledgement.
5. Demonstrate the newly available coordinated support against a suitable test obstacle. Make the unavailable/available distinction explicit without requiring support to capture its own prerequisite relay.
6. Return to or establish the captured site's planning position. Reveal candidate onward routes and a short authored aftermath. Test local success remaining visible alongside the fixed story beat.

## Build order and asset needs

| Priority | Deliverable | What must be demonstrated |
|---|---|---|
| P0 | Standalone Godot FOB/map/relay test scene | Does not depend on the terrain demo or a complete campaign simulation. |
| P0 | Physical map table/projector with procedural holographic sectors and links | Two selectable routes, visible support coverage, readable unsupported/offline state, selected route feedback. This requires runtime visuals and interaction, not just a static mesh. |
| P0 | Modular FOB greybox | A recognisable planning point, deployment exit, rearm location and readable circulation; dimensions judged with the player present. |
| P0 | Relay/console greybox with observable states | Capture and link activation visibly change communications/support availability. |
| P1 | Small combat courtyard and two approaches | Threats, cover, movement and readable alternatives work in play. Reuse existing weapons/characters/vehicle where suitable. |
| P1 | Companion presentation stub | A small set of grounded acknowledgements, one optional translation moment, silence when nothing useful needs saying. No final voice casting or plot identity required. |
| P1 | Stop-to-view local hologram experiment | Compare navigation clarity and friction against the FOB-only baseline; remain proposed until tested. |
| P2 | Reviewed production FOB, relay and projector meshes/materials | Replace successful greyboxes while preserving interaction and sightlines. Crude realism; avoid premature decoration. |

Defer catalogue-wide weapons, mounts, medieval equipment and unrelated vehicle production. Existing exports are retained as prototypes, not gameplay-approved assets. Enemy design and combat tuning are prerequisites for expanding that art list.

## Acceptance observations

- Can a fresh player explain the objective, chosen route and support limitation from the installation and world signals?
- Can they identify an incoming threat and deliberately change the fight through movement or targeting?
- Can they distinguish loss of comms from exhausted/unavailable support?
- Does activating the relay make an immediate, understandable difference?
- Does the same place visibly become useful as a FOB, and does its map show the new opportunity?
- Is the exchange enjoyable without loot or XP, while its outcome changes the next available situation?
- Do the companion and optional hologram help without explaining every action or obscuring enemies?
- Does the authored aftermath recognise local success without allowing a rewritten theatre?

Record observations and unresolved failures; do not claim validation from screenshots alone. Test representative co-op use and target hardware before scaling. No exact frame budget, enemy count, melee reach or production triangle budget is ratified here.

## Automation boundary

The old model worker is paused and its Windows task disabled. It can generate Blender sources/GLB, render and review meshes, but cannot validate playable map interaction, mission states or combat enjoyment with its current checks. It must not be restarted merely by replacing catalogue IDs with “FOB” or “hologram”. First build the P0 interactive slice, identify stable asset contracts, then commission bounded art tasks with suitable checks.
