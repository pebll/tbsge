extends RefCounted

const BattleExpectationEstimator = preload("res://scripts/battle/battle_expectation_estimator.gd")
const CombatSimSnapshot = preload("res://scripts/battle/combat_sim_snapshot.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_clone_preserves_vitals():
		return false
	if not _test_estimate_bounds():
		return false
	if not _test_estimate_cache():
		return false
	print("Success: Battle expectation estimator tests")
	return true

func _make_legion(unit_type: String, count: int, team_id: String) -> Legion:
	return Legion.new(unit_type, count, Vector2i.ZERO, team_id)

func _test_clone_preserves_vitals() -> bool:
	var legion := _make_legion("goblin", 2, "GREEN")
	legion.units[0].current_health = 5
	legion.units[0].shield_remaining = 1
	var copy := CombatSimSnapshot.clone_legion(legion)
	if copy.units.size() != 2:
		push_error("Clone should preserve unit count")
		return false
	if int(copy.units[0].current_health) != 5 or copy.units[0].shield_remaining != 1:
		push_error("Clone should preserve vitals")
		return false
	return true

func _test_estimate_bounds() -> bool:
	var attacker := _make_legion("goblin", 4, "GREEN")
	var defender := _make_legion("goblin", 4, "BLUE")
	var prev_sims := GameSettings.battle_expectation_sim_count
	var prev_log := GameSettings.battle_expectation_log_timing
	GameSettings.battle_expectation_sim_count = 20
	GameSettings.battle_expectation_log_timing = false
	BattleExpectationEstimator.clear_cache()

	var result: Dictionary = BattleExpectationEstimator.estimate(
		attacker,
		defender,
		"melee_attack",
		Vector2i(0, 0),
		Vector2i(1, 0)
	)
	GameSettings.battle_expectation_sim_count = prev_sims
	GameSettings.battle_expectation_log_timing = prev_log

	if int(result.get("sim_count", 0)) != 20:
		push_error("Expected 20 sims, got %s" % result.get("sim_count"))
		return false
	if int(result.get("enemy_damage_min", -1)) < 0:
		push_error("Enemy damage min should be non-negative")
		return false
	if int(result.get("enemy_damage_max", -1)) < int(result.get("enemy_damage_min", 0)):
		push_error("Enemy damage max should be >= min")
		return false
	if float(result.get("elapsed_ms", -1.0)) < 0.0:
		push_error("Elapsed ms should be recorded")
		return false
	return true

func _test_estimate_cache() -> bool:
	var attacker := _make_legion("archer", 3, "GREEN")
	var defender := _make_legion("goblin", 3, "BLUE")
	var prev_sims := GameSettings.battle_expectation_sim_count
	var prev_log := GameSettings.battle_expectation_log_timing
	GameSettings.battle_expectation_sim_count = 10
	GameSettings.battle_expectation_log_timing = false
	BattleExpectationEstimator.clear_cache()

	var first: Dictionary = BattleExpectationEstimator.estimate(
		attacker,
		defender,
		"ranged_attack",
		Vector2i(0, 0),
		Vector2i(0, 2)
	)
	var second: Dictionary = BattleExpectationEstimator.estimate(
		attacker,
		defender,
		"ranged_attack",
		Vector2i(0, 0),
		Vector2i(0, 2)
	)
	GameSettings.battle_expectation_sim_count = prev_sims
	GameSettings.battle_expectation_log_timing = prev_log

	if bool(first.get("cached", false)):
		push_error("First estimate should not be cached")
		return false
	if not bool(second.get("cached", false)):
		push_error("Second estimate should be cached")
		return false
	if int(first.get("enemy_damage_min", -1)) != int(second.get("enemy_damage_min", -2)):
		push_error("Cached estimate should match original")
		return false
	return true
