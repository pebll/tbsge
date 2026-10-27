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
	if not _test_wipe_prob():
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

func _test_wipe_prob() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))
	CombatExpectation.set_sim_count(6)
	# Guaranteed wipe: a lone 1-HP defender.
	blue.units.resize(1)
	blue.units[0].current_health = 1
	var sure: Dictionary = CombatExpectation.estimate_combat(
		green, blue, "melee_attack", green.tile_coords, blue.tile_coords
	)
	if not sure.has("wipe_prob") or float(sure["wipe_prob"]) < 0.99:
		push_error("Expected wipe_prob ~1 vs lone 1-HP unit, got %s" % sure.get("wipe_prob"))
		CombatExpectation.use_play_mode()
		return false
	# Impossible wipe: huge defender stack with several units.
	for i in range(3):
		blue.units.append(Unit.new("GOBLIN"))
	for u in blue.units:
		u.max_health = 9999.0
		u.current_health = 9999.0
	var never: Dictionary = CombatExpectation.estimate_combat(
		green, blue, "melee_attack", green.tile_coords, blue.tile_coords
	)
	CombatExpectation.use_play_mode()
	if not never.has("wipe_prob") or float(never["wipe_prob"]) != 0.0:
		push_error("Expected wipe_prob 0 vs huge stack, got %s" % never.get("wipe_prob"))
		return false
	if float(CombatExpectation.estimate_combat(null, null, "melee_attack", Vector2i.ZERO, Vector2i.ZERO).get("wipe_prob", -1.0)) != 0.0:
		push_error("Empty estimate should carry wipe_prob 0")
		return false
	return true
