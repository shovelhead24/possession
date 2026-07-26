# Possession — Aesthetic & Directorial Philosophy

Area doc (2026-07-26). The felt, sensory identity of the game and how it's staged. Distinct from rendering.md (the *technical* fidelity baseline — GL Compat, ~2001 texel budget) — this doc is about *mood and craft*, the layer that carries authorial meaning since the design laws bar the systems from editorializing (intensity-not-valence). Cinematography here is environmental/playable, not editorial — see "Directorial Constraints" below.

## Ordering: theme → (aesthetic + direction), in parallel

Theme comes first and is locked (vision.md: arrived late to something enormous / indifferent ring / witnessing over heroism). Aesthetic and directorial philosophy both fall out of theme *together*, each disciplining the other — not sequentially. Working definition (via a 2026-07-26 discussion): **theme** is the idea; **devices** are the literal tools (lens, light, blocking, sound); **aesthetic** is the mood that emerges when devices work consistently — it makes the theme *felt, not understood*. Execution is discovered through the tech constraints (the Millstreet look emerged from real DEM + fidelity budget + honest-curve, not from a mood board), so we fix *pillars* now, not finished frames.

## Aesthetic Pillars — PROPOSED (the non-negotiable felt qualities)

- **Silhouette reads before detail** — coarse textures (rendering.md) mean shape carries identity; every important object must be recognizable as a black cutout.
- **Colour does the emotional work** — since geometry and texture are low-fi, palette and light are the primary emotional channel, not surface detail.
- **Emptiness is a feature, not a lack** — negative space, silence, and low density are load-bearing (see "The Emptiness/Life Axis").
- **The sky is the most important surface in the game** — the ring curve, the far side, the night lights, the day/night terminator: more screen time and emotional weight than the ground. (Reinforced by knowledge.md's "the air is the horizon" and the sky-as-map decision.)

## The Emptiness/Life Axis — the sharpest tension (2026-07-26)

External critique (a Gemini analysis of Halo CE Level 2) argued Halo's awe *comes from* emptiness — the "liminal ghost town," silence foreshadowing a sterile superweapon — and that adding wildlife would *ruin* it, turning haunting emptiness into Avatar's Pandora. This directly challenges our Earth-zoo design (wildlife.md, lore.md). Taken seriously, the resolution:

- **Different route to the same eeriness.** Halo's uncanny is *absence* (everyone died). Ours is *presence that shouldn't be there* (deer too normal, anachronistic megafauna, a zoo with no keeper). Both are uncanny; ours needs life to achieve it.
- **The real risk is losing both.** A lush, teeming ring stops being haunting-empty *and* stops being uncannily-wrong — it becomes a nature preserve. That failure is real and must be actively avoided.
- **Rule 1 — sparse and uncanny, never lush.** Every creature reads slightly wrong and is rare enough to be an *event* (the deer moment only works because it's rare — moments/deer.md). Low density is the aesthetic, not a hardware compromise.
- **Rule 2 — emptiness is the opening aesthetic; life is what you discover.** Tier 1 (crash/wilderness/prey) leans fully into Halo's haunting sparseness — you are alone. Density climbs with the progression tiers toward the living enclave. Maps onto the existing tier ladder for free.
- **Phrase to keep:** "a synthetic zoo waiting for an operator" (Gemini's, offered as criticism) *is* our lore.md thesis — the ring is a zoo whose builders vanished. The critique accidentally wrote our premise.

## Directorial Constraints (from theme, non-negotiable)

- **Almost no cuts.** The camera is the player's hands nearly always (landing unbroken, no cutscenes per the moment docs). This bars most editorial film craft (shot/reverse, cutting on action, traditional montage) — the deliberate exceptions are the ending (moments/the_return.md) and marketing trailers.
- **What's left is environmental/playable cinematography:** lighting, haze, composition through level geometry (draw the eye, never force it — the Half-Life discipline), sound design, camera *behavior* (drift/hold/idle) not camera *editing*.
- **Style carries the authorial weight the systems can't.** Because intensity-not-valence bars the simulation from ever judging, craft (the shot, the silence, the song) is the *only* channel authorial meaning travels through. Where the world refuses to judge, style must show up and mean it — or it reads as a shrug (the Far Cry 2 failure, vision.md).

## Palette — DECIDED 2026-07-26

**The target is Halo CE Level 2's cliff-overlook vista**, precisely — and this corrects a wrong assumption baked into the tone-reference list. It is *not* the cold 2001/T2 blue-grey. It's **serene, hazy, pastoral**: soft desaturated blue-greens on the hills, heavy atmospheric perspective fading distance to cyan/teal, warm gold sunlight cutting through, purple-grey far mountains, clean cool silver structures against the softness. The eeriness comes from *context* (this inviting place is a machine), not from a cold palette. Serene surface, uncanny meaning.

**Tech convergence (not coincidence):** this look is atmospheric-perspective-driven — distance dissolving into haze — which is exactly the deep-cross-section, surface-concentrated atmosphere + haze system already decided (`.decisions/world.md#atmosphere-density-falloff`, knowledge.md "air is the horizon"). We chose the haze model for the far-side seam and the landing threshold; it happens to be the precise mechanism that produces the Halo CE vista. The palette is reachable with committed machinery.

**Halo Reach Forge World** is a *second, separate* reference — for far-field **detail density**, not palette: its distance is full of legible intriguing silhouettes (waterfalls, arches, distant landmasses). That's an *anticipation* note, not a colour one — see "Anti-Boredom" below.

## Anti-Boredom & The Faction/Emptiness Reconciliation — 2026-07-26

The core worry: at 2,000 × 50 km, eerie emptiness (which sparsity gives us — see the Emptiness/Life Axis) risks becoming *repetitive boredom*, and factions/RPG density seems to clash with it. Both resolve together:

- **Emptiness is a rhythm, not a uniform field.** Evenly-sparse is the failure (No Man's Sky empty-planet, Far Cry 2 flat repetition). The form is long sparse traversal *punctuated* by rare dense nodes — Shadow of the Colossus, Elden Ring's rides between legacy dungeons, Death Stranding. Sparsity is what makes arrival *land*; it sets content up, it isn't the absence of it.
- **Factions are islands of humanity in indifferent vastness — witnessed, not inhabited.** Not a bustling Skyrim; you come upon a settlement after hours of solitude, observe from outside the firelight (settlement_night.md already frames exactly this), maybe touch it, leave back into emptiness. Fits all three constraints at once: witnessing-over-heroism, eerie-emptiness aesthetic, and no-missions (visitor, not employee). RPG depth (pressures/intentions/reputation) runs *at the nodes and along the chain-topology threads between them* (factions.md), not spread thin across the whole area — deep where dense, empty between.
- **Four anti-boredom levers, none requiring the space be filled:** (1) vista/biome variety — the terrain itself is content (why the DEM splice portfolio + biome catalog matter); (2) rhythm — sparse→dense→sparse; (3) **anticipation** — you can always *see* the next worthwhile thing (curve, night lights, distant spires, the Forge-World-dense horizon), so empty = pulled-forward, not directionless; (4) rarity as amplifier — sparsity is what makes each vista/creature/settlement hit hard.
- **The vista is the anticipation engine, not decoration.** An empty stretch isn't empty if its far side shows something worth reaching. The distance must always promise (the Forge World lesson).
- **Faction pulse — the temporal anti-boredom lever (2026-07-26).** The dense nodes aren't static dioramas; they run on *cycles* whether or not the player is watching — market days, patrol/caravan schedules, seasonal raids, the build-and-release of a border dispute. Mechanism already exists: TempoBuf's regional clocks (simulation.md, "a region under pressure simulates hotter"), given a *rhythm* rather than a flat rate. Musical model: "The Riddle" (Nick Kershaw) — a repeating riff that builds, resolves, and builds again, pressure inside the loop. Payoff: the **same node feels different depending on when you arrive** (market day vs. dead of night vs. the eve of a raid) — the temporal twin of vista-variety, giving revisits and arrivals variety with zero new authored content, and deepening witnessing (you catch a living thing mid-breath, not a diorama triggered by your entry).

## Craft Reference Siblings (games, since film craft mostly doesn't transfer)

- **Outer Wilds** — closest sibling: no cutscenes, camera always yours, "witnessing over heroism" as literal orbital mechanics (events on a schedule whether you watch or not).
- **Fumito Ueda (ICO / Shadow of the Colossus)** — emotion from scale, silence, and geometry pointing the eye; minimal UI/dialogue.
- **Half-Life / Alyx** — never take the camera from the player; stage events so they look the right way naturally.
- **Death Stranding** — walking as the camera, weather/light as emotional labor, licensed needle-drops at vista beats (our Cherry Lips / Hail Bop instinct).
- **Halo CE** — the emptiness/awe source above; steal the liminal sacredness, diverge on wildlife per the axis rule.

## Open Questions

- Palette/era direction — the one thing still unspecified. Painterly vs. realist, colour identity, whether "The Riddle"'s 80s-optimism-with-melancholy is an *audio* reference or a *visual* one (it pushes the look somewhere specific if visual).
- Does the emptiness→life density curve get authored per-region, or fall out of the recovery-band field (civilization.md)?
- Craft specification remains design-brief level, not shot-list level — the gap flagged in TODO.md; needs the user's directorial sensibility leading, not more doc-writing.
