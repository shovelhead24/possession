# Information, physical interfaces and companion

Baseline 2026-09-12. Objects are the primary interface; a working state should be understandable from its world representation. Signals below are proposed for validation, not an instruction to implement the entire list.

## Readable signals

| Scale | Observable signal | Useful interpretation / action |
|---|---|---|
| Tactical | Weapon charge sound and visible preparation | Move, interrupt or bait the coming attack. |
| Tactical | Shield failure, stagger or exposed mechanism | Exploit a temporary opening. |
| Tactical | Braced weapon and visible traverse limits | Recognise the dangerous arc and find another approach. |
| Tactical | Leader calls/gestures and squad response | Read coordination; test what disruption changes. |
| Tactical | Search at the last known position, directional calls | Reposition while enemies investigate incomplete information. |
| Tactical | Transport arrival and dismount sequence | Recognise reinforcements and their arrival phase. |
| Strategic | Relay linking motion, console state, support acknowledgement | A communications path is available. |
| Strategic | Link alarm, static and missing acknowledgement | Support cannot be coordinated; the cause may require investigation. |
| Strategic | Loaded transport departing toward another position | A local movement offers interception or observation. |
| Strategic | Friendly crews and operational equipment at a captured fortress | This site now functions as a FOB. |
| Theatre | Authored evacuation traffic, distant fighting or official broadcasts | Communicate the current story situation without requiring a campaign HUD. |
| Theatre | A distant chain goes dark and reports cease | Contact is lost; do not imply knowledge of the exact cause. |

Theatre signals stage the authored story; they are not proof of a freely simulated war. Signals representing local actions should correspond to real state changes. Give critical information visual and audible forms plus accessibility equivalents. Distinguish contact lost from destroyed, reported from observed, and known from unknown.

## Maps

**Decided:** FOBs provide mission planning through a physical map installation. Objects remain the interface; no omniscient always-open campaign overlay.

**Proposed:** the companion can project a local holographic map while the player stops to examine it. This modifies the earlier FOB-only map idea and needs testing. It must not quietly become a mobile full planning screen. Define how projection starts/closes, how movement interrupts it, whether the world continues, and how co-op players participate before shipping it.

Maps show available information with source and freshness, not hidden world truth. A lost link stops updates; it does not erase downloaded knowledge. The FOB map can display authored route topology while tactical details remain incomplete. Ring landmarks and the sky still help orientation.

## Companion

**Decided:** an AI companion belongs in the intended experience.

**Proposed capability boundary:** interpret local sensors and received reports; translate supported languages; recognise patterns; operate compatible systems through a physical connection and appropriate access. Possessing a hologram display gives no additional knowledge. Communications outages limit remote services without disabling established local functions.

Translation should have defined competencies and uncertainties; it is not automatically universal understanding. Door access needs consistent power, connection and permission rules rather than arbitrary story-dependent hacking. The character must not constantly narrate clues the player already understands or replace every physical action.

**Open:** identity, personality, motives, origin, relation to earlier lore AI, dramatic centrality, translation range, trust arc and co-op presence. The companion is not assumed to be the Displacement AI. Importance to the story can be high while operational powers remain limited.

The existing offline-authored/baked dialogue boundary remains: a fictional AI character is not a decision to ship runtime LLM inference. Authored short lines can test the role. Without a companion, these functions would be distributed among people, radios and terminals; that remains reference material, not the selected direction.
