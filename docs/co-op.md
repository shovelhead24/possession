# Possession — Co-op

"Couch co-op first" is a non-negotiable (docs/vision.md) — and it's the one that compounds every other cost. Tracking issue: [#3](https://github.com/shovelhead24/possession/issues/3).

## What's Settled

- Couch co-op first. Local, same screen, from the start — not a post-launch port.
- Two protagonists with asymmetric knowledge (RE2 structure): one crashed in wilderness knowing nothing, one witnessed the city destruction and is already moving.

## Open Questions

- **What does co-op mean, mechanically?** Simultaneous split-screen with both protagonists? Two solo campaigns that interlock RE2-style? Both? This is the first thing the brief has to settle — everything else here depends on it.
- **Split-screen cost** — two viewports ≈ double draw calls on hardware that's already the constraint. Needs a measured spike (issue #8's benchmark scene should test a two-viewport variant).
- **Streaming for two cameras** — current terrain streams around one position. Divergent players = two stream centers or a tether distance.
- **Input** — KB/M + gamepad mix; PS5 controller support already exists from April.
- **Story moments in co-op** — moments are built around *witnessing* (one player watches the city burn; the other is elsewhere). Do moments fire per-player? What does the other player see?
- **The ending is resolved, not open:** either player alone can end the session for both (unilateral, no consent gate — `.decisions/ending.md#ending-coop-unilateral`, moments/the_return.md). A template for handling asymmetric-knowledge moments generally: shared facts, interleaved per-player knowledge, no negotiation UI.
- **Solo play** — is the second protagonist AI, absent, or swappable?
  - **Drop-in join, resolved (2026-07-22):** a player joining an already-progressed solo save takes control of an existing nearby NPC entity — proximity-weighted, availability-filtered selection reusing the `realize()` pattern (`select_possession_host`, operators.md) — rather than spawning a character or waiting in an idle companion slot. Distinct from **day-one co-op**, which still starts both players as the authored Protagonist One/Two. See `.decisions/coop.md#coop-join-npc-possession`.

## Not in Scope (yet)

- Network multiplayer — explicitly out of scope in April planning; nothing since has changed that.
