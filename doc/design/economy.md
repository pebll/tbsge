# Economy, capital & buildings

Applies to the economy mode. Status: **design only**.

## Resources

| Resource | Used for |
|----------|----------|
| **Gold** | Build and recruit |
| **Food** | Upkeep for cities and units (soft cap) |
| **Science** | Research (see `progression.md`) |

(The 20/08 notes also mention "prod" from mines; decide whether production is a 4th resource or the same as gold.)

## Capital

- One capital per player. It produces units and builders. **Capital falls = you lose.**
- Cities should be weak/limited so city-spam / "city in the opponent's face" (the Gladius problem) isn't a strategy.
- Economy should **not** sit mostly in the capital: it's boring and you can't interact with it. Spread it over the map so territory control and raiding become a strategy layer.

## Territorial economy, two layers

1. **Map-tied**: pre-placed buildings, special tiles, neutral units (HoMM style). Possibly *the only* way to get outposts and farms. Simpler, and avoids city-placement rules.
2. **Self-built**: builders construct farms, mines, watchtowers, fishing boats…

### Builders (Civ6 charges, simplified)
- A unit with a special action: **build one thing, then consume itself.**
- 3 builder tiers, each unlocked by the first tech of that science tier → building progression without a separate economy tree.
- Option (maybe too complex): each research unlocks 1 legion + 1 building (5 buildings per tier; hard to fill and balance).
- Tier-1 examples: farm on grassland (+food), mine on mountain (+production).
- Builders are weak: they must be escorted, which pulls armies around the map.

### Spreading out vs ringing the capital
- Players will ring their capital with farms and mines. That's OK: it **breaks turtle stalemates**, because a losing player sitting in the capital loses the ring and their economy collapses.
- To pull players outward: high-yield special tiles that need higher-tier builders and are far away (harder to protect), plus neutral buildings.

## Interacting with enemy buildings

| Action | Cost | Use |
|--------|------|-----|
| **Claim** | 2 AP, terminal | You intend to hold it. (06/08 note: ownership changes over a few turns) |
| **Burn** | 1 AP, terminal | Raid: destroy it (maybe gain gold) |

Hit-and-run raiding is a desired play pattern.

## Loot

- Dead units drop 10–30% of their cost in gold (higher tiers maybe some science), or food for living creatures.

## Food soft cap

- Each unit eats food equal to its **size** (a full legion = 12 food).
- Over the limit you can still produce (and research?), but **production is reduced by the deficit**.
- Purpose: allow a deliberate over-army for a decisive push, paid for with a weaker economy. No hard cap.
- To decide: the deficit formula (linear? does it floor at 0? does it hit science?), and whether units in the field cost more than garrisoned ones.
