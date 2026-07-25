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
