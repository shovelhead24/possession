# Possession — Dialogue & NPC Voice

New area doc (2026-07-19 session). Core proposal: **LLM-baked dialogue** — offline generation as a bake layer, zero runtime LLM (potato hardware, latency, ungateable output).

## The Design — PROPOSED

**Dialogue is a LayerBuf consumer.** A bake pass reads world fields per settlement/NPC — water source (L1), biome (L3), roads/tolls/pinches (L5), ruins and history (L5), faction pressures — and generates each NPC archetype's *utterance pool*, grounded in what the world actually is. The barkeep complains about the pass toll because the road graph genuinely routes through the pinch.

**Same systems plus noise:** intent templates (grumble, rumor, boast, warning, directions) × per-NPC voice noise (culture_seed + personality vector) → original-sounding surface text over systemic substance. Runtime selection is cheap lookup indexed by (pressure state, arc phase, reputation, weather); the *system* stays reactive while the *text* stays baked.

**Bake gates extend to words:**
- Knowledge radius: NPCs only reference places/facts within plausible reach — InfoOpacity/SignalAmplification reused as *knowledge topology*; rumor accuracy decays with distance
- Banned lore: nobody explains the deer. Hard gate.
- Tier/anachronism checks; tone pass via LLM-judge
- Hallucinated grounding caught like an uphill river — validator, coordinates, fail the bake

**Arc branches are finite, so bake them:** the drumline (fixed beats) enumerates a small set of arc-phase pools ("before the city" / "after"). Negotiable inevitabilities bake both branches — the hail-mary timeline's dialogue ships in the data whether or not any player ever hears it.

**Rumors close the bone-thrower loop:** the leak mechanism *is* dialogue selection — baked rumor variants at graded accuracy, selected at runtime by pressure state and the player's journal pins (see simulation.md).

**Storage:** trivial. 200 settlements × 20 NPCs × 50 lines ≈ 200k lines ≈ ~20 MB text.

## Agency & Authoring Scale (the resolution)

Player agency lives in interceptable simulation preconditions; the world's *response* is systemic — pressures, prices, rumor selection — never per-choice hand-written content. Authoring cost stays flat because accommodation is selected, not authored; baked branches exist only where the finite drumline forks.

## Open Questions

- Generation pipeline: local model vs API batch; cost/quality per 100k lines; regeneration cadence when upstream layers change (dialogue is a downstream bake layer — cache rules apply)
- Voice consistency per culture: few-shot exemplars per culture_seed; how many cultures before sameness shows
- Dynamic slot-filling at runtime (place names, current prices) vs fully baked lines — where stiffness is acceptable
- Delivery: text-only vs TTS-baked audio (storage/tone tradeoff; potato decode cost)
- How tier-1 (pre-people) handles voice: none? found writing? the pilot's object?
