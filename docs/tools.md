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

## Regional Gating (2026-07-22)

Tool and vehicle availability is gated by a region's `recovery_band` (civilization.md) — bows/improvised melee in regressed zones, trucks/horses in frontier zones, boats/aircraft/drones/mortars/NVGs only near a surviving enclave. Not random placement: the tech spectrum is a bake-time causal field, same discipline as biomes.

## A Third Ladder

Alongside the transport ladder (world.md) and the progression tiers (progression.md), tools form a **perception ladder** — what you can *know at range* grows the same way what you can *reach* grows. The hookshot (moments/hookshot.md) was always this pattern's flagship instance, just not yet generalized.

## The Artery Rule (2026-07-22)

If free expression is the heart, tools are the arteries — so **a tool only earns a slot if it has at least two unscripted uses**, discovered through the systems (fire, tempo, knowledge, animals, factions, terrain), never assigned by content. One-use tools are keys wearing costumes; keys are missions wearing costumes. The second use is never tutorialized — finding it *is* the content.

## Catalog Sketch — goodies × vignettes (2026-07-22, examples not commitments)

Grouped by recovery band (civilization.md); every entry lists intended use → at least one emergent use.

**Regressed band:**
- **Spear** — hunting reach → plant it in a river ford as a deer-drive stake; throw it to spook a wolf pack off a kill you want.
- **Baseball bat** (pre-collapse relic — someone's heirloom) — melee → knock burning debris away from a structure you want saved; the *pathos object*: a child's sports gear as a war club says centuries of decline without one line of dialogue.
- **Fishing rod** — food → cast across a gap to snag something unreachable; fish at dawn beside an NPC who talks more freely to someone holding a rod (dialogue selection reading context).
- **Fire (torch/embers)** — light/warmth → drive game toward a cliff; burn a wooden bridge behind you mid-pursuit; start a grassfire upwind of a battle you were only supposed to watch.

**Frontier band:**
- **Binoculars** — `observe()` at range → read a battle's tempo from a ridge before choosing a side (or not choosing); spot which chimney smokes at dawn to learn who's home.
- **Horse** — transport → a knowledge tool: it panics before you see the wolves (fauna fields feeding a tempo signal you can *feel through the saddle*).
- **Truck** — hauling → mobile cover in a firefight; ram a palisade gate; the beach-joyride-flamingos vignette (world.md) is this band's postcard.
- **Flare** (consumable) — signal → decoy: fired far away, watchers reposition toward it (faction knowledge models reacting to false information — lying through the rumor physics).
- **Saloon piano** (stretch, but the principle) — nothing → tempo writer for a whole room; play badly and watch the mood consumer shift. Ambient tools count.

**Enclave band:**
- **NVGs** — night sight → *reads the night-sky map better than eyes* (knowledge.md: night is the acquisition channel — enclave tech literally accelerates the knowledge pyramid); gated late so the wolves moment keeps its darkness.
- **Drone** — scouting → remote `observe()` decoupled from your body: your K-pyramid grows where you aren't; bait air-defense nodes into revealing themselves by flying it where you'd rather not walk.
- **Mortar** — indirect fire → the first weapon that works *entirely off the knowledge pyramid*: you shell coordinates you know, not targets you see. Stale K4 = shelling yesterday's camp. Knowledge staleness becomes ballistics.
- **RIB / submarine** — water traversal → the sea (world.md) as a knowledge shadow: approach any coast unseen; the sub is the only tool that hides from the *night sky's* omniscience in reverse — nobody can watch you from above.
- **Radio** (if enclave has one) — comms → rumor injection at range: SignalAmplification without walking. The knowledge pyramid's first broadcast-speed writer — handle with care, may be too strong.

**Ancient tier:**
- **Hookshot** — traversal (moments/hookshot.md) → vertical hunting, wall ascent, yanking a rider off a horse (?); the flagship, already designed.
- **Wall transit** (reactivatable, lore.md) — fast travel → moving *cargo* and *people*: evacuate a settlement ahead of a negotiable inevitability the director scheduled (the hail-mary artery — deliverable by transit what could never be delivered on foot).
- **Air-defense node** (reactivatable) — area denial → pointed at the *mid-game armada's* landing craft? Probably futile (lore.md: armadas intercept the interceptors) — but "probably" is where hail marys live.

**Round 2 additions (2026-07-22):**
- **Snare line** — passive hunting → perimeter alarm at night (a micro-clock interrupt while you sleep); catch the wolf that's been tracking *you*.
- **Hunting horn** — call/drive game → audio lie: a horn where no army is, heard by faction knowledge models (the flare's acoustic sibling, cheaper than the radio and probably safe where the radio isn't).
- **Bicycle** — silent personal transport, no fuel economy → tech archaeology on wheels: where a bike is *usable* reveals road quality, which reveals recovery band, which is knowledge acquired through your legs.
- **Glider** — wall-foot updraft descent (highlands → plains) → the poor man's sky survey: altitude is K-gain, and a one-way trip is a commitment device — you can see where you'll land but not how you'll get back.
- **Smoke pot** — combat cover → writes a visible false claim into everyone's `observe()` for a mile around; wind-dependent, so terrain knowledge gates the lie's quality.
- **Rope** — climbing aid, binding → flagged honestly: rope physics is a notorious engineering tarpit; keep uses abstracted (anchor-point verbs, not simulated slack) or cut it.

## Ranking — author's cut (2026-07-22)

Criteria: systems touched × buildable cheapness × theme fit.

1. **Mortar** — fires at your *knowledge*, not your sight; staleness becomes ballistics. Three systems for the price of one weapon.
2. **Horse as felt tempo-consumer** — panics before you see the wolves. Empathy hardware on a potato budget.
3. **Flare as decoy** — a lie injected into faction knowledge via the same physics as truth. Nearly free to build.
4. **Wall transit as hail-mary artery** — evacuation-scale delivery the director's scheduled inevitabilities can't ignore. Expensive, but it's the tool that touches the arc itself.
5. **Glider one-way commitment** — cheap, spatial, and produces stories by geometry alone.

**Flagged weakest, honestly:** radio (probably breaks knowledge-pyramid pacing — quarantined until proven safe); rope (tarpit unless abstracted).

**Saloon piano — pardoned by user decree (2026-07-22):** ranked weakest systemically, kept anyway — as the flagship of an emergent-comedy principle: *comedy obeys the same laws as everything else or it isn't funny here.* No authored jokes, no wacky NPCs, no joke quests (impossible anyway — no missions). The humor budget is entirely systems playing ridiculous inputs completely straight: the piano as a legitimate tempo-writer for a room, the boar derailing a solemn negotiation because pressure said so, flamingos betraying your ambush. Surprise survives because nothing is *authored to be funny* — the simulation just refuses to break character. Same law as the deer moment, pointed at absurdity instead of awe.

## Open Questions

- Which HUD elements convert first for the first slice (brief §9) — does the deer/wolves/ridge slice need any tool at all, or does it deliberately ship with none?
- Tool loss on death — does dying cost a tool, or are tools death-safe (only consumables and facts are at stake)?
- Durability/charges on tools, or permanent once found?
