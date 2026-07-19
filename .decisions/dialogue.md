# Dialogue / NPC Voice

### dialogue-baked-only — LLM dialogue generation is bake-time only; zero runtime LLM
**Date:** 2026-07-19
**Status:** active
**Decision:** All NPC dialogue is generated offline as a bake layer (LayerBuf-grounded utterance pools, arc-phase branches baked for the finite drumline, rumor variants at graded accuracy) and validated by bake gates (knowledge radius, banned lore, tier anachronism). Runtime does selection only. No runtime LLM inference in the shipped game, ever.
**Why:** Potato hardware target, latency, and ungateable output rule out runtime generation; bake-time generation gets grounding, validation, and voice control for free inside the existing pipeline. Generation pipeline choice (local vs API, cost/quality) deliberately open pending R7 research.
