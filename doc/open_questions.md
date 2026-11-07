# Open questions

Decisions still to make, each with why it matters. When one is answered, move it to **Decided** with the date.

## Still open

### Product
1. **What's the differentiator from KingdomHex, in one sentence a player would understand?** The claim is "Civ-style multi-legion combat". Is that visible in a 2-minute video of the game today? It matters for the itch page and for deciding which features earn their place.

### AI
2. **EA fitness: against whom?** Self-play alone tends to cycle. A hall of fame of older champions plus the scripted baselines is the usual fix. Only relevant when weight tuning resumes.
3. **Real difficulty levels.** Difficulty only scales the AI's draft gold today, and you said to leave it like that for now. Revisit before the beta: randomness in choices (temperature), fewer sims per fight, weaker profiles.

### Economy & progression (decide during the economy prototype)
4. **Is "production" a fourth resource or just gold?** (The mine gives "+prod".) *Parked: "we will need to think about that more later".*
5. **Food deficit formula**: linear or percentage, can production reach 0, does it slow science? *Decide in the prototype.*
6. **Science tree size and generator rules**: how many nodes per tier, and what guarantees that every random pool can answer every archetype? The counter tags (decided below) are the tool for this.
7. **Smallest economy prototype**: capital + 1 builder + 2 buildings + gold + a 3-node tree? Decide when the skirmish beta is out.

### Competitive / multiplayer (parked until after the beta)
8. **Determinism**: lockstep or server-authoritative? The match already has a seeded RNG (`MatchSession.rng`); who owns the seed?
9. **Out-of-turn economy commands** ("their turn: economy"): applied immediately, or queued for your turn start?

---

## Decided

### 2026-11-07
- **Skirmish ships first.** Polish the draft skirmish through 0.5 and release a beta on itch; the economy mode comes after.
- **Legions will mix unit types.** Do the *data-model* part (legion = any units; per-unit identity for visuals, cost and SFX) **before 0.2**, so effects are written mix-aware. The mixing UI/UX stays in 0.4.
- **Targeting stays random** inside a legion. Control comes from effects (Snipe, First strike, …), not from a deterministic rule or a player-chosen focus.
- **Fixed capital is the main mode** (capital + builders + raidable territory). The walking factory is a battle-royale experiment for much later.
- **Counter tags now.** Every unit gets tags from a small fixed list (armored, flyer, swarm, shielded, ranged, support, …), shown in tooltips; draft, tech generator and AI use them later.
- **Flying moves to 0.3** (with terrain), so it's complete from day one.
- **Poison ticks at the start of the poisoned legion's turn**, for N turns.
- **Fog of war: the AI sees through fog at first.** An honest fog AI comes later, maybe as a difficulty option.
- **AI scope for 0.1:** coordinated focus fire within a turn + legion ordering (ranged/support first, melee finishes, tank swaps forward). **Smart AI draft later**: it needs balance first, and a deterministic draft isn't interesting yet.
- **Economy will have both** map-placed buildings to capture and builders that construct.
- **Title: Realmrise Tactics** (window title, menu, itch page, save folder).
- **Desktop only** (mouse + keyboard). No touch constraints on UI.
- **No separate "complexity tiers".** An earlier agent proposal (unit kit complexity I–IV for tutorial pacing) is dropped; "tier" means science tier only.
- **Parked until after the skirmish beta:** battle royale / walking factory, factions (random tech trees only), campaign & tutorial, online multiplayer (hotseat + AI until then).
- Difficulty keeps scaling only the AI's gold for now (see open question 3).
- The player can choose the opponent AI in Play setup: Evolved / Hand-tuned (default) / Cascade.

### Earlier
- *(2026-08-11)* AI = utility AI with optimised weights; no RL.
- *(2026-08-11)* Science accumulates over time; no buying research with gold.
- *(2026-08-20)* Online multiplayer will be 1v1 (with a chess-like clock).
- *(2026-08-20)* Food is a soft cap (production penalty), not a hard cap.
- *(2026-08-20)* Enemy buildings: Claim (2 AP, terminal) or Burn (1 AP, terminal).
