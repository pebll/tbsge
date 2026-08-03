# FableQuest

Isometric turn-based strategy built in Godot 4. The repo is structured as a small **battle engine** plus **game modes** that reuse it.

## Architecture

- **Engine:** `MatchSession`, actions (`ActionResolver` / targeting), `CombatResolver`, `TurnManager`, hex pathfinding, `GridPresenter`, battle playback.
- **Modes:**
  - **Minigame** — draft → battle duel (`scenes/runnables/minigame.tscn`, main scene).
  - **Sandbox** — free spawn & fight (`scenes/runnables/unit_preview.tscn`); keeps the engine honest / not overfit to minigame.

Battle commands use `{"type": "use_action", "action_id": "move"|"melee_attack"|"ranged_attack"|"self_heal", ...}`.

## Run

- Editor: open the project and run the main scene (minigame), or use **Dev Test** from the menu.
- Headless tests: `./run_tests.sh` (or `flatpak run org.godotengine.Godot --headless --path . -s res://tests/run_tests.gd`).
- Balance sim: `./run_balance.sh`.
- Optional smoke script: `res://scripts/cli/cli_main.gd` (manual headless entry).

## Docs

See `AGENT_NOTES.md` for conventions (tests, combat rules, UI style).
