class_name MinigamePhaseDeps
extends RefCounted

## Typed bag of dependencies for draft/battle phase controllers.
## Keeps mode orchestration out of the engine while remaining explicit.

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigamePresenterScript = preload("res://scripts/minigame/minigame_presenter.gd")
const BattleUIAdapterScript = preload("res://scripts/ui/battle_ui_adapter.gd")
const BattleActionRunnerScript = preload("res://scripts/battle/battle_action_runner.gd")

var host: Node
var session: MinigameSessionScript
var presenter: MinigamePresenterScript
var battle_ui: BattleUIAdapterScript
var action_runner: BattleActionRunnerScript
var action_playback: RefCounted
var setup_panel: MinigameSetupPanel
var unit_picker: MinigameUnitPicker
var turn_hud: TurnHud
var tile_info_panel: TileInfoPanel
var pass_overlay: PanelContainer
var status_label: Label
var game_over_panel: GameOverPanel
var action_bar: Control
var action_log_panel: BattleActionLogPanel
var pause_menu: PauseMenu

func config():
	return session.config if session else null

func first_team_id() -> String:
	var cfg = config()
	if cfg == null or cfg.team_ids.is_empty():
		return ""
	return String(cfg.team_ids[0])

func is_ai_team(team_id: String) -> bool:
	var cfg = config()
	return cfg != null and team_id in cfg.ai_team_ids
