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
	if not _test_hotseat_match_config():
		return false
	if not _test_display_names_and_opponent_roll():
		return false
	if not _test_ai_vs_ai_match_config():
		return false
	if not _test_ai_vs_ai_display_names():
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
	var prev_mode := GameSettings.match_mode
	GameSettings.set_match_mode(GameSettings.MATCH_MODE_AI, false)
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
	if config.ai_team_ids.size() != 1 or String(config.ai_team_ids[0]) != "BLUE":
		push_error("Expected AI team BLUE in vs-AI mode")
		ok = false
	GameSettings.set_match_map_size(prev_size, false)
	GameSettings.set_match_difficulty(prev_diff, false)
	GameSettings.set_match_mode(prev_mode, false)
	return ok

func _test_hotseat_match_config() -> bool:
	var prev_mode := GameSettings.match_mode
	var prev_size := GameSettings.match_map_size
	var prev_diff := GameSettings.match_difficulty
	GameSettings.set_match_mode(GameSettings.MATCH_MODE_HOTSEAT, false)
	GameSettings.set_match_map_size(4, false)
	GameSettings.set_match_difficulty("impossible", false)
	var config := GameSettings.build_match_config()
	var ok := true
	if not config.ai_team_ids.is_empty():
		push_error("Hotseat should have no AI teams")
		ok = false
	if not is_equal_approx(config.ai_budget_mult, 1.0):
		push_error("Hotseat ai_budget_mult should be 1.0")
		ok = false
	if config.budget_for_team("GREEN") != config.budget_for_team("BLUE"):
		push_error("Hotseat budgets should match")
		ok = false
	if config.budget_for_team("GREEN") != 125:
		push_error("Expected radius-4 gold 125")
		ok = false
	GameSettings.set_match_mode(prev_mode, false)
	GameSettings.set_match_map_size(prev_size, false)
	GameSettings.set_match_difficulty(prev_diff, false)
	return ok

func _test_display_names_and_opponent_roll() -> bool:
	var prev_mode := GameSettings.match_mode
	var prev_p1 := GameSettings.player_name
	var prev_p2 := GameSettings.player2_name
	var prev_opp := GameSettings.match_opponent_name
	var prev_launch := GameSettings.is_match_launch_active()

	GameSettings.clear_match_launch()
	GameSettings.set_match_mode(GameSettings.MATCH_MODE_AI, false)
	GameSettings.player_name = "TestHero"
	GameSettings.begin_match_launch()
	var ok := true
	if GameSettings.match_opponent_name.is_empty():
		push_error("Expected AI opponent name after begin_match_launch")
		ok = false
	elif GameSettings.match_opponent_name not in GameSettings.AI_FUNNY_NAMES:
		push_error("Opponent name not in AI pool: %s" % GameSettings.match_opponent_name)
		ok = false
	if GameSettings.display_name_for_team("GREEN") != "TestHero":
		push_error("Expected GREEN display TestHero")
		ok = false
	if GameSettings.display_name_for_team("BLUE") != GameSettings.match_opponent_name:
		push_error("Expected BLUE display to match opponent")
		ok = false

	# Rematch keeps the same AI name.
	var kept := GameSettings.match_opponent_name
	GameSettings.begin_match_launch()
	if GameSettings.match_opponent_name != kept:
		push_error("Rematch should keep opponent name")
		ok = false

	GameSettings.clear_match_launch()
	GameSettings.set_match_mode(GameSettings.MATCH_MODE_HOTSEAT, false)
	GameSettings.player2_name = "Buddy"
	GameSettings.begin_match_launch()
	if GameSettings.match_opponent_name != "Buddy":
		push_error("Hotseat opponent should be player2_name")
		ok = false
	if not GameSettings.build_match_config().ai_team_ids.is_empty():
		push_error("Hotseat launch config must clear AI teams")
		ok = false

	GameSettings.clear_match_launch()
	GameSettings.match_mode = prev_mode
	GameSettings.player_name = prev_p1
	GameSettings.player2_name = prev_p2
	GameSettings.match_opponent_name = prev_opp
	if prev_launch:
		GameSettings.begin_match_launch()
	return ok

func _test_ai_vs_ai_match_config() -> bool:
	var prev_mode := GameSettings.match_mode
	var prev_size := GameSettings.match_map_size
	GameSettings.set_match_mode(GameSettings.MATCH_MODE_AI_VS_AI, false)
	GameSettings.set_match_map_size(3, false)
	var config := GameSettings.build_match_config()
	var ok := true
	if config.ai_team_ids.size() != 2:
		push_error("AI vs AI should have 2 AI teams, got %d" % config.ai_team_ids.size())
		ok = false
	if not config.is_ai_team("GREEN"):
		push_error("GREEN should be AI in AI vs AI mode")
		ok = false
	if not config.is_ai_team("BLUE"):
		push_error("BLUE should be AI in AI vs AI mode")
		ok = false
	if not is_equal_approx(config.ai_budget_mult, 1.0):
		push_error("AI vs AI budget mult should be 1.0")
		ok = false
	if config.budget_for_team("GREEN") != config.budget_for_team("BLUE"):
		push_error("AI vs AI budgets should be equal")
		ok = false
	GameSettings.set_match_mode(prev_mode, false)
	GameSettings.set_match_map_size(prev_size, false)
	return ok

func _test_ai_vs_ai_display_names() -> bool:
	var prev_mode := GameSettings.match_mode
	var prev_opp := GameSettings.match_opponent_name
	var prev_launch := GameSettings.is_match_launch_active()

	GameSettings.clear_match_launch()
	GameSettings.set_match_mode(GameSettings.MATCH_MODE_AI_VS_AI, false)
	GameSettings.begin_match_launch()
	var ok := true
	var green_name := GameSettings.display_name_for_team("GREEN")
	var blue_name := GameSettings.display_name_for_team("BLUE")
	if green_name.is_empty() or green_name == "Commander":
		push_error("AI vs AI GREEN should get AI name, got: %s" % green_name)
		ok = false
	if blue_name.is_empty() or blue_name == "Commander":
		push_error("AI vs AI BLUE should get AI name, got: %s" % blue_name)
		ok = false
	if green_name == blue_name:
		push_error("AI vs AI names should differ: %s vs %s" % [green_name, blue_name])
		ok = false

	GameSettings.clear_match_launch()
	GameSettings.match_mode = prev_mode
	GameSettings.match_opponent_name = prev_opp
	if prev_launch:
		GameSettings.begin_match_launch()
	return ok

func _restore_ai_debug(flag: bool, behavior: bool) -> void:
	GameSettings.ai_debug_enabled = flag
	AttackNearestEnemyBehavior.debug_enabled = behavior
	# Persist the restored preference so we don't leave test pollution ON.
	GameSettings._save_settings()
