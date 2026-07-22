# Co-op Mechanics

### coop-join-npc-possession — Drop-in co-op possesses an existing NPC, proximity-weighted
**Date:** 2026-07-22
**Status:** active
**Decision:** A player joining an already-progressed solo save takes control of an existing R2 NPC entity rather than spawning a new character or activating a pre-made companion slot. Candidate selection reuses the `realize()` pattern: proximity-weighted softmax over *eligible* nearby entities, where eligibility excludes narrative-anchor-tied and plot-critical NPCs. Human-only in v1 (possessing an animal entity considered and set aside — too strange for a first pass). Distinct from day-one co-op, which starts both players as the authored Protagonist One/Two from the landing.
**Why:** The player was never architecturally special (design-laws.md — the player is an ordinary R2 intention-holding entity); this makes drop-in/out co-op a natural consequence of that law rather than new machinery, avoids teleport-to-host or idle-companion hacks, and produces asymmetric knowledge for free — the possessed NPC has been simulated with their own history the whole time, so their knowledge pyramid already differs from the host's without any authoring.
