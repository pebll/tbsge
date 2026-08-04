extends Node

## Persistable gameplay / UX options (battle log filters, AI debug, match setup).

signal settings_changed

const SETTINGS_PATH := "user://game_settings.cfg"
const SETTINGS_SECTION := "game"
const MATCH_SECTION := "match"

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")

const MAP_SIZE_OPTIONS := [3, 4, 5]
const MAP_SIZE_GOLD := {3: 75, 4: 125, 5: 200}

const DIFFICULTY_IDS := ["easy", "normal", "hard", "impossible"]
const DIFFICULTY_MULT := {
	"easy": 0.75,
	"normal": 1.0,
	"hard": 1.5,
	"impossible": 2.0,
}
const DIFFICULTY_LABELS := {
	"easy": "Easy",
	"normal": "Normal",
	"hard": "Hard",
	"impossible": "Impossible",
}

const MATCH_MODE_AI := "ai"
const MATCH_MODE_HOTSEAT := "hotseat"
const MATCH_MODE_IDS := [MATCH_MODE_AI, MATCH_MODE_HOTSEAT]

const DEFAULT_PLAYER_NAME := "Commander"
const DEFAULT_PLAYER2_NAME := "Challenger"

const AI_FUNNY_NAMES: Array[String] = [
	"Sir Tripsalot",
	"Hex Goblin",
	"Duke Oops",
	"Count Clickbait",
	"Lady Softblock",
]

var show_battle_log_moves: bool = false
var show_battle_log_end_turns: bool = false
var ai_debug_enabled: bool = false

## Last Play setup choices (persisted for the setup UI).
var match_map_size: int = 3
var match_difficulty: String = "normal"
var match_mode: String = MATCH_MODE_AI
var player_name: String = DEFAULT_PLAYER_NAME
var player2_name: String = DEFAULT_PLAYER2_NAME

## Match-scoped opponent label (AI roll or hotseat P2); cleared with launch.
var match_opponent_name: String = ""

## When true, MinigameRoot builds config from setup prefs (survives rematch).
var _match_launch_active: bool = false

func _ready() -> void:
	_load_settings()
	_apply_ai_debug_flag()

func set_show_battle_log_moves(value: bool, persist: bool = true) -> void:
	if show_battle_log_moves == value:
		return
	show_battle_log_moves = value
	_emit_and_maybe_save(persist)

func set_show_battle_log_end_turns(value: bool, persist: bool = true) -> void:
	if show_battle_log_end_turns == value:
		return
	show_battle_log_end_turns = value
	_emit_and_maybe_save(persist)

func set_ai_debug_enabled(value: bool, persist: bool = true) -> void:
	if ai_debug_enabled == value:
		return
	ai_debug_enabled = value
	_apply_ai_debug_flag()
	_emit_and_maybe_save(persist)

func is_ai_debug_enabled() -> bool:
	return AttackNearestEnemyBehavior.debug_enabled

func toggle_ai_debug(persist: bool = true) -> bool:
	set_ai_debug_enabled(not ai_debug_enabled, persist)
	return is_ai_debug_enabled()

func set_match_map_size(value: int, persist: bool = true) -> void:
	if value not in MAP_SIZE_OPTIONS:
		return
	if match_map_size == value:
		return
	match_map_size = value
	_emit_and_maybe_save(persist)

func set_match_difficulty(value: String, persist: bool = true) -> void:
	if value not in DIFFICULTY_IDS:
		return
	if match_difficulty == value:
		return
	match_difficulty = value
	_emit_and_maybe_save(persist)

func set_match_mode(value: String, persist: bool = true) -> void:
	if value not in MATCH_MODE_IDS:
		return
	if match_mode == value:
		return
	match_mode = value
	_emit_and_maybe_save(persist)

func set_player_name(value: String, persist: bool = true) -> void:
	var cleaned := value.strip_edges()
	# Ignore empty mid-edit; Start / begin_match_launch sanitize to default.
	if cleaned.is_empty():
		return
	if cleaned.length() > 24:
		cleaned = cleaned.substr(0, 24)
	if player_name == cleaned:
		return
	player_name = cleaned
	_emit_and_maybe_save(persist)

func set_player2_name(value: String, persist: bool = true) -> void:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		return
	if cleaned.length() > 24:
		cleaned = cleaned.substr(0, 24)
	if player2_name == cleaned:
		return
	player2_name = cleaned
	_emit_and_maybe_save(persist)

func commit_player_names(p1: String = "", p2: String = "") -> void:
	player_name = _sanitize_name(p1 if not p1.is_empty() else player_name, DEFAULT_PLAYER_NAME)
	player2_name = _sanitize_name(p2 if not p2.is_empty() else player2_name, DEFAULT_PLAYER2_NAME)
	_emit_and_maybe_save(true)

func is_hotseat_mode() -> bool:
	return match_mode == MATCH_MODE_HOTSEAT

func player_budget_for_map_size(map_size: int = -1) -> int:
	var size := match_map_size if map_size < 0 else map_size
	return int(MAP_SIZE_GOLD.get(size, 75))

func ai_budget_mult_for_difficulty(difficulty: String = "") -> float:
	if is_hotseat_mode():
		return 1.0
	var id := match_difficulty if difficulty.is_empty() else difficulty
	return float(DIFFICULTY_MULT.get(id, 1.0))

func begin_match_launch() -> void:
	_match_launch_active = true
	_ensure_match_opponent_name()

func clear_match_launch() -> void:
	_match_launch_active = false
	match_opponent_name = ""

func is_match_launch_active() -> bool:
	return _match_launch_active

func build_match_config() -> MinigameConfigScript:
	var config: MinigameConfigScript = MinigameConfigScript.new()
	var mode_tag := match_mode
	config.id = "match_r%d_%s_%s" % [match_map_size, match_difficulty, mode_tag]
	config.display_name = "Match"
	config.map_radius = match_map_size
	config.budget = player_budget_for_map_size()
	config.deploy_slot_count = 7
	config.team_ids = ["GREEN", "BLUE"]
	config.max_legion_fill = 12.0
	if is_hotseat_mode():
		config.ai_team_ids = []
		config.ai_budget_mult = 1.0
	else:
		config.ai_team_ids = ["BLUE"]
		config.ai_budget_mult = ai_budget_mult_for_difficulty()
	return config

func resolve_minigame_config(fallback_path: String) -> MinigameConfigScript:
	if _match_launch_active:
		return build_match_config()
	return load(fallback_path) as MinigameConfigScript

## Prefer match identity while a Play match is active; else TeamDefs / id.
func display_name_for_team(team_id: String) -> String:
	if team_id.is_empty():
		return "—"
	if _match_launch_active or not match_opponent_name.is_empty():
		if team_id == "GREEN":
			return _sanitize_name(player_name, DEFAULT_PLAYER_NAME)
		if team_id == "BLUE":
			var opp := match_opponent_name.strip_edges()
			if opp.is_empty():
				opp = player2_name if is_hotseat_mode() else ""
			return _sanitize_name(opp, "Opponent")
	var team_res: Resource = TeamDefs.get_def(team_id)
	if team_res is TeamDefinition:
		var name := (team_res as TeamDefinition).display_name.strip_edges()
		if not name.is_empty():
			return name
	return team_id

func apply_to_action_log(_action_log: BattleActionLog) -> void:
	# Visibility reads GameSettings directly; kept for call-site compatibility.
	pass

func _ensure_match_opponent_name() -> void:
	if is_hotseat_mode():
		match_opponent_name = _sanitize_name(player2_name, DEFAULT_PLAYER2_NAME)
		return
	# Rematch keeps the rolled AI name until main menu clears launch.
	if not match_opponent_name.strip_edges().is_empty():
		return
	match_opponent_name = AI_FUNNY_NAMES[randi() % AI_FUNNY_NAMES.size()]

func _sanitize_name(value: String, fallback: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		return fallback
	if cleaned.length() > 24:
		cleaned = cleaned.substr(0, 24)
	return cleaned

func _apply_ai_debug_flag() -> void:
	AttackNearestEnemyBehavior.debug_enabled = ai_debug_enabled

func _emit_and_maybe_save(persist: bool) -> void:
	settings_changed.emit()
	if persist:
		_save_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	show_battle_log_moves = bool(cfg.get_value(SETTINGS_SECTION, "show_battle_log_moves", false))
	show_battle_log_end_turns = bool(cfg.get_value(SETTINGS_SECTION, "show_battle_log_end_turns", false))
	ai_debug_enabled = bool(cfg.get_value(SETTINGS_SECTION, "ai_debug", false))

	var map_size := int(cfg.get_value(MATCH_SECTION, "map_size", 3))
	if map_size in MAP_SIZE_OPTIONS:
		match_map_size = map_size
	var difficulty := String(cfg.get_value(MATCH_SECTION, "difficulty", "normal"))
	if difficulty in DIFFICULTY_IDS:
		match_difficulty = difficulty
	var mode := String(cfg.get_value(MATCH_SECTION, "mode", MATCH_MODE_AI))
	if mode in MATCH_MODE_IDS:
		match_mode = mode
	player_name = _sanitize_name(
		String(cfg.get_value(MATCH_SECTION, "player_name", DEFAULT_PLAYER_NAME)),
		DEFAULT_PLAYER_NAME
	)
	player2_name = _sanitize_name(
		String(cfg.get_value(MATCH_SECTION, "player2_name", DEFAULT_PLAYER2_NAME)),
		DEFAULT_PLAYER2_NAME
	)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, "show_battle_log_moves", show_battle_log_moves)
	cfg.set_value(SETTINGS_SECTION, "show_battle_log_end_turns", show_battle_log_end_turns)
	cfg.set_value(SETTINGS_SECTION, "ai_debug", ai_debug_enabled)
	cfg.set_value(MATCH_SECTION, "map_size", match_map_size)
	cfg.set_value(MATCH_SECTION, "difficulty", match_difficulty)
	cfg.set_value(MATCH_SECTION, "mode", match_mode)
	cfg.set_value(MATCH_SECTION, "player_name", player_name)
	cfg.set_value(MATCH_SECTION, "player2_name", player2_name)
	cfg.save(SETTINGS_PATH)
