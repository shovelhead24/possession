# Possession — Perception & Interaction Resolution

New area doc (2026-07-25, live brainstorm — PROPOSED, not decided). Answers: how does an entity "notice" a physical event, and how does that noticing cascade into social/tempo consequence? Sits alongside LayerBuf and TempoBuf, consuming both — not a third grid.

## Core Model — PROPOSED

Each **Tier 3+ realized entity** (Fern Rule — background crowd never gets this) carries a perception model:
- **Foveal vision** — narrow cone, registers detail + intent (you see *that a friend threw this at you*)
- **Peripheral vision** — wide cone, registers motion/presence only, not intent (you see *something moving*, hand reflexively catches unless under pressure)
- **Hearing** — threshold distance, driven by existing `SignalAmplification` (propagation) and `InfoOpacity` (biome muffling) fields — no new fields needed

An event (thrown object, sound, impact) is checked against nearby entities' perception models to produce a **registration quality**: full witness / peripheral glimpse / audio-only / impact-only-unexplained. This quality is a K2-style **fact with provenance** — same shape as rumor — and is what everything downstream keys off, not the raw physical event itself.

## Worked Example — Throwing an Object to an NPC (2026-07-25)

- **Not perceived, then hit:** registers as impact-only-unexplained. Emotional/relationship consequence differs sharply from a witnessed toss — same physics event, different fact quality, different downstream reputation claim (factions.md's reputation-as-inverted-knowledge-pyramid).
- **Witnessed + accurate throw:** clean mid-air catch. Accuracy is modulated by tempo/intensity at throw time and by `InfoOpacity` (night reduces it) — reused fields, no new ones.
- **Reverse case — object enters player's peripheral vision:** reflexive auto-catch, *unless under pressure* — this is TempoBuf's existing "aggressive play → worse decisions" pattern (combat.md), pointed at the player's own reflexes instead of an enemy's. Tempo modulates the resolver's success rate; it does not run the perception check itself.
- **Downstream:** politics (does this faction/context permit it), enforcement (a witnessing guard runs their *own* perception check → their own intention) — both already-existing factions.md/R-stack machinery, unmodified.

## Signal vs. Simulation Fidelity (2026-07-25)

Distance-based throttling is real but must split into two channels, not one:

- **Simulation channel** — how richly a region's causes/consequences are computed (NPC count, AI decision depth, physics detail). Legitimately throttles with distance/tile-size — this is just the existing three-tier fidelity system and TempoBuf's regional clocks, nothing new.
- **Signal channel** — a cheap, low-dimensional emission (brightness, plume height, loudness) computed once at an event's source and read through the *existing* `observe()`/K1 sky-visibility machinery, propagating effectively instantly regardless of the source region's simulation fidelity. **Precedent already proves this works:** moments/armada.md and moments/city_destruction.md are exactly this split — nobody simulates the armada's full arrival for a distant witness; what arrives is a shadow crossing the sun. An explosion is the same shape: the cause stays at whatever fidelity tier its region has; the flash/plume/boom is a signal, decoupled from that tier entirely.

**A grid still earns a narrow role here:** broad-phase visibility culling (line of sight over the heightfield, above the curve horizon, not haze-blocked) to cheaply determine which regions/players could even perceive an emitted signal — before doing the expensive per-observer check. This bounds *who checks*, not *how much is simulated*.

**Resolved 2026-07-25 — three channels, three speeds, not one operator:**

| Channel | Speed | Mechanism | Needs a grid? |
|---|---|---|---|
| Light | ~instant (6.7ms ring-wide) | visibility check only | No |
| Sound | 340 m/s — genuinely delayed (a 50km boom arrives ~150s late; the real lightning/thunder gap, playable at ring scale) | analytic `distance ÷ speed`, scheduled once | No — simpler than a grid |
| Consequence/pressure | hours–days | fact → R1 pressure, propagates via the existing region-adjacency graph (factions.md's refugee-wave/upstream-dam dynamics) | Graph, not a spatial grid |
| Rumor/social | variable, **infamy-weighted** — bigger news travels faster/further through the chain topology, same way urgent news outruns gossip in reality | graph-walk over settlement/route connectivity, per-edge speed from local infrastructure (`tech_level`) | Graph, not a spatial grid |
| Weather | wind speed, continuous field advection along `spinward_wind` | reuses `wind_exposure` (L2) — a moving front, visibly approaching, no per-region authoring needed | **Yes** — the one case that's genuinely grid-shaped |
| Disease | contact/chain-graph, no sensory signal at all (never seen from a distance — only rumor or direct K4 observation) | same graph as rumor, disease-specific params; severity modulated by `tech_level` (civilization.md) — poor sanitation in regressed bands worsens outbreaks; triggers the same refugee-to-pinch-camp dynamic as a scheduled evacuation | Graph, not a spatial grid |

**Verdict on "one generic solution":** the *vocabulary* (emit → attenuate → threshold-detect) is real and worth keeping as a shared mental model — it's the same family as diffusion/epidemic math, not a coincidence. The *implementation* should stay as several small, naive, topology-specific engines (broadcast / analytic delay / graph-walk / field-advection) rather than one generic operator — forcing a shared implementation across genuinely different topologies (isotropic-instant vs. contact-graph vs. wind-advected field) would mean parameterizing away the real differences, which is what "generous interfaces, naive engines" warns against. Naming the family pays off conceptually (recognize the shape fast next time); it doesn't pay off as shared code.

## Lies Carry Their Motive (2026-07-25)

A deliberate false K2 claim isn't just content with provenance — it's an **action (R3) serving an existing intention (R2)** the liar already holds (fear of punishment, protecting an ally, manipulating the player for a resource). That intention already exists in the system; it just isn't linked to the lie yet. **Small, precise addition:** a deliberate-lie K2 claim carries a back-reference to its generating intention. Discovering *why* someone lied — not just that they did — becomes its own discoverable fact, feeding the journal or surfacing that a "misattributed reactivation" (factions.md) was deliberate cover, not an accident.

This is the same mechanism, one hop deep, as the bigger causal-chain idea in lore.md's "Recontextualization" note — a fact pointing back to what generated it. Worth keeping the two connected rather than designing them separately.

## Recompute Priority (2026-07-25)

A region's simulation tick priority is a function of three things, not one: **distance to player**, **distance to the event**, and **time since the event** — not just player proximity. This doesn't need new machinery: `realize()`/`summarize()`'s conservation gate already reconciles a region's accumulated facts into a consistent local state whenever a player finally arrives, regardless of how long it was ticking coarsely in the meantime. "Catching up" is already the job that mechanism does.

## Critiques / Open Considerations

- **Naming/layer separation:** perception must NOT be folded into TempoBuf. TempoBuf is coarse-by-design (arc/regional/encounter/micro, pacing-timescale). Perception is per-frame, per-entity, geometry-heavy. Keep them separate: perception *consumes* tempo's intensity output as a modulator; it isn't part of the clock hierarchy.
- **Cost discipline:** full perception checks are Tier 3+ only (Fern Rule). Ambient/background crowd (civilization.md) never runs this — they can't be meaningfully thrown at anyway.
- **Determinism:** "fluke" outcomes (a lucky catch despite imperfect conditions) must stay a seeded function of (accuracy, perception state, world seed, fact_version) — never true unseeded randomness, per "observation never rerolls the world."
- **No new grid required:** vision cones/hearing are continuous per-entity geometry, not tile lookups. Resolves the earlier grid-unification question — this system sits alongside LayerBuf/TempoBuf rather than requiring either to be finer-grained.

## The General Principle

One resolver (perception quality × accuracy × tempo × context), reused across many surface interactions — catching a thrown item, noticing a lie, spotting a fire, a guard clocking a theft — rather than bespoke logic per interaction type. Direct extension of the artery rule (tools.md: two unscripted uses minimum) to NPC interaction generally.

## Open Questions

- Exact vision cone angles (foveal vs. peripheral half-angles) — tuning value, not set here.
- Does hearing distinguish sound *type* (a thrown-object whoosh vs. a shout) for registration quality, or is it binary heard/not-heard?
- Should peripheral-only registration ever upgrade to full witness retroactively (turning your head *after* noticing motion)?
