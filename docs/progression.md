# Possession — Progression

Three tiers, from prey to power (docs/vision.md). Least-developed system — nothing in code yet; this doc is the planning surface. The runtime machinery that *delivers* progression (intentions, tempo, realization, arc director) lives in [simulation.md](simulation.md).

## What's Settled

1. **Survival** — prey, no power. Crash, stripped, hunted at night. Player starts with nothing, including weapons.
2. **Medieval** — people, factions, bows. Settlements, the army, human-scale conflict.
3. **Ancient Alien** — tech that changes everything. The hookshot (Moment 12) is the flagship: first swing across a canyon.

The arc runs crash → stripped → hunted → survivor → discover people → climb → relay → armada → choice.

**The tree is RECOVERY, not invention** (`.decisions/progression.md#recovery-not-invention`, ratified 2026-08-17). The player arrives spacefaring and is stripped of it (`the-toll`, vignettes.md), so climbing the three tiers is getting *back* to a baseline already seen — a spear is what you use when they took your rifle, not tier-one naïveté. Consequences: tiers gate on **re-acquisition** (found/salvaged/traded/taken + faction trust + geography), never a research tree; there is **no deep craft-from-scratch layer** (recovery answers the crafting Open Question below); the immediate FP carbine is dev-only, replaced when the stripped start lands; and **knowledge leads capability** — you keep knowing what is possible after losing the means.

**The transport ladder is the progression ladder's shadow** (world.md): walk → horse → vehicle/boat → flyer → ancient rim transit — each tier redefines "far" and what you can *know* (knowledge.md).

**No missions, ever** — progression is self-directed via the journal (pins as player-authored goals) plus the world's opportunity gradients. See simulation.md for the architecture and the arc director's inevitability rules.

## Open Questions

- **What gates the tiers?** Settled shape: **re-acquisition** of capability, not research (`.decisions/progression.md`) — found tech, faction trust, geography (pinch points — world.md). Still open: the *specific* gates, and whether tier progression is per-player in co-op.
- **Is there an inventory/crafting layer?** Settled: progression is **acquired capabilities**, not a craft-from-scratch economy (`.decisions/progression.md`) — you recover a rifle, you don't build one. Crafting is bottom-tier improvisation only (fire/shelter/haft a spear), kept shallow so it doesn't fight the witnessing tone. Still open: exactly how shallow the Survival-tier survival loop runs.
- **Traversal as progression** — "if you can see it you can reach it" may be *earned*: reachable at tier 1 by walking, at tier 3 by hookshot. Or must everything be walkable from the start? Shapes the terrain plan (issue #1).
- **Death and saves** — what does dying cost at each tier? Couch co-op revive vs solo?
- **The stripped start vs the FP carbine** — settled framing: the immediate carbine is **dev-only test loadout**, and the real arc opens stripped (`.decisions/progression.md`). Still open: the *trigger* — when in the build the stripped start replaces the test loadout.
- **Asymmetric progression** — protagonist two starts "already moving" with knowledge protagonist one lacks. Do they also differ in capabilities?

## Tone Guard

Progression serves witnessing, not power fantasy — the biggest things still happen without you (docs/vision.md). Tier 3 makes you mobile, not mighty.
