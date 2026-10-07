# Possession — Co-op

"Couch co-op first" is a non-negotiable (docs/vision.md) — and it's the one that compounds every other cost. Tracking issue: [#3](https://github.com/shovelhead24/possession/issues/3).

## What's Settled

- Couch co-op first. Local, same screen, from the start — not a post-launch port.
- Two protagonists with asymmetric knowledge (RE2 structure): one crashed in wilderness knowing nothing, one witnessed the city destruction and is already moving.

## Open Questions

- **What does co-op mean, mechanically?** Simultaneous split-screen with both protagonists? Two solo campaigns that interlock RE2-style? Both? This is the first thing the brief has to settle — everything else here depends on it.
- **Split-screen cost** — two viewports ≈ double draw calls on hardware that's already the constraint. Needs a measured spike (issue #8's benchmark scene should test a two-viewport variant).
- **Streaming for two cameras** — current terrain streams around one position. Divergent players = two stream centers or a tether distance.
  - **Backprop 2026-07-22 (from geography.md):** the two protagonists' *narrative starts* (crash region and THE city, ~3–8% of arc apart — potentially 60–160 km) exceed any plausible shared-origin tether. Day-one co-op therefore requires either per-viewport origin frames (substrate.md flags this as D5's problem) or a narrative concession (P2 starts nearer the crash than the fiction implies). The rendering architecture and the story geography are now explicitly coupled — resolve together in D5, not separately.
- **Input** — KB/M + gamepad mix; PS5 controller support already exists from April.
- **Story moments in co-op** — moments are built around *witnessing* (one player watches the city burn; the other is elsewhere). Do moments fire per-player? What does the other player see?
- **Ending agency remains open:** unilateral shared departure is a candidate, with legible approach and deliberate activation required. Test what both players understand before settling consent or interaction details. See `.decisions/ending.md#ending-shared-agency`; shared facts and interleaved memories remain.
- **Solo play** — is the second protagonist AI, absent, or swappable?
  - **Drop-in join, resolved (2026-07-22):** a player joining an already-progressed solo save takes control of an existing nearby NPC entity — proximity-weighted, availability-filtered selection reusing the `realize()` pattern (`select_possession_host`, operators.md) — rather than spawning a character or waiting in an idle companion slot. Distinct from **day-one co-op**, which still starts both players as the authored Protagonist One/Two. See `.decisions/coop.md#coop-join-npc-possession`.

## Not in Scope (yet)

- Network multiplayer — explicitly out of scope in April planning; nothing since has changed that.

## Shared discovery — adopted 2026-09-10

Asymmetric knowledge should create useful conversation: one player recognises a place, explains an observed change, or notices an opportunity the other missed. Design for both to contribute; neither is a permanent guide or passenger. The knowledge difference must come from what they plausibly witnessed, not artificial withholding of basic controls or clarity. Screen visibility need not equal the character's recorded knowledge; the shared conversation is part of couch play.

Include co-op in the 30-second loop discussion: what does each person perceive, choose and do, how can their actions combine or disagree, and what remains engaging while a partner is occupied? Specific mechanics are still open.
