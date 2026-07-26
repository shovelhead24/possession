# First Slice Mock — Design

Design doc (2026-07-26) for the playable test of the no-missions short-term-pacing bet (pacing.md). The slice: **crash → wilderness walk → the deer → day/night → the wolves → crest the ridge → ring-curve reveal.** Its single job: *does walking this world with only survival + terrain pulling you forward feel compelling, with no missions?* If yes, the core bet is essentially won; if it lulls, we learn it here, cheap.

## Scope Discipline — what we deliberately DON'T build

- **No bow / no weapon (v1).** Tier 1 is prey (vision.md, moments/wolves.md — terrain saves you, not combat). A weapon tests none of the slice's questions and undercuts the helplessness. Deferred to a later hunting pass.
- **No good creature meshes.** Crude procedural proxies (body + 4 legs + head, procedural gait) — silhouette-first is the aesthetic pillar (aesthetic.md), so this is correct, not a compromise. Deer are distant/fleeing, wolves dark/fast — movement and timing carry them, not the mesh.
- **No new terrain tech.** Builds on the ring_vibes foundation (real Millstreet DEM, walk mode, day/night, haze, Halo-CE palette target).
- **No faction/RPG/tools.** The slice is pre-people by design — it's the purest possible pacing test.

## Reused vs. new

- **Reuse:** terrain + walk + day/night + haze (ring_vibes), trees/grass (`prop_pool.gd`), human walk/run animations (mixamo, already imported).
- **New:** the generic creature proxy + startle/flee primitive (wildlife.md); ambient/creature **sound** (CC0-sourced, freesound, same licensing discipline as the DEM — the highest feel-per-effort element); the staged sequence + a legible-path landmark (pacing.md: the ridge must be *visible and readable as reachable* from the start).

## Build Order (cheapest-highest-value first)

1. **Creature proxy + startle/flee primitive** — biggest unknown (quadruped gap), and wolves are the same primitive as deer with different params. Test: a deer herd on real terrain that grazes and flees. **← starting here.**
2. **Staged sequence + legible-path landmark** — spawn at "crash," a readable ridge on the horizon pulling you spinward (the Forge-World "visible path" lesson).
3. **Sound pass** — wind ambience → the drop to silence at the deer clearing (the null-write, made audible) → wolf sound at night. Footsteps + a pressure cue.
4. **Night + wolf pressure** — day/night already exists; wolves activate at night, faster than you, flanking; TempoBuf pressure cue; you run for the ridge/trees and terrain resolves it (no combat).
5. **Palette tune + the reveal** — dial the near/mid/far palette to Halo CE Level 2; crest the ridge for the ring-curve money shot.

## The acceptance test (from simulation.md's deer null-write)

The deer clearing must produce **zero** writes to any threat/encounter/intensity channel — assertable in a debug overlay. If anything twitches when the player meets the herd (music stub, spawn budget, pressure tick), the implementation has violated the moment. "The game does nothing" is a testable requirement.

## Open Questions

- Creature proxy fidelity ceiling — how crude before it breaks immersion rather than reading as stylized? (Distance and darkness hide a lot; a playtest call.)
- Sound sourcing: pure CC0 mix, or synthesize ambient wind procedurally? (Wind is easy to synth; wolves/foley want real samples.)
- Does the slice need hunger/cold as an *explicit* survival pull, or is terrain + wolves + the ridge enough short-term pull on their own? (The minimal version tests the purest hypothesis.)
