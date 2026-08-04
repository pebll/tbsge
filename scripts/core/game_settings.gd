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

var show_battle_log_moves: bool = false
var show_battle_log_end_turns: bool = false
var ai_debug_enabled: bool = false

## Last Play setup choices (persisted for the setup UI).
var match_map_size: int = 3
var match_difficulty: String = "normal"

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

func player_budget_for_map_size(map_size: int = -1) -> int:
	var size := match_map_size if map_size < 0 else map_size
	return int(MAP_SIZE_GOLD.get(size, 75))

func ai_budget_mult_for_difficulty(difficulty: String = "") -> float:
	var id := match_difficulty if difficulty.is_empty() else difficulty
	return float(DIFFICULTY_MULT.get(id, 1.0))

func begin_match_launch() -> void:
	_match_launch_active = true

func clear_match_launch() -> void:
	_match_launch_active = false

func is_match_launch_active() -> bool:
	return _match_launch_active

func build_match_config() -> MinigameConfigScript:
	var config: MinigameConfigScript = MinigameConfigScript.new()
	config.id = "match_r%d_%s" % [match_map_size, match_difficulty]
	config.display_name = "Match"
	config.map_radius = match_map_size
	config.budget = player_budget_for_map_size()
	config.ai_budget_mult = ai_budget_mult_for_difficulty()
	config.deploy_slot_count = 7
	config.team_ids = ["GREEN", "BLUE"]
	config.ai_team_ids = ["BLUE"]
	config.max_legion_fill = 12.0
	return config

func resolve_minigame_config(fallback_path: String) -> MinigameConfigScript:
	if _match_launch_active:
		return build_match_config()
	return load(fallback_path) as MinigameConfigScript

func apply_to_action_log(_action_log: BattleActionLog) -> void:
	# Visibility reads GameSettings directly; kept for call-site compatibility.
	pass

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

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, "show_battle_log_moves", show_battle_log_moves)
	cfg.set_value(SETTINGS_SECTION, "show_battle_log_end_turns", show_battle_log_end_turns)
	cfg.set_value(SETTINGS_SECTION, "ai_debug", ai_debug_enabled)
	cfg.set_value(MATCH_SECTION, "map_size", match_map_size)
	cfg.set_value(MATCH_SECTION, "difficulty", match_difficulty)
	cfg.save(SETTINGS_PATH)
