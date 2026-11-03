# Codebase map & review

Godot 4.6, GDScript, ~22.7k lines in `scripts/` + `tests/`. Review date: 2026-11-03.

## Architecture

```
data/                     .tres resources: units, actions, teams, glossary, mode configs
scripts/
  models/                 Legion, Unit, Tile                       (pure data, RefCounted)
  actions/                ActionDefinition/DB, ActionTargeting, ActionResolver, ActionParams, BattleState
  core/                   CombatResolver, TurnManager, HexLayout, mapgen, autoloads (EventBus, AudioManager, *Defs, GameSettings)
  match/                  MatchSession (command API: resolve_use_action / end_turn / pass), sandbox session
  battle/                 playback (ActionPlayback, BattleActionRunner), battle log + formatter, expectation estimator, input lock, host wiring
  ai/                     AttackNearestEnemyBehavior, AiActionScorer, AiDrafter, HexPathfinder
  minigame/               skirmish mode: session (draft→battle→ended), phase controllers, rules, root scene
  ui/ visu/               HUD (legion strip, action bar, log panel, tooltips), world visuals
  balance/ cli/           headless balance + AI-duel runners
tests/                    headless suite (run_tests.gd), one file per area
```

**Good bones (keep them):**
- Model-first: `MatchSession.apply(cmd)` mutates the model synchronously and returns events + payload; visuals replay the result afterwards. This is exactly what headless tests, AI search, replays and multiplayer need.
- Command dictionaries (`{"type": "use_action", "action_id", "from", "to", "rng_seed"}`) are already serialisable.
- Data-driven units/actions with per-unit param overrides.
- Engine shared by two modes (minigame + sandbox) so it doesn't overfit one.
- A sizeable headless test suite and an AI-duel harness.

## Fixed in this pass

| # | Issue | Where |
|---|-------|-------|
| 1 | Live battle-log loss counter was set instead of incremented → stuck at 1 | `ui/battle_action_log_panel.gd` |
| 2 | Damage and loss chips popped on the same frame → loss tick now delayed by 0.22 s on killing hits | `battle/action_playback.gd` |
| 3 | Human attacks deselected the attacker before playback → kept selected (`keep_selection_in_combat` hook) | `battle/battle_action_runner.gd`, `battle/battle_host_wiring.gd`, `ui/battle_interaction.gd`, `ui/battle_ui_adapter.gd`, `minigame/battle_phase_controller.gd` |
| 4 | Action bar touched the legion strip → raised 20 px | `scenes/ui/battle_action_bar.tscn` |
| 5 | **Likely crash**: AI loop / playback / runner coroutines resumed after the scene was freed (abandon to menu, rematch) and touched freed nodes → guarded with `is_instance_valid(host)` | `battle_phase_controller.gd`, `action_playback.gd`, `battle_action_runner.gd` |
| 6 | Pause menu didn't stop the AI → AI holds between actions while paused | `battle_phase_controller.gd` (`_ai_delay`) |
| 7 | Swapping with a waited ally cleared its wait (free extra turn) → wait kept; regression test added | `actions/action_resolver.gd`, `tests/test_actions.gd` |

⚠️ These changes were reviewed statically: I couldn't run Godot in the cloud session. **Run `./run_tests.sh` and play one battle (attack, abandon mid-AI-turn, pause during the AI turn) before merging.**

## Findings not fixed (refactor backlog, by priority)

### High: they will bite the next milestones
1. **"Waited" is stored per tile** (`TurnManager.waited_coords`), not per legion. That's why there are `clear_wait()` patches in move, swap, teleport and cleanup, and why bug 7 existed. → Put `has_acted_this_turn` / `waited` on `Legion` and delete the coordinate bookkeeping. Small, contained refactor with good test coverage already.
2. **Three combat models**: `CombatResolver` (truth), `BattleExpectationEstimator` (Monte Carlo over the resolver, good) and `AiActionScorer._estimate_combat_damage` (hand-rolled: no shields, front-target instead of random, no kills). Every 0.2 effect would need to be coded three times. → AI uses the estimator (or an expected-value pass built on the resolver). **Do this first in 0.1.**
3. **Homogeneous-legion assumptions** block 0.4 mixing: `Legion.unit_type`; `ActionTargeting._legion_has_ranged/_legion_attack_range` read `units[0]`; action ids come from the legion's type; `unit_count` duplicates `units.size()`. → If mixing is coming, introduce "legion capabilities = union/aggregate of its units" **before** writing many effects that assume one type.
4. **No status/modifier hooks in combat.** `CombatResolver.resolve_combat` is one loop with damage = `attack` or `ranged_attack`. → Add pre-strike / on-hit / on-death hooks + a `StatusEffect` model before 0.2 effects (see `design/combat.md`).
5. **Global RNG** (`randi()` defaults in `ActionResolver`, `BattleHostWiring`, battle controller). → One seeded RNG per match, passed through; needed for replays, multiplayer and reproducible EA fitness.

### Medium
6. AI evaluates teleports by **temporarily mutating the live grid** (`AiActionScorer._score_teleport`). Works today, but it's fragile (an early return leaves corrupted state). → Targeting helpers that take a hypothetical origin.
7. AI magic numbers live in two files as consts and literals → one `AiParams` resource (prereq for the EA).
8. HP is `float` while every stat in `data/units` is an integer, and heals cast to `int` (`mini(before + heal, int(max))`). If a fractional damage source ever appears, heals silently truncate. → Pick `int` everywhere (or float everywhere).
9. `CombatResolver` prints every hit unless `quiet` is set; ~19 other bare `print`s. → Route through a debug logger; this matters for EA throughput.
10. Big files: `tile_info_panel.gd` (894), `battle_action_log_panel.gd` (893), `attack_nearest_enemy.gd` (731), `battle_interaction.gd` (~680), `unit_visu.gd` (670). Not urgent; split when you next touch them (e.g. log panel → card builder + live-tick controller).
11. `minigame_root.gd` and `sandbox_root.gd` still duplicate HUD wiring (pause, strip, vitals/AP handlers). `BattleHostWiring` covers part of it; move the rest when sandbox next needs a feature.
12. The pause menu is a click-catcher overlay, not `get_tree().paused`. The AI is now held, but tweens/animations keep running. Probably fine; just be aware.

### Repo hygiene
13. `videos/001_select_units.avi` and `videos/recording.avi` are **identical** 28 MB files, both committed (`project.godot` points the movie writer at `videos/recording.avi`). → Add `videos/` to `.gitignore`, remove them from git.
14. `assets/_archive/` = 142 MB in the working tree; `.git` = 221 MB. → Once you approve the delete list, remove it (history keeps it; a full slim-down needs a history rewrite, only if you want it).
15. `data/ai_duel/run_*` CSV outputs (+ `.import` files) are committed. → Ignore `data/ai_duel/run_*`.
16. `.uid` policy is contradictory: `.cursor/rules/git-workflow.mdc` says don't commit `.uid`, yet 126 are tracked and 13 scripts have none (e.g. `battle_expectation_estimator.gd`, `legion_strip.gd`, `ui_stat_icons.gd`). Godot 4.4+ expects `.uid` files to be **committed** (scenes reference scripts by uid, e.g. `project.godot` autoloads). → Commit them all and update the rule.
17. No CI. `run_tests.sh` needs a local `./godot_exe`. → A GitHub Action with a headless Godot 4.6 binary would catch regressions from agent sessions.

## Where to start (suggested order for 0.1)
1. Run tests + smoke the fixes above.
2. Wait-per-legion refactor (#1). Small, and removes a whole class of bugs.
3. Seeded match RNG (#5) + quiet logging (#9). Needed for any optimisation.
4. AI on the shared estimator + `AiParams` (#2, #7), then add considerations and an EA loop.
