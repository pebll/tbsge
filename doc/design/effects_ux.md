# Effects UX: how abilities, statuses and terrain are shown

*2026-11-08, updated 2026-11-09. Current state, problems, proposal, and the art list.*

## How it works today

There are four kinds of "special rules", and each is shown differently:

| Kind | What it is | Examples | Where the player sees it today |
|---|---|---|---|
| **Traits** (abilities) | Permanent, per unit type (`UnitDefinition.traits`) | Flying, Regeneration, Lifesteal, Pierce, Poison strikes | **Abilities list**: one "emoji Name: rule" line each, under the legion name (info panel) and in the unit tooltip. Popups when they trigger |
| **Statuses** | Temporary, on a legion, with stacks and turns (`Legion.statuses`) | Poison, Empowered, Weakened | Badge above the legion and in the strip's stat row; hover explains (description, stacks, turns left); battle-log card; floating popup when applied or ticking |
| **Special actions** | Buttons in the action bar | Rally, Curse, Teleport, Heal ally | Action button + tooltip |
| **Terrain affinities** | Per unit type, per terrain (`UnitDefinition.terrain_affinity`) | none shipped | **Removed from all units for now (2026-11-09).** The code and tests remain. |

Plus the **tags** (ranged, armored, swarm…): hidden from players since 2026-11-08 and kept for the AI and the future smart draft.

**Problems**
- Traits and affinities change how a unit plays, but the player can't learn what they do.
- Statuses look polished; traits look like plain text, so the two feel like different systems.
- Several placeholders show a coloured circle with a letter: badges and popups for statuses without art, and every trait.

## Proposal: one "Abilities" list per unit

- **What it shows:** every rule that changes how a unit behaves (traits, terrain affinities, and special actions worth explaining) as a list of rows. Each row has an **icon, a name and a one-line rule**:
  ```
  [icon] Flying          Flies over water and mountains. Ignores slow terrain and cover.
  [icon] Poison strikes  Each arrow that lands adds 1 Poison (2 turns).
  [icon] Forest walker   Moves through forest for 1 AP and takes 25% less damage there.
  ```
- **Where it shows:**
  - The unit tooltip (hover a unit in the legion strip).
  - The info panel (draft picker and right-click inspect).
  - Compact icons in the strip header next to the stats; hovering one shows its row.
- **Terrain affinities:** not yet (decided 2026-11-09).
- **Placeholders:** emojis until the icons exist (decided 2026-11-09). Status emojis are in `data/status/*.tres` (`emoji`); trait emojis are in `scripts/visu/effect_visuals.gd`.
  - Statuses: 🧪 Poison, 💪 Empowered, 🥀 Weakened.
  - Traits: 🪶 Flying, 🌿 Regeneration, 🩸 Lifesteal, 🗡️ Pierce, 🐍 Poison strikes.
- **Data:** each trait gets a definition file like statuses already have (`data/traits/<id>.tres`: name, one-line rule, icon, colour), so the UI, popups and log all read the same data. The rules stay in code.
- **Statuses stay as they are:** badges, hover and popups. They're temporary, so they belong on the legion rather than in the unit's ability list.

**Rule of thumb for players:** an icon in a unit's list is something it always has; an icon above a legion is something happening to it now.

## Art list (missing or placeholder)

### Icons (small, readable at ~24 px; used in badges, popups, ability rows, log)
| Icon | For | Now |
|---|---|---|
| Poison | status | green circle "P" |
| Weakened | status | purple circle "W" |
| Empowered | status | reuses `strong.png` (also Rally's button) |
| Flying | trait | blue circle "F" |
| Regeneration | trait | green circle "R" |
| Lifesteal | trait | red circle "L" |
| Pierce | trait | grey circle "P" (clashes with Poison) |
| Poison strikes | trait | can share the Poison icon with a small arrow |
| Rally | action button | reuses `strong.png` |
| Curse | action button | reuses `target.png` |
| Teleport | action button | `spell.png` (fine; was shared with Curse until 2026-11-08) |

### Tiles (delivered 2026-11-09)
- **New tiles:** v2 (388×330) and v3 (700×650) art is fitted to the grid per texture (`texture_fit` / `variant_fit`: scale and offset measured from the art).
- **Looks per terrain** (each match picks one look per terrain):

| Terrain | Looks |
|---|---|
| Grass | grass, flowers, grass variant |
| Desert | desert, savanna, bushland, pebbles |
| Forest | forest, jungle |
| Water | water, ocean |
| Mountain | mountain, volcano |
| Swamp | swamp |
| **Hill** (new: 2 AP, +1 vision) | grass hill, badlands |
| **Tundra** | tundra; defined but not generated yet (map weight 0) |

- **Still missing:** a fog texture. Tiles in fog are only darkened.

### Units
- All 22 unit types have sprites. 23 new sprites arrived on 2026-11-09 (knight, elves, griffon rider, frog, …) and aren't used yet. The Dragon Rider only has a front view (same as the other `base_uncut` units).

### Later
- Sounds: status applied/tick, lifesteal, pierce, wings for flyers (Sounds milestone).
