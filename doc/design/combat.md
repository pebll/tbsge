# Combat & actions

## Current rules (as implemented)

**Turns & AP**
- Teams alternate turns. Each legion has AP (default 2; per unit type via `UnitDefinition.ap`), refilled at the start of its team's turn. Shields refill then too.
- **Move** costs 1 AP and is **non-terminal**. Moving into an ally with AP left **swaps** the two (both spend 1 AP).
- **Terminal** actions (melee, ranged, heals, teleport) spend all remaining AP and end that legion's turn.
- **Wait/pass** ends a legion's turn without acting. *Implementation note:* "waited" is stored per **tile**, not per legion (see `codebase.md`).
- Cooldowns are per legion and per action, ticked at the start of your own turn (cooldown 1 = unavailable next turn).

**Combat resolution** (`CombatResolver`)
- The attacking legion hits first; then the sides alternate. When one side runs out of eligible strikers, the other side **drains** its remaining strikers.
- Each unit strikes **at most once per combat**. Targets are **random** among living enemy units.
- Deaths are immediate: dead units don't strike later.
- Shields absorb the first hit each turn (up to the shield value), then break until refreshed.
- **Melee** (distance 1): every unit can strike back. **Ranged**: only units whose `attack_range` covers the distance and that have `ranged_attack > 0` strike, on both sides.
- Combat is resolved fully in the model first, then played back visually from the hit/death log.

**Heals**
- `self_heal` / `heal_ally`: each caster unit heals `heal_amount` onto the currently lowest-HP wounded unit of the target. Terminal.

**Teleport**
- Jump to an empty walkable tile in range; terminal + cooldown.

**Action data model**
- One `ActionDefinition` per verb (`data/actions/*.tres`) with defaults; per-unit overrides through `ActionParams` (`override ?? default`). Don't create per-unit action variants unless the verb itself changes.

## Unit complexity tiers (UX guidance)

| Tier | Kit |
|------|-----|
| I Basic | Move, melee (maybe self-heal). One job. |
| II Specialty | + ranged **or** shield **or** one simple skill |
| III Tactical | Cooldown skill, terrain-aware kit, 1 status |
| IV Complex | Several skills, buffs/debuffs, keywords matter |

Note: these UX tiers are not the same thing as the **science tiers** in `progression.md`. Consider aligning them.

## Effects catalogue

Status: ✅ done · 🎯 scheduled (milestone) · 💡 idea

| Effect | Status | Notes / open design |
|--------|--------|---------------------|
| Heal (self / ally) | ✅ | |
| Shield | ✅ | Absorbs the first hit per turn |
| Teleport | ✅ | |
| Status-effect visualisation | 🎯 0.2 | Prerequisite for every status below |
| Flying | 🎯 0.2 | Ignores terrain blocking? Can only be hit by ranged / flyers? Decide before terrain (0.3) |
| Regeneration | 🎯 0.2 | Heal X at the start of own turn |
| Lifesteal | 🎯 0.2 | % of HP damage dealt → heal own lowest unit |
| Pierce / shieldbreak | 🎯 0.2 | Ignores or destroys the shield |
| Attack buff / debuff | 🎯 0.2 | First real status with a duration |
| Poison | 🎯 0.2 | Ticks each turn or on move? Pick one |
| Freeze | 🎯 0.4 | Skip next turn / no move |
| Scare | 🎯 0.4 | Target must move away; needs pathing rules |
| Summon | 🎯 0.4 | Needs free slots in a legion → depends on mixing |
| Merge (slimes) | 🎯 0.4 | Depends on mixing |
| Stealth | 💡 | Needs fog of war (0.3) |
| Silence | 💡 | Disable actions/effects |
| Set trap | 💡 | Tile objects |
| Necromancy | 💡 | Raise dead units → needs a death record per tile |
| Move speed buff/debuff | 💡 | |
| Ignore armor (magic) | 💡 | Close to pierce; merge them? |
| Mind control | 💡 | Team swap for N turns |
| Thorns / barricade | 💡 | Tile objects |
| Snipe | 💡 | Always target the lowest-HP unit (breaks the random-target rule on purpose) |
| AoE | 💡 | Heal/damage **each** unit in the legion |
| First strike | 💡 | Strike order modifier |
| Water units | 💡 | Siren, boat; needs water terrain to be walkable for some units |

**Framework needs, before stacking many effects:** a single `StatusEffect` model (id, stacks, duration, source, tick timing: turn start / on hit / on move), modifier hooks in `CombatResolver` (pre-strike, on-hit, on-death), and one battle-log line shape for status events. If combat stays a hard-coded loop, each effect will touch the resolver, the estimator and the AI scorer separately (three copies of the same rule today).
