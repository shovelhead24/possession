# Possession — Diegetic Tools & QoL

New area doc (2026-07-22). Core thesis: any convenience that would normally be a HUD element must instead be a physical, ownable, discoverable tool. Extends the Fern Rule (interaction fidelity ≤ visual fidelity × system importance) and the knowledge pyramid's no-omniscient-map precedent into a general UI law.

## Diegetic-Tools-Not-HUD — PROPOSED (2026-07-22, strong)

- Convenience earns a body. Zoom → binoculars. Waypoint-bearing → compass. Dialect legibility → translator. If it can't be held, dropped, or lost, it isn't real enough to keep.
- **Retroactive confirmation:** the journal (knowledge.md) already followed this rule before it had a name — a physical pin-book instead of a quest-log HUD.
- Tools are found in the world (loot, trade, ruins), never quest-rewarded — consistent with the no-missions law.

## Worked Tools

- **Binoculars/spyglass** — no new mechanic, a handheld interface to the existing `observe(vantage, time, weather)` operator (knowledge.md). Plausible dual-purpose as a combat scope.
- **Translator/codex** (tier 2–3) — extends which baked dialogue variants are legible as you move along the arc's dialect gradient (factions.md "placename gradients"). A consumer-side filter over existing dialogue-bake output; no new fields needed.
- **Compass/sextant** — bearing + distance to the player's *own* journal pins only. Deliberately respects no-omniscient-map: it orients you toward what you decided mattered, never toward what the world would otherwise reveal for free.
- **Night-vision/lowlight tool** (tier 2–3, gate carefully) — must not arrive before the wolves moment does its job; tier-gating night capability is how "you are prey" stays true until the design wants it to stop being true.

## Tools vs Consumables

Two different economies: **tools** are permanent, ownable, occupy the "what can I carry" NG+ question (vision.md). **Consumables** are single-use (flares, a one-shot signal device) and are the disposable half — not yet designed, flagged for later.

## The Replay-Value Thesis

Pairs with same-seed NG+ (`.decisions/ending.md#ending-postcredits-deferral`): mastery is route/acquisition-order knowledge, not a stat curve. "I remember the spyglass is on that cliff" is the entire reward loop for a second playthrough — the world must stay knowable for foreknowledge to be worth anything, which is exactly why the seed doesn't change.

## A Third Ladder

Alongside the transport ladder (world.md) and the progression tiers (progression.md), tools form a **perception ladder** — what you can *know at range* grows the same way what you can *reach* grows. The hookshot (moments/hookshot.md) was always this pattern's flagship instance, just not yet generalized.

## Open Questions

- Which HUD elements convert first for the first slice (brief §9) — does the deer/wolves/ridge slice need any tool at all, or does it deliberately ship with none?
- Tool loss on death — does dying cost a tool, or are tools death-safe (only consumables and facts are at stake)?
- Durability/charges on tools, or permanent once found?
