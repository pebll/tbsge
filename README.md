# FableQuest

Isometric turn-based strategy built in Godot 4. The repo is structured as a small **battle engine** plus **game modes** that reuse it.

## Architecture

- **Engine:** `MatchSession`, actions (`ActionResolver` / targeting), `CombatResolver`, `TurnManager`, hex pathfinding, `GridPresenter`, battle playback.
- **Modes:**
  - **Minigame** — draft → battle duel (`scenes/runnables/minigame.tscn`, main scene).
  - **Sandbox** — free spawn & fight (`scenes/runnables/unit_preview.tscn`); keeps the engine honest / not overfit to minigame.

Battle commands use `{"type": "use_action", "action_id": "move"|"melee_attack"|"ranged_attack"|"self_heal"|"heal_ally"|"teleport"|"pass", ...}`.

## Battle UX (Aug 2026)

- **Legion strip** (bottom HUD): select any legion (yours, enemy, 0 AP) to inspect; 6×2 unit board with footprints; aggregate stats + unit hover tooltips. Replaces the right `TileInfoPanel` **in battle** (draft still uses the right panel).
- **Battle log** (left dock): icon stat cards, team-colored turn banners; combat/heal entries appear at action start and **tick live** with playback.
- **Expectation preview**: hover valid attack/heal targets to see min–max damage/loss/heal ranges before committing.
- **Action bar**: all actions visible; unavailable ones greyed with reason in tooltip.

## Run

- Editor: open the project and run the main scene (minigame). **Play** is the primary path; **Dev Test** is for lab/sandbox variants.
- Headless tests: `./run_tests.sh` (or `flatpak run org.godotengine.Godot --headless --path . -s res://tests/run_tests.gd`).
- Balance sim: `./run_balance.sh`.
- Optional smoke script: `res://scripts/cli/cli_main.gd` (manual headless entry).

## Docs

See `AGENT_NOTES.md` for conventions (tests, combat rules, UI style).  
See `MISSIONS.md` for the living short-term / features checklist.
