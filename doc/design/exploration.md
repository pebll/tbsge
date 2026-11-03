# Exploration & map objects

Applies to the economy mode. Status: **design only**. Exploration is what makes the Civ early game fun; it should also give early units something to do.

## Map objects

| Object | Effect | Source |
|--------|--------|--------|
| **Ruins / chests** | Random gold, a random tech, a mercenary, or map information | Civ, KingdomHex |
| **Barbarians** | Hostile neutrals; a reason to use early units | Civ |
| **Neutral legions** | Cattle, animals minding their own business. Maybe recruitable with a druid / forest fae | HoMM |
| **Mercenaries** | Hire for gold; they join you | HoMM |
| **Abandoned buildings** | Occupy to own | HoMM |
| **Statues** | Permanent buff while you hold them | KingdomHex |
| **Spawners** | Recruit units for you while held | KingdomHex |
| **Special tiles** | Pyramids, big bone, teleporter, volcano… | — |
| **Dragon pit / observatory** | Hire special units / gain science | HoMM5 |

Most valuable objects are **guarded by a neutral stack** (HoMM / KingdomHex pattern). This gates rewards behind combat and makes early army composition matter.

## Dependencies

- Fog of war (0.3) — exploration means nothing without it.
- Neutral AI behaviour (wander / guard / aggro radius): a second, simpler AI.
- Tile objects in the model (today a `Tile` only has terrain + one legion).
- Map generation that places objects fairly (mirrored or balanced by distance from each capital).
