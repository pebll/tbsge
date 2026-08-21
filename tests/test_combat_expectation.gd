extends RefCounted

const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_train_play_sim_counts():
		return false
	if not _test_estimate_adjacent_melee():
		return false
	if not _test_higher_n_reduces_spread_tendency():
		return false
	print("Success: Combat expectation MC tests")
	return true

func _teleport_legion(session, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

func _test_train_play_sim_counts() -> bool:
	CombatExpectation.use_train_mode()
	if CombatExpectation.get_sim_count() != CombatExpectation.TRAIN_SIM_COUNT:
		push_error("Train mode should set TRAIN_SIM_COUNT")
		return false
	CombatExpectation.use_play_mode()
	if CombatExpectation.get_sim_count() != CombatExpectation.PLAY_SIM_COUNT:
		push_error("Play mode should set PLAY_SIM_COUNT")
		return false
	return true

func _test_estimate_adjacent_melee() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	CombatExpectation.set_sim_count(8)
	var est: Dictionary = CombatExpectation.estimate_combat(
		green, blue, "melee_attack", green.tile_coords, blue.tile_coords
	)
	if int(est.get("sim_count", 0)) != 8:
		push_error("Expected sim_count 8")
		return false
	if float(est.get("enemy_loss_mean", 0.0)) <= 0.0:
		push_error("Expected positive enemy loss from melee")
		return false
	if float(est.get("kill_prob", -1.0)) < 0.0 or float(est.get("kill_prob", 2.0)) > 1.0:
		push_error("kill_prob should be in [0,1]")
		return false
	# Live legions must be untouched.
	if green.units.is_empty() or blue.units.is_empty():
		push_error("MC must not mutate live legions")
		return false
	CombatExpectation.use_play_mode()
	return true

func _test_higher_n_reduces_spread_tendency() -> bool:
	## Smoke: both N return sane spreads; not asserting strict inequality (RNG).
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	var low: Dictionary = CombatExpectation.estimate_combat(
		green, blue, "melee_attack", green.tile_coords, blue.tile_coords, 2
	)
	var high: Dictionary = CombatExpectation.estimate_combat(
		green, blue, "melee_attack", green.tile_coords, blue.tile_coords, 20
	)
	if float(low.get("enemy_loss_mean", 0.0)) <= 0.0:
		push_error("Low-N estimate should deal damage")
		return false
	if float(high.get("enemy_loss_mean", 0.0)) <= 0.0:
		push_error("High-N estimate should deal damage")
		return false
	return true
