# Possession — planning index

Current baseline: 2026-09-12, adopted from the user's design discussion. Design intent is not an implementation claim. Earlier brief preserved in [archive](archive/brief-before-theatre-baseline.md).

## Read in this order

1. [Core conception](core-conception.md): ring-scale tactical run and gun, authored theatre, simple planning and scope boundaries.
2. [Campaign and player agency](campaign-and-agency.md): branching sectors, relay fortresses/FOBs, communications-dependent support and bounded local consequences.
3. [Information and companion](information-and-companion.md): physical interfaces, signal list, map proposals, AI capabilities and unresolved story role.
4. [First operation](first-operation.md): the proposed playable test and its ordered prototype/asset needs.

These documents explicitly distinguish decided direction, proposed implementation and open questions. They take precedence over incompatible older design proposals. The decision record is [.decisions/campaign.md](../.decisions/campaign.md); existing area docs carry applicability notices.

## Decided direction

- Simple mission planning followed by tactical run and gun; RTS-derived organisation supports the experience without requiring continuous unit micromanagement.
- Highly authored theatre-level story; local player influence exists within defined bounds. Story timing remains open.
- Branching ring sectors and captured relay fortresses becoming FOBs. No comms, no bombs: support requires communications.
- Objects as the primary interface and FOB-based mission planning. A stationary local holographic map is proposed, not yet ratified.
- An AI companion is wanted. Translation, exact powers and narrative centrality need design.
- Crude realism in the art; physical weapon dimensions and gameplay reach remain separate.

## Immediate priorities

The catalogue-wide asset worker is stopped and must remain paused while its remit is revised. Prototype the FOB map/projector, relay interaction and support-state feedback before commissioning finished meshes. Reuse existing combat assets to test two approach routes and a short authored aftermath. See [TASKS.md](../TASKS.md).

## Deferred, not erased

Medieval-first progression, broad tech trees/RPG simulation, catalogue completion and an exploration-only first slice no longer gate the combat prototype. Existing landing, quiet, co-op and ending material remains available for reconciliation with the authored campaign. No final plot rewrite, title rename, terrain redesign or new ring dimensions is authorised here.

## Technical and historical references

Use [.decisions/INDEX.md](../.decisions/INDEX.md) before reading relevant technical decisions. Terrain, rendering, co-op and hardware constraints retain their established authority. Prior area documents preserve useful implementation notes but their superseded progression, mission and map assumptions must not silently govern new work.

## Decisions next

Resolve the prototype's enemy behaviours and player movement/defence model; define a local-outcome contract for one authored beat; test FOB-only versus stationary local hologram access; establish companion access/translation limits; then agree production asset contracts and acceptance criteria. Campaign timing and Theatrics as a title remain open.
