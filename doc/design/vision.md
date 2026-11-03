# Vision

## One line

**Realmrise Tactics**: fast-paced, deep, multi-legion tactical battles on a hex map, with just enough economy, science and exploration to make every match a different strategic puzzle. It's the tactical core that a fuller *Realmrise* (diplomacy, deep economy) could one day be built on.

> Naming: the Godot project is called **FableQuest**, the repo is `tbsge`, and the notes say *Fable Quest*, *Realmrise* and *Realmrise Tactics*. Pick one working title (see `open_questions.md`).

## What makes it fun (the two pillars we know work)

1. **Outplaying the opponent**: winning a battle with less "value" on the board. Positioning, focus fire, timing and counters matter more than army size.
2. **The spectacle of big armies** lined up and crashing into each other.

Every feature should feed at least one of these. If a feature only adds bookkeeping, cut it.

## What it is, and what it isn't

| It is | It isn't |
|-------|----------|
| Civ-style **multi-legion** combat: many stacks manoeuvring on one map | A HoMM/auto-battler where one army fights one army on a separate battlefield |
| Hex grid, stacked units (legion = up to a 6×2 footprint of units) | Single-unit-per-hex wargame |
| Short matches (chess / Super Auto Pets pace) | A 6-hour 4X |
| Strategic variety from **science + many legions with counters** | A faction game (at least at first; see progression) |
| Light, interactive economy spread over the map (raidable) | Spreadsheet economy in the capital |
| AI good enough to be a real opponent | RL / ML agents (out of scope) |

## Inspirations, and what we take from each

- **Civ (early game)**: exploring fast, ruins with random rewards, barbarians, builders that spend charges.
- **HoMM5**: capturable map buildings (mills, observatories, dragon pits), mercenaries, neutral stacks guarding things.
- **KingdomHex** (in development by a two-person team): the closest relative. It has stacking, hex tactics, many skills, recruiting, exploration, stealth, claimable **statues** (permanent buff while held), **spawners**, chests, mines. **Our difference**: deep multi-legion combat like Civ rather than HoMM/auto-battler fights; no factions/heroes/items at first; time-gated science instead of buying research with gold.
- **Chess / SAP**: match length, a clock, the capital as the "king".
- **MTG**: rush vs economy as a real strategic choice.
- **Gladius**: a warning: don't let players plant a city in the opponent's face.

## Long-term shape (not committed yet)

1. **Skirmish** (now → 0.5): draft legions with gold, fight to the last unit. Pure tactics.
2. **Economy mode**: one capital (lose it = lose), production, builders, map buildings, science tree, food soft cap. Ideally 1v1 competitive with a clock.
3. **Battle royale / walking factory**: a mobile capital-factory and a shrinking map. An experiment.
4. Later: multiplayer, campaign, tutorial, sounds/music.

See `modes.md`, `economy.md`, `progression.md`, `exploration.md`.
