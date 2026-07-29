# Possession — Player Consumers

Started 2026-07-29. **A scope instrument, not a system.**

## Why

The project is bounded by what one person plus AI assistance can actually build. The failure mode
that bound most threatens is not "too few features" — it is **simulation nobody perceives**: state
that is computed, stored, propagated and conserved, and never once reaches a player. That work is
invisible in every sense, including in playtesting, so it is never caught by looking at the game.

A *consumer* is a channel through which world state actually reaches the player. Enumerating them
lets us ask the only scope question that matters:

> **Which consumer surfaces this? If none — coarsen it until it costs nothing, or cut it.**

Precedent: `.decisions/design-laws.md#world-never-reads-knowledge` already reasons this way ("the
knowledge pyramid has exactly two consumers"). This generalises that discipline to everything.

## The consumers

| # | Consumer | Carries | Bandwidth | Notes |
|---|---|---|---|---|
| 1 | **Sight — landscape** | terrain, silhouettes, lights, smoke, weather, ruin | very high, passive | The night sky is a *map* (`knowledge.md` K1). Standing draws live here (`draws.md`). |
| 2 | **Sight — bodies** | NPC posture, activity, wear, kit, wounds, numbers | high, local | The only consumer that shows a faction's *state* rather than its territory. Market day vs eve-of-raid (`factions.md` Pulse) is read entirely here. |
| 3 | **Rumor / dialogue** | K2 claims with provenance, distance-decay, staleness | low, lossy, *deliberately* | The only consumer that can carry the past, causes, and other people's beliefs — including wrong ones. Bake-time LLM, zero runtime (`.decisions/dialogue.md`). |
| 4 | **Traces** | objects with histories, bodies, ruins, grievance sites | low, high-impact | Stolen-tool provenance lands here. The only consumer that puts consequence *in the player's hands*. |
| 5 | **Direct encounter (R4)** | actions intersecting the player's bubble | high, rare | Witnessing = choosing to realize (`factions.md`). |
| 6 | **Sound** | signal, gunfire, weather, absence | medium, ambient | Includes the null write: silence as systems *refraining* (`simulation.md`, the deer). |
| 7 | **The journal** | the player's own pins | reflective | Not a world output — a *read* surface for the bone-thrower. Listed because it is often mistaken for one. |

## The audit rule — PROPOSED

Every simulated quantity must be traceable to **at least one consumer**, named. If it cannot be, one
of three things is true, and all three are fine:
1. It is a **hidden driver** — legitimate, but then it must be cheap, because nobody will ever see it.
   (Pressure fields, tempo clocks.)
2. It should be **coarsened** until it costs nothing — the conservation gate already permits this.
3. It should be **cut**.

The rule is not "everything must be visible." It is "we must know which of the three each thing is."

## Verify by mock, not by argument

Consistent with how terrain was settled: a claimed consumer is a hypothesis until a mock shows a
player actually consuming it. The terrain work established the pattern — the LOD stress test
overturned a reasoned recommendation on measurement (`mocks/LOD-STRESS-FINDINGS.md`), and the
splice `--selftest` caught index aliasing that looked correct in every log.

Cheap consumer probes worth building before committing to the systems behind them:
- **Does the player read faction state off bodies (#2) at all?** Stage the same settlement at three
  pulse phases; see whether the difference registers without text.
- **Does rumor provenance survive the trip (#3)?** Plant one fact three regions away and see whether
  a player can trace it back — this is the "are returning draws legible as consequences?" question
  from `draws.md`, and it is testable in isolation.
- **Do traces read as consequence (#4)?** Put a player's own traded object on a body and observe
  whether it registers as *theirs*.

Each is a small scene, not a system. If a probe fails, the machinery behind that consumer is not
worth building at full fidelity — which is the point.

## Anti-tree note

Authored trees (dialogue trees, behaviour trees as content, quest graphs) are rejected on scope: the
hand-authoring cost scales with branches and the project cannot pay it. The established alternative
is already in use twice — **precondition-tagged pools selected at runtime against actual state**
(`.decisions/dialogue.md` bake, `simulation.md` ending-vignette assembly). No nodes, no traversal,
no authored edges: content is tagged with what must be true, and selection is a seeded pick against
live facts. Consequence systems should reuse this shape rather than growing a graph.

Extrapolation and interpolation are likewise already solved in design and should not be reinvented:
seeded softmax realization expands coarse facts into detail deterministically, and the conservation
gate collapses detail back without resampling (`simulation.md`).
