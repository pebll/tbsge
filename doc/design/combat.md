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

## Effects catalogue

Status: ✅ done · 🎯 scheduled (milestone) · 💡 idea

Targeting inside a legion stays **random** (decided 2026-11-07); effects such as Snipe or First strike are the way to add control.

| Effect | Status | Notes / open design |
|--------|--------|---------------------|
| Heal (self / ally) | ✅ | |
| Shield | ✅ | Absorbs the first hit per turn |
| Teleport | ✅ | |
| Status-effect visualisation | 🎯 0.2 | Prerequisite for every status below |
| Flying | 🎯 0.3 | Moved to terrain milestone (decided 2026-11-07); rules designed with terrain |
| Regeneration | ✅ 0.2 | Unit trait. Treant: +3 HP per unit at the start of its own turn |
| Lifesteal | ✅ 0.2 | Unit trait. Shadow Hound: the striking unit heals 50% of the HP its strike took |
| Pierce / shieldbreak | ✅ 0.2 | Unit trait. Axeman: strikes ignore the shield and break it |
| Attack buff / debuff | ✅ 0.2 | Statuses Empowered (+N per strike) and Weakened (-N per strike), applied by the Rally (Rat Shaman) and Curse (Rat Sorcerer) actions |
| Poison | ✅ 0.2 | Status. Venom Archer arrows add a stack per landed hit; each unit loses 1 HP per stack at the start of the poisoned legion's turn, for 2 turns (stacks add, max 5) |
| Freeze | 🎯 0.4 | Skip next turn / no move |
| Scare | 🎯 0.4 | Target must move away; needs pathing rules |
| Summon | 🎯 0.4 | Needs free slots in a legion → depends on mixing (data model done in 0.1.5) |
| Merge (slimes) | 🎯 0.4 | Depends on mixing |
| Stealth | 💡 | Needs fog of war (0.3; the AI sees through fog at first) |
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

## Unit traits (0.2)

- Traits are **passive, per-unit abilities** in `UnitDefinition.traits`: regeneration, lifesteal, pierce and poison_on_hit (`scripts/effects/unit_traits.gd`).
- They run from the same hook points as statuses, so mixed legions work per unit.
- Statuses are temporary and sit on the legion; traits are permanent and belong to the unit type.
- **Status actions:** `TargetingKind.STATUS_ALLY` / `STATUS_ENEMY` with `status_id`, `status_stacks` and `status_turns` on the `ActionDefinition` (Rally, Curse). A new buff or debuff is just data.

## Status-effect framework (0.1.5, implemented)

- **Model:** `Legion.statuses`. Each entry is `{"id", "stacks", "turns_left", "source_team"}`, managed through `scripts/effects/status_effects.gd` (apply / remove / query).
  - **Stacking:** each type uses `refresh` (keep the larger stacks and duration) or `add` (sum the stacks, refresh the duration), capped at `max_stacks`.
  - **Duration:** N = N of the owner's turns, counting the current one. It counts down at the **end** of the owner's turn. `-1` means until removed.
- **Types:** one `data/status/<id>.tres` per effect (`StatusDefinition`: name, description, icon or colour, debuff flag, stacking, default duration) plus a behaviour script that extends `scripts/effects/status_behavior.gd`.
- **Hooks** (a behaviour overrides only what it needs):
  - `outgoing_damage` and `incoming_damage`, applied per strike before shields.
  - `on_hit_dealt`, `on_hit_taken` and `on_unit_death`.
  - `on_turn_start`, at the start of the owner's turn after AP and shields refill. Poison goes here.
  - `on_turn_end`.
- **One source of truth:** the damage and hit hooks run inside `CombatResolver`. Previews, the AI's Monte Carlo and the turn planner all use the resolver, and every copy of the board carries the statuses, so a new effect reaches all of them without extra code.
  - Two exceptions: the AI's threat map and the `team_finish` feature use raw stats, so add AI awareness per effect where it matters.
- **Status damage** (`StatusEffects.damage_unit`) bypasses shields and kills at 0 HP. Deaths at turn start prune the legion and can end the match.
- **UI:** badges on the map (`scripts/visu/status_badges_2d.gd`) and in the legion strip's stat row (hover shows the description, stacks and turns left).
  - Battle log: one card per event (`status:<id>`). Expiries aren't logged.
  - Turn-start ticks are animated (hit, heal or death).
- **Testing:** test-only effect types in `tests/test_status_effects.gd`. The autopilot's `status_demo` flag shows a demo burn and guard in a real game.

