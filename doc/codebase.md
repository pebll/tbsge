# Codebase map & review

Godot 4.6, GDScript. Reviewed 2026-11-03; updated after the utility-AI merge (PR #4).

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

All of the above are covered by the headless suite (38 suites, run locally with Godot 4.6).

## Review findings: status after the utility-AI merge (PR #4) and the follow-up pass

| # | Finding | Status |
|---|---------|--------|
| 1 | "Waited" stored per tile (`TurnManager.waited_coords`) → stale stains, swap exploit | ✅ **Fixed**: `Legion.waited`; `end_team_turn` clears every legion; tile bookkeeping deleted |
| 2 | Three combat models (resolver / UI estimator / hand-rolled AI sim) | ✅ **Mostly fixed by PR #4**: the shipped `utility` brain scores fights via `CombatExpectation` over the real resolver. ✅ **Follow-up**: UI preview and AI now share one sampler (`CombatSampler`). ⚠️ The legacy `AiActionScorer` heuristic (no shields, front-target) remains, but only inside the `cascade`/`greedy` *baseline* brains used as benchmark opponents |
| 3 | Homogeneous-legion assumptions (`units[0]` for range, single-type action ids, duplicated `unit_count`) | ✅ **Fixed for rules**: `Legion.has_ranged/max_attack_range/unit_types`, union of action ids, read-only `unit_count`. ⚠️ Still single-type by design: `Legion.unit_type` drives visuals, draft cost, SFX and the legion stats panel. That is the actual 0.4 mixing work |
| 4 | No status/modifier hooks in combat | ⏸ **Deferred on purpose** to the first 0.2 effect. Designing the hook API without a single consumer means guessing it. Let the first status (attack buff) define `StatusEffect` + pre-strike / on-hit / on-death hooks in `CombatResolver`. UI and AI sample through the resolver, so they get it for free |
| 5 | Global RNG | ✅ **Fixed**: `MatchSession.rng` / `match_seed`. The resolver default, battle controller, sandbox and the utility brain's softmax pick use it; AI duels seed it. The remaining global RNG is cosmetic only (formations, SFX variants, menu background, opponent names) |
| 6 | AI moves legions on the live grid to evaluate hypotheticals | ✅ **Fixed**: 7 call sites (utility, cascade, legacy scorer) go through `HypotheticalPosition.evaluate`, which always restores |
| 7 | AI magic numbers scattered | ✅ **Fixed by PR #4** for the utility brain (`AiProfile`, loadable JSON profiles, GA / MAP-Elites tuning; in-game it currently runs the hand-tuned `hand_v1` profile because no evolved profile beat it). Baseline brains keep their consts (intentionally frozen opponents) |
| 8 | Heals truncate float HP to int | ✅ **Fixed** (float math + test) |
| 9 | Per-hit combat prints; sims toggled the static `quiet` flag from worker threads | ✅ **Fixed**: quiet by default, no toggling in sims. The other prints were already behind debug flags |
| 10 | Big files (log panel, tile info panel, cascade behaviour, interaction) | ⏸ **Not a defect**: split when next touched |
| 11 | `minigame_root` / `sandbox_root` duplicate HUD wiring | ⏸ **Not a defect**: move into `BattleHostWiring` when the sandbox next needs a feature |
| 12 | Pause menu is an overlay, not `get_tree().paused` | ✅ The AI now holds while paused; animations still run, which is fine |
| 13 | `videos/` (2× identical 28 MB AVI) committed | ✅ **Untracked + ignored** (files kept on disk; still in git history) |
| 14 | `assets/_archive/` is 142 MB | ⏸ **Waiting on your delete list** (see `assets_archive.md`) |
| 15 | Run outputs committed | ✅ `data/ai_duel/` untracked (it was already ignored by PR #4). ❓ `data/ai/evolve/{cur,cur2,cur3,lon1,nice}` (~140k lines of CSV/JSON) are still tracked. Keep only `best_profile.json` + `history.jsonl`? Your call |
| 16 | `.uid` policy contradictory / files missing | ✅ Every script has a tracked `.uid`; the cursor rule now says to commit them; missing asset `.import` files committed |
| 17 | No CI | ✅ `.github/workflows/tests.yml` + `tools/get_godot.sh` (checksum-verified Godot 4.6). Verified from a fresh clone: 38/38 |

### New observations from this pass
- `tests/test_ai_evolution.gd` logs `eval job N returned no result (worker error)` on some runs, but the suite still passes. A worker in the parallel evaluator is failing silently; worth a look before the next long evolve run.
- `CombatSimSnapshot.clone_legion` doesn't copy `waited`, cooldowns or statuses. That's fine for combat sims today; revisit when 0.2 statuses exist, because the sampler will need them.
- Behaviour check: `utility` vs `cascade`, 20 mirrored pairs (seed offset 1e6), gave **identical** results on `main` and on this branch. The refactors didn't change how the AI plays.

## Where to start next
1. Smoke-test in the editor: attack (selection stays), pause during an AI turn, abandon mid-AI-turn.
2. 0.2: build the first status effect (attack buff/debuff) together with the resolver hook API (#4).
3. Decide on #15 (evolve run data) and #14 (archive delete list).
