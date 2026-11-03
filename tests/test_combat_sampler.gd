extends RefCounted

const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const BattleExpectationEstimator = preload("res://scripts/battle/battle_expectation_estimator.gd")

## UI preview and AI expectation share CombatSampler, so they must agree.

func run(_tree: SceneTree) -> bool:
	if not _test_ui_range_contains_ai_mean():
		return false
	if not _test_sampler_leaves_originals_untouched():
		return false
	if not _test_heal_keeps_fractional_hp():
		return false
	print("Success: Combat sampler / heal precision tests")
	return true

func _test_ui_range_contains_ai_mean() -> bool:
	var atk := Legion.new("GOBLIN", 4, Vector2i(0, 0), "GREEN")
	var def := Legion.new("GOLEM", 2, Vector2i(1, 0), "BLUE")
	var n := 16
	BattleExpectationEstimator.clear_cache()
	var prev_n: int = GameSettings.battle_expectation_sim_count
	GameSettings.battle_expectation_sim_count = n
	var ui: Dictionary = BattleExpectationEstimator.estimate(atk, def, "melee_attack", atk.tile_coords, def.tile_coords)
	GameSettings.battle_expectation_sim_count = prev_n
	var ai: Dictionary = CombatExpectation.estimate_combat(atk, def, "melee_attack", atk.tile_coords, def.tile_coords, n)
	var mean_enemy: float = float(ai["enemy_loss_mean"])
	if mean_enemy < float(ui["enemy_damage_min"]) - 0.5 or mean_enemy > float(ui["enemy_damage_max"]) + 0.5:
		push_error("AI mean enemy loss %.2f outside UI range %s-%s" % [mean_enemy, ui["enemy_damage_min"], ui["enemy_damage_max"]])
		return false
	var mean_deaths: float = float(ai["enemy_kills_mean"])
	if mean_deaths < float(ui["enemy_losses_min"]) or mean_deaths > float(ui["enemy_losses_max"]):
		push_error("AI mean kills %.2f outside UI loss range" % mean_deaths)
		return false
	return true

func _test_sampler_leaves_originals_untouched() -> bool:
	var atk := Legion.new("GOBLIN", 3, Vector2i(0, 0), "GREEN")
	var def := Legion.new("GOBLIN", 3, Vector2i(1, 0), "BLUE")
	var hp_before := CombatSampler.total_hp(def)
	var rows := CombatSampler.sample(atk, def, "melee", 1, 8)
	if rows.size() != 8:
		push_error("Expected 8 samples")
		return false
	if CombatSampler.total_hp(def) != hp_before or def.units.size() != 3:
		push_error("Sampling must not mutate the real legions")
		return false
	var again := CombatSampler.sample(atk, def, "melee", 1, 8)
	if again != rows:
		push_error("Same N must give the same samples")
		return false
	return true

func _test_heal_keeps_fractional_hp() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var unit: Unit = green.units[0]
	unit.current_health = unit.max_health - 2.5
	var action_def: ActionDefinition = ActionDefs.get_def("self_heal")
	if ActionParams.resolve_int(green, action_def, "heal_amount", action_def.heal_amount) >= 3:
		# Make sure the heal can't simply cap at max (we want to see the .5 survive).
		unit.current_health = unit.max_health - 20.5
		if unit.current_health <= 0.0:
			unit.current_health = 0.5
	var result := session.apply({
		"type": "use_action",
		"action_id": "self_heal",
		"from": green.tile_coords,
		"to": green.tile_coords,
	})
	if not result["ok"]:
		push_error("Self heal failed: %s" % result.get("error"))
		return false
	var action: ActionDefinition = ActionDefs.get_def("self_heal")
	var heal := float(ActionParams.resolve_int(green, action, "heal_amount", action.heal_amount))
	# Every caster unit heals the (only) wounded unit until it is full.
	var start_hp := unit.max_health - 2.5
	if heal >= 3.0:
		start_hp = unit.max_health - 20.5 if unit.max_health - 20.5 > 0.0 else 0.5
	var expected := minf(unit.max_health, start_hp + heal * green.units.size())
	if not is_equal_approx(unit.current_health, expected):
		push_error("Heal truncated fractional HP: %.2f, expected %.2f" % [unit.current_health, expected])
		return false
	return true
