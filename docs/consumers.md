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

## Emitter/consumer topology — PROPOSED 2026-07-29

The consumer framing generalises: **every layer consumes from below and emits upward**, and the
player-facing channels above are just the last hop. Written out, three things become precise that
were previously fuzzy.

**There are two bufs, and they never talk to each other.**

- **LayerBuf** — space. Baked, L0–L7, a composable DAG. *The score.*
- **TempoBuf** — time. Live, four nested clocks (arc → regional → encounter → micro) plus a mixing
  rule. *The beat.* Deliberately **not** a mirrored layer stack: space composes ahead of time, time
  cannot.

`simulation.md` already names the junction you are reaching for: **the intention boundary** — "never
buf-to-buf: an entity reads space (where is possible) + time (when is ripe) and commits. Score, beat,
musician." So the special junction is at **R2 (intentions)**, where an entity reads both, not at the
director. Nothing ever wires LayerBuf to TempoBuf; entities are the only bridge.

**The common substrate is R0's fact tuple, not the director.** R0 already carries the Datomic note:
*one universal fact tuple shape across every system* — terrain edits, faction events, inventory,
knowledge — rather than bespoke per-system representations. That uniformity is what lets one generic
"why / since when" query work everywhere, and it is the true bottom of both stacks.

**The director is the opposite of a bottom layer.** R5 is *sparse and top-down*: it schedules facts
into R0 and sets tempo, and explicitly never commands entities. Intentions are distributed and
bottom-up; the director is a thin top-down writer. Calling it the common bottom inverts it.

### The player closes a loop, and is not simply "the top"

The player appears in the topology **three** times, which is why "top of both stacks" doesn't quite
land:

1. **As an emitter into R0** — actions become persistent facts, the only durable world mutations.
2. **As an R2 entity** — "the player as just another intention-holding entity, not a special
   customer of a content system" (`simulation.md`).
3. **As the terminal consumer** — the seven channels above.

So the architecture is not a stack with the player on top; it is a **loop that closes through the
player**:

```
player acts ──► R0 facts ──► R1 pressures ──► R2 intentions ──► R3 actions
   ▲                            (reads LayerBuf + TempoBuf here)        │
   │                                                                    ▼
   └────────── consumers (7 channels) ◄────── R4 encounters ◄───────────┘
```

**Returning draws are literally this loop closing** (`draws.md`). That is why they cannot exist early
— the loop has not gone round yet — and why they need no separate consequence system: they are what
the architecture does when it runs. Standing draws come from LayerBuf directly (baked, present from
the start); returning draws come all the way round.

**Audit consequence:** a quantity is worth simulating if it survives the trip to a consumer. Most
"consequence" bugs will be a break *somewhere on this loop* — a fact that never becomes pressure,
a pressure with no intention that reads it, an action that intersects no bubble — rather than a
missing feature. Debug the loop, not the symptom.

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
