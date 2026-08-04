extends RefCounted

const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_budget_for_team():
		return false
	if not _test_session_asymmetric_budgets():
		return false
	if not _test_ai_debug_persists_in_settings():
		return false
	if not _test_build_match_config():
		return false
	print("Success: Match setup / settings tests")
	return true

func _test_budget_for_team() -> bool:
	var config := MinigameConfigScript.new()
	config.budget = 100
	config.ai_budget_mult = 1.5
	config.team_ids = ["GREEN", "BLUE"]
	config.ai_team_ids = ["BLUE"]
	if config.budget_for_team("GREEN") != 100:
		push_error("Expected player budget 100, got %d" % config.budget_for_team("GREEN"))
		return false
	if config.budget_for_team("BLUE") != 150:
		push_error("Expected AI budget 150, got %d" % config.budget_for_team("BLUE"))
		return false
	return true

func _test_session_asymmetric_budgets() -> bool:
	var config := MinigameConfigScript.new()
	config.map_radius = 3
	config.budget = 80
	config.ai_budget_mult = 0.75
	config.deploy_slot_count = 7
	config.team_ids = ["GREEN", "BLUE"]
	config.ai_team_ids = ["BLUE"]
	var session := MinigameSessionScript.new(config)
	if session.drafts["GREEN"].budget_total != 80:
		push_error("Expected GREEN budget_total 80")
		return false
	if session.drafts["BLUE"].budget_total != 60:
		push_error("Expected BLUE budget_total 60, got %d" % session.drafts["BLUE"].budget_total)
		return false
	return true

func _test_ai_debug_persists_in_settings() -> bool:
	var prev_flag := GameSettings.ai_debug_enabled
	var prev_behavior := AttackNearestEnemyBehavior.debug_enabled
	GameSettings.set_ai_debug_enabled(true)
	if not GameSettings.is_ai_debug_enabled():
		push_error("Expected AI debug ON after set")
		_restore_ai_debug(prev_flag, prev_behavior)
		return false

	# Simulate a fresh apply from the persisted field (boot path).
	GameSettings.ai_debug_enabled = true
	AttackNearestEnemyBehavior.debug_enabled = false
	GameSettings._apply_ai_debug_flag()
	if not AttackNearestEnemyBehavior.debug_enabled:
		push_error("Expected _apply_ai_debug_flag to restore ON")
		_restore_ai_debug(prev_flag, prev_behavior)
		return false

	# Round-trip through ConfigFile using the real settings path.
	GameSettings.set_ai_debug_enabled(true)
	var cfg := ConfigFile.new()
	if cfg.load(GameSettings.SETTINGS_PATH) != OK:
		push_error("Expected settings file after save")
		_restore_ai_debug(prev_flag, prev_behavior)
		return false
	if not bool(cfg.get_value(GameSettings.SETTINGS_SECTION, "ai_debug", false)):
		push_error("Expected ai_debug saved as true")
		_restore_ai_debug(prev_flag, prev_behavior)
		return false

	_restore_ai_debug(prev_flag, prev_behavior)
	return true

func _test_build_match_config() -> bool:
	var prev_size := GameSettings.match_map_size
	var prev_diff := GameSettings.match_difficulty
	GameSettings.set_match_map_size(5, false)
	GameSettings.set_match_difficulty("hard", false)
	var config := GameSettings.build_match_config()
	var ok := true
	if config.map_radius != 5:
		push_error("Expected map_radius 5")
		ok = false
	if config.budget != 200:
		push_error("Expected player budget 200, got %d" % config.budget)
		ok = false
	if not is_equal_approx(config.ai_budget_mult, 1.5):
		push_error("Expected ai_budget_mult 1.5")
		ok = false
	if config.budget_for_team("BLUE") != 300:
		push_error("Expected AI budget 300, got %d" % config.budget_for_team("BLUE"))
		ok = false
	GameSettings.set_match_map_size(prev_size, false)
	GameSettings.set_match_difficulty(prev_diff, false)
	return ok

func _restore_ai_debug(flag: bool, behavior: bool) -> void:
	GameSettings.ai_debug_enabled = flag
	AttackNearestEnemyBehavior.debug_enabled = behavior
	# Persist the restored preference so we don't leave test pollution ON.
	GameSettings._save_settings()
