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

**Half-baked, not adopted:** rumor spread, sound, light, fire, and weather fronts might all be the same generic operator (emit at a point → attenuate by a medium property → threshold-detect at receivers), just parameterized differently per channel. Genuinely unsure whether unifying them saves complexity (their propagation shapes differ enormously — light is instant/isotropic, rumor is slow/route-constrained) or just adds an abstraction nobody asked for. Flagged for whoever wants to chase it, not committed to.

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
