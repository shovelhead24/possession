# Possession — Combat & AI

The most-built side of the codebase (April sprint). Mostly needs consolidation and a squad/terrain layer, not a rewrite.

## What Exists

- Enemy soldiers: AI states with cover behavior, mixamo animation set (strafe, reload, hit reaction, firing), carbine attached via BoneAttachment3D to mixamorig_RightHand at `Vector3(90, -90, 0)` (`enemy_controller.gd`, `enemy_soldier.tscn`)
- Factions and a battle-base spawner system (`battle_base.gd`, `enemy_spawner.gd`)
- Weapons: plasma carbine + railgun, first-person arms viewport, weapon switch (dev-loadout; tier-1 starts with none per progression.md)
- Warthog-style vehicle with enter/exit, driver camera, physics driving (`warthog.tscn`, `warthog_controller.gd`) — the full aspirational range (trucks, ribs, ferries, submarines, drones, helicopter dropships) is gated by regional `recovery_band`, see civilization.md
- Demo-cycle test mode for observing a single soldier's animation/AI states in isolation

## Open Questions

- **Squad layer** — the layer stack (docs/vision.md) has Squad between Terrain-as-Strategy and Combat. Nothing squad-shaped exists. What is it — commandable allies, enemy fireteams, both?
- **Terrain as strategy** — the layer above squad. High ground, cover from landscape, sightlines on curved terrain. Needs the terrain plan (issue #1) first.
- **Progression-tier weapons** — tier 2 is bows and medieval factions; the entire current arsenal is tier 3-ish energy weapons. Tier 1 is *no* weapons (prey). Combat has to work unarmed-first.
- **Animals as combatants** — wolves hunt the player (Moment 3). Predator AI is a different shape than soldier cover AI.
- **Damage/health model** — placeholder now; couch co-op raises downed/revive questions.
- **The Medieval Army moment** — a battle that runs *without the player* at watchable scale on potato hardware. Big sim/LOD question.

## Tempo Consumers (PROPOSED 2026-07-19)

Enemy AI decision ticks (grenade timing, decision quality/"cleverness", squad coordination rate) consume shared tempo clocks rather than querying player state directly — see simulation.md "Tempo". Pressure reads as morale (worse, slower decisions), not as a difficulty dial. Design AI states with tick-rate as an external input from day one so the conductor can drive them later without rework.

## Constraints

- Enemy soldiers share the player's carbine model. Character pipeline (docs/characters.md) is how enemy variety gets cheap.
