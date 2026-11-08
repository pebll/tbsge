## Agent notes (project conventions + learnings)

### Architecture (engine vs modes)
- Treat shared battle systems as an **engine**: `MatchSession`, actions, combat, turns, pathfinding, grid presenter, action playback.
- **Minigame** (`scenes/runnables/minigame.tscn`) is the primary product (draft + battle). Main scene in `project.godot`.
- **Sandbox** (`unit_preview` / `sandbox_root`) is a second mode for spawn/fight — keep it so the engine stays modular and not overfit to minigame.
- Mode-specific code lives under `scripts/minigame/` (draft, deploy rules, AI drafter, win conditions) and sandbox session/root.
- Living board: **`doc/roadmap.md`** (bugs + milestones). Design docs in `doc/` (index: `doc/README.md`); open decisions in `doc/open_questions.md`. The old v0.1 board is frozen at `doc/archive/missions_v0.1.md`.

### Workflow
- **Always run unit tests** after code changes: `./run_tests.sh`. No Godot binary yet? `tools/get_godot.sh` downloads the official 4.6 build (SHA-512 checked), links `./godot_exe` and does the first import. CI runs the same suite on every push/PR (`.github/workflows/tests.yml`).
- Balance sims: `./run_balance.sh` (not part of the main unit suite).
- **Add tests first** when implementing new behavior (especially combat rules / edge cases).
- Prefer **headless, CLI-only** workflows for CI.
- Avoid flaky tests by controlling randomness (seed RNG or force deterministic state).

### Test harness conventions
- Tests live in `res://tests/` and are executed by `tests/run_tests.gd`.
- Test runner must print a clear summary and exit **0 on pass**, **non-zero on fail**.
- Prefer **logic-level unit tests** (no scenes) unless visuals/nodes are required.
- Headless exit may print `ObjectDB instances leaked` / resources still in use — known Godot autoload/test teardown noise; ignore unless a new test clearly owns the leak.

### Terrain/spawn/move test constraints
- Spawn/move behavior depends on `Tile.walkable`; tests must not fail due to random terrain.
- In tests, force tiles to a deterministic walkable state (e.g. `terrain_type="GRASS"`, `walkable=true`).

### UI panel requirements + style
- UI must be **scalable/adaptable**: render sections depending on context (draft tile panel vs battle legion strip).
- Style direction: **simple shapes**, **beige**, **rounded corners**, **thicker borders**, **large text**. Shared chrome: `UiTheme`, `UiStatIcons` (see `.cursor/rules/ui-chrome.mdc`).
- **Draft:** `TileInfoPanel` is **fixed width**, **anchored right**; **right-click** a tile to inspect; hides when leaving that tile.
- **Battle:** bottom **LegionStrip** / `BattleExpectationBar` for inspect; click any legion on the map to select and inspect (sticky until deselect or another legion). Unit details via **hover tooltips** on strip cells (not a separate right panel).
- Legion units list: **no “Unit 1/2 …” labels**; show **unit image + health bar** per unit (footprint-sized tiles on a 6×2 board).
- Stat rows use icon + number (heart/sword/bow/shield), not text-only labels.

### Data-driven unit stats
- Use Godot `Resource`-based unit definitions:
  - `UnitDefinition` per unit type (id, display_name, max_health, attack, icon; extend later).
  - `UnitDatabase` holds all definitions and provides lookup.
  - `UnitDefs` autoload provides `UnitDefs.get_def(id)` globally (models + UI + headless tests).
- `Unit` stats come from the DB; keep safe defaults if definition missing.
- Resource loading must work headless; `.tres` should be compatible with script-attached resources.

### AI (utility + whole-turn planning)
- In-game utility opponents (`utility`, `utility_hand`, `utility_evolved`) **plan whole turns** (`scripts/ai/planning/turn_planner.gd`). `*_greedy`, `utility_v0`, `utility:<file>` and evolution brains don't (fast, for tuning).
- The planner runs on `TurnSimSession` copies (`turn_sim_session.gd`). In the game, `BattlePhaseController._ai_sort_actionable` scores a copy on a `WorkerThreadPool` task with an 800 ms cap. Never mutate the live session from AI code that may run there.
- `UtilityBrain` caches (`_cache`, `_planned`) are keyed by **tile coords + board signature**, not object ids, so a copy's result applies to the live board. Keep the signature complete: anything scoring reads must be in `_board_signature`.
- Benchmark play strength with `./run_ai_duel.sh --draft mirror --play-sims --brain-a X --brain-b utility_v0`. Random drafts make about 85% of pairs split on the draft.

### Mixed legions (data model, 0.1.5)
- A legion is **any set of units**. Build one with `Legion.from_composition([[type, n], ...], coords, team)`.
- `Legion.unit_type` is only a *label*: the most numerous type, ties go to the first seen. Use it for the title, icon and click sounds. Rules, cost and stats must read `units`.
  - Helpers: `gold_value()`, `composition()`, `is_mixed()`, `count_of()`, `display_name()`.
- Rules:
  - Actions are the union over the unit types present.
  - Per-unit actions use the unit's own type. Ranged: shooters only. Heals: healers only, each with its own amount (`ActionParams.unit_heal_amounts`).
  - Legion-wide params take the largest value among the types that can perform the action.
  - Max AP is the lowest among the types present.
- Creating mixed legions in the draft UI is 0.4. The info panel still shows the first unit's attack/HP.

### Status effects (framework, 0.1.5)
- To add an effect, write a behaviour script extending `scripts/effects/status_behavior.gd` and a `data/status/<id>.tres` `StatusDefinition` pointing to it. Apply it with `StatusEffects.apply(legion, id, stacks, turns)`.
- Put rule changes in behaviour hooks, never directly in `CombatResolver` or the AI. Previews and the AI then pick them up through the resolver. See `doc/design/combat.md`.
- Anything that copies a legion must copy `statuses`. `CombatSimSnapshot.clone_legion` already does.

### Terrain, flying, fog (0.3)
- Read terrain only through `scripts/terrain/terrain_rules.gd`:
  - `enter_cost`, `modify_strike`, `has_los`, `is_flyer`.
  - Don't check `tile.walkable` for movement in new code; flyers ignore it.
- Every `CombatResolver.resolve_combat` / `CombatSampler.sample` / `CombatExpectation.estimate_combat` call that should see terrain must pass `TerrainRules.combat_options(grid, from, to)`.
- Fog: `scripts/terrain/visibility.gd`. Fog rules sit in `ActionTargeting.get_targets` (when `state.fog_of_war` is on); drawing is in `GridPresenter.sync_fog` (`fog_viewer_team`).

### Combat logic (current rules)
- Attacking legion **hits first**.
- Each unit **hits at most once per combat**.
- **Deaths are immediate**: dead units are removed and do not hit later.
- Hit order is **alternate-then-drain**:
  - alternate hits between legions while both have eligible attackers;
  - once one side is out of eligible attackers, the other side continues with remaining attackers.
- Per-hit trace: set `CombatResolver.quiet = false` (off by default; sims run thousands of combats).
- Combat resolver returns ordered hit/death logs for driving visuals.
- Melee and ranged are separate actions (`melee_attack`, `ranged_attack`). Counter-fire only if defender `attack_range` covers engagement distance.
- **Move is non-terminal** (does not `wait_legion`); combat/heal terminal actions do. "Done this turn" is `Legion.waited` (set by wait/pass and terminal actions, cleared for all legions on `end_team_turn`) — never track it by tile.
- Randomness in battle comes from the match RNG (`MatchSession.rng` / `next_rng_seed()`, seeded by `set_match_seed`). Don't call global `randi()`/`randf()` in rules or AI.
- Legion capabilities (`has_ranged`, `max_attack_range`, `unit_types`, `ActionDefs.legion_action_ids`) aggregate over all units — never read `units[0]` for rules.
- **Reference other scripts through `const X = preload("res://...")`, never only by global `class_name`.** A stale `.godot` class cache (branch pulled while the editor is open) makes bare class names fail to compile — that once froze every AI turn.
- AI "what if this legion stood there" queries go through `HypotheticalPosition.evaluate` (always restores the grid).
- Combat expectation (UI preview and AI) both sample via `CombatSampler` — one Monte Carlo loop over `CombatResolver`.

### Combat visuals requirements (current)
- Animations are **sequential** with a fixed delay between hits (`ActionPlayback.COMBAT_HIT_BEAT`, currently **0.4s**; 0.6s on a kill).
- Human attacks keep the attacker selected during playback (legion strip mirrors vitals live); AI turns deselect.
- Playback/AI coroutines must bail out if the host scene was freed (`is_instance_valid(host)`) — never touch nodes after an `await` without that check.
- Only the **attacking unit** animates attack and only the **target unit** animates being hit.
- Before combat begins, **both legions face each other**.
- When a unit dies, update the **legion visu immediately** (remove unit visu, re-pack).
- After combat, remaining units should **tween** into their re-packed positions (no snapping).

### Assets
- Runtime art lives under `assets/`. Unused / pipeline piles live under `assets/_archive/` — see `doc/assets_archive.md`.
- Prefer archiving over deleting until explicitly approved (speeches were an exception).
- Menu music: `assets/music/bgmusic_menu.wav`.
