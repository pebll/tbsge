# Progression & science

Applies to the economy mode, not the skirmish. Status: **design only**.

## Goal

The classic early → mid → late-game arc, recurring "new toy" moments, and strategic variety between matches.

## Unit tiers

- Many legions, sorted into tiers (the notes say "say 4 tiers", tier 0–III).
- Start of a match: **one tier-0 legion** (pick 1 of 3).
- Science unlocks higher tiers over time; the economy scales so you can afford them.

## The science tree ("diamond" lattice)

- 3 research tiers (I, II, III).
- **Tier I**: all visible and researchable.
- **Tier II / III**: each node has **two parents** in the tier below.
  - **Visible** once *one* parent is researched.
  - **Researchable** once *both* parents are researched.
- Effects: you can't rush tier III, and you sometimes have to research something that isn't ideal to reach what you want → diversification; players try legions they wouldn't pick at first.
- Researches are **randomised** (shared or per player, depending on the mode).
- Science **accumulates over time** (resource per turn), rather than being bought instantly with gold as in KingdomHex. This avoids the "tech vs more units" gold trade-off and gives a steady stream of new units.
- Each research = 1 legion unlock (+ maybe 1 building; see `economy.md`) (+ maybe capital upgrades in the walking-factory variant).

## Tech modes (pick one first)

| Mode | Pros | Cons |
|------|------|------|
| **Random tree, shared** | Roguelike, fair by construction, "best army from the same pool" | Less identity |
| **Random tree, per player** | Asymmetric, plan around the opponent, roguelike "faction" feel | Can be unfair if a pool lacks counters |
| **Fixed faction trees** | Identity, synergy (e.g. undead + necromancy), beginner-friendly, enables a campaign | Heavy to make and balance; can get stale |

A campaign is possible without factions ("fake factions" built from existing legions).

## Things to pin down

- Number of nodes per tier (the lattice shape is what makes the "both parents" rule interesting; 4–3–2? 5–4–3?).
- Generator constraints for per-player randomness: e.g. **every pool must contain at least one answer** to each archetype (anti-shield, anti-flyer, anti-swarm…). That needs **counter tags** on legions, which also helps the AI and the draft.
- How builders' tiers map to science tiers (see `economy.md`).
- Whether science is slowed by the food deficit.
