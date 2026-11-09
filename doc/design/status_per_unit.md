# Rework: status effects belong to units, not legions

*2026-11-09. Plan only; nothing implemented yet.*

## Why

Today a status lives on the legion (`Legion.statuses`). That breaks the game's core idea: a legion is a stack of individual units.

- **Poison is far too strong against swarms.** One venom arrow adds a stack to the whole legion, and every unit then takes the poison damage. Five archers shooting 8 rats: the legion reaches 5 stacks, so each rat loses 5 HP per turn, about 40 HP per turn in total. With per-unit poison, the same 5 arrows poison about 4 rats once or twice each, about 5–6 HP per turn.
- **It doesn't match how combat works.** Each strike already picks one target unit (`CombatResolver`, random target). Damage, shields, lifesteal and regeneration are all per unit. Statuses are the only exception.
- **Mixed legions.** When units move between legions, or the legion's units differ, a legion-wide status can't say who is poisoned.
- **Readability.** "This legion is poisoned" hides which units are dying. Per-unit statuses can show on the unit cards.

## The new model

| | Today | After |
|---|---|---|
| Storage | `Legion.statuses: Array[Dictionary]` | `Unit.statuses: Array[Dictionary]` (same shape: `id, stacks, turns_left, source_team`) |
| A unit dies | the status stays on the legion | its statuses go with it |
| Poison strike | +1 stack on the legion | +1 stack on **the unit that was hit** |
| Rally / Curse | stacks on the legion | applied to **every unit in the target legion at cast time** (see question 1) |
| Poison tick | every unit loses `stacks` | each poisoned unit loses its own `stacks` |
| Empowered / Weakened | changes every strike of the legion | changes the strikes of the units that have it |
| Durations | counted per legion | counted per unit, at the end of the owner team's turn (same timing as today) |

`Legion` keeps only **read-only views** for UI and AI. Nothing is stored on the legion:
- `StatusEffects.legion_summary(legion) -> {id: {"units": n, "max_stacks": s, "total_stacks": t, "turns_left": max}}`.
- `StatusEffects.legion_has_any(legion)`.

## Code changes

### Rules (`scripts/effects/`, `scripts/core/`, `scripts/models/`)
1. **`unit.gd`:** add `var statuses: Array[Dictionary] = []`. **`legion.gd`:** remove `statuses` and add the helper views.
2. **`status_effects.gd`:** `apply / get_effect / has_effect / stacks_of / remove` take a `Unit`. Add `apply_to_legion(legion, id, stacks, turns, team)`, which loops over the legion's units and returns one "applied" event per legion (holding the unit count, so the log and popups stay short).
3. **`status_behavior.gd` hooks:** pass both the unit and its legion, e.g. `outgoing_damage(owner_legion, owner_unit, effect, …)` and `on_turn_start(owner_legion, owner_unit, effect)`.
   - `strike_damage` reads the attacking unit's statuses and the target unit's statuses.
   - `after_hit` runs `on_hit_dealt` for the striking unit and `on_hit_taken` for the struck unit.
   - `after_death` runs the dying unit's own `on_unit_death`.
4. **`turn_start` / `turn_end`:** loop over legions, then units, then each unit's statuses. Expiry happens per unit.
5. **`poison_on_hit` trait:** call `apply(target_unit, POISON, …)`. The hit row already holds `target`.
6. **`combat_sim_snapshot.clone_unit`:** copy `statuses` (deep). The AI's `TurnSimSession` and the combat Monte Carlo get this for free.
7. **`any_statuses(a, b)`:** checks units instead of the legion. It's still cheap: short-circuit on the first unit that has a status.
8. **`action_resolver._execute_apply_status`:** use `apply_to_legion`.

### AI
- `threat_map.gd` (×2), the `with_status` check: use `StatusEffects.legion_has_any`.
- `utility_brain.gd`, board signature for the brain caches: add each unit's statuses to the per-unit HP string, otherwise the caches go stale.
- `ai_feature_extract.gd:281`, the value of Rally/Curse: today it's "existing stacks on the target". It becomes "share of target units that already have it, and their stacks", so the AI doesn't re-curse an already-cursed legion. It does re-curse when new units have joined.
- `projected_hp_change`: per unit (poison already sums per unit). No change to how it's used.

### UI and playback
- **Map badge** (`status_badges_2d`, `legion_visu`): one badge per status present in the legion. The number on it is **how many units** have it, not stacks. Hover shows "Poison: 3 of 8 units, up to 2 stacks, 1 turn left".
- **Unit cards in the strip** (`legion_unit_cell`): a small emoji corner badge on each affected unit, e.g. 🧪2. This is where per-unit statuses become visible.
- **Chips** (strip and info panel): same chip, with the count showing units: "🧪 3/8". The tooltip lists stacks and turns.
- **Popups:** they already add up damage per legion and status. Keep that. One "applied" popup per legion per strike batch, e.g. "🧪 +3 units".
- **Battle log:** status tick cards already list each unit (`unit` is in the event). No change in shape.
- **Fog:** unchanged.

### Tests
`test_status_effects` (27 references), `test_effects_v02` (12) and `test_ai_effects` (3) get rewritten around units. New cases to add:
- A poison strike poisons only the unit that was hit.
- A unit that dies takes its poison with it.
- A Rally then a new unit joining: the new unit isn't empowered.
- An empowered unit's strikes do more, the others' don't.
- Durations count down per unit.
- Snapshot clones carry unit statuses.
- The brain signature changes when one unit's stacks change.

## Balance: must change in the same PR

Per-unit poison is roughly **5–8× weaker against swarms** and about the same against small elite legions. That's the point, but the venom archer would become bad. Options, from simplest to richest:

1. **Raise the venom archer's stacks or duration.** For example 2 stacks for 3 turns per hit. Easy, but it's still random which unit gets hit.
2. **Make poison hurt more per stack.** 2 HP per stack, max 3 stacks. This keeps the "focus a big unit" use case strong.
3. **Make poison spread on a tick.** When a poisoned unit takes its tick, one adjacent unit in the same legion gets 1 stack. This gives poison its own swarm-killer identity without hitting everything at once. It's more rules text.

**My pick:** option 2 first, measured with the AI duel benchmark (`--draft mirror --play-sims`, vs `utility_v0`) and venom-archer-heavy drafts. Consider option 3 later as the identity for a dedicated plague unit.

Rally (+2 dmg per strike, 2 turns) and Curse (−3 per strike, 1 turn) keep the same numbers if they hit the whole legion, so balance doesn't change for them.

## Order of work (one PR, about 1.5–2 days)

1. **Model and rules:** `Unit.statuses`, `StatusEffects` API, hooks, behaviours, resolver, snapshot clone. Rewrite the rule tests until they're green.
2. **AI:** signature, threat map, feature extract. Run the AI tests and a short duel to check nothing went pathological.
3. **UI:** unit-card badges, legion summary chips and badges, popups. Check the screenshots with the UI autopilot (`status_demo` flag).
4. **Balance:** poison per stack, the benchmark, then pick numbers.
5. **Docs:** `effects_ux.md` (statuses row), plus the status descriptions in `data/status/*.tres`. For example, "Each poisoned unit loses 2 HP per stack at the start of its turn."

## Questions for you

1. **Rally / Curse target:** the whole legion at cast time (recommended; same as today, simple to read)? Or one unit per caster unit, so a bigger caster legion buffs more units? The second is more "per unit", but harder to explain.
2. **Poison balance:** option 2 (2 HP per stack, max 3)? Or one of the others?
3. **Map badge number:** the units affected (recommended), or the highest stack count?
