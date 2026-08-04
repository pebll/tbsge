extends Node

## Persistable gameplay / UX options (battle log filters, more later).

signal settings_changed

const SETTINGS_PATH := "user://game_settings.cfg"
const SETTINGS_SECTION := "game"

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")

var show_battle_log_moves: bool = false
var show_battle_log_end_turns: bool = false

func _ready() -> void:
	_load_settings()
	_sync_ai_debug_flag()

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
	if AttackNearestEnemyBehavior.debug_enabled == value:
		return
	AttackNearestEnemyBehavior.debug_enabled = value
	_emit_and_maybe_save(persist)

func is_ai_debug_enabled() -> bool:
	return AttackNearestEnemyBehavior.debug_enabled

func toggle_ai_debug(persist: bool = true) -> bool:
	set_ai_debug_enabled(not is_ai_debug_enabled(), persist)
	return is_ai_debug_enabled()

func apply_to_action_log(_action_log: BattleActionLog) -> void:
	# Visibility reads GameSettings directly; kept for call-site compatibility.
	pass

func _sync_ai_debug_flag() -> void:
	# AI debug is session-scoped (not persisted) — always start OFF.
	AttackNearestEnemyBehavior.debug_enabled = false

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

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, "show_battle_log_moves", show_battle_log_moves)
	cfg.set_value(SETTINGS_SECTION, "show_battle_log_end_turns", show_battle_log_end_turns)
	cfg.save(SETTINGS_PATH)
