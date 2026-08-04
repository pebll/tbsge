extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_move_and_turns():
		return false
	if not _test_surrender():
		return false
	if not _test_victory_by_elimination():
		return false
	print("Success: Minigame battle tests")
	return true

func _test_move_and_turns() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	if session.turn_manager.active_team_id != team_a_id:
		push_error("%s should move first" % team_a_id)
		return false

	var legion_a: Legion = session.legions[0]
	var from_coords := legion_a.tile_coords
	var movable := session.get_movable_coords(from_coords)
	if movable.is_empty():
		push_error("Expected at least one movable tile")
		return false

	var move: Dictionary = session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": from_coords,
		"to": movable[0],
	})
	if not move["ok"]:
		push_error("Move failed: %s" % move["error"])
		return false

	var end_turn: Dictionary = session.apply({"type": "end_turn"})
	if not end_turn["ok"]:
		push_error("End turn failed")
		return false
	if session.turn_manager.active_team_id != team_b_id:
		push_error("Expected %s turn after end_turn" % team_b_id)
		return false
	return true

func _test_surrender() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var result: Dictionary = session.apply({"type": "surrender", "team": team_a_id})
	if not result["ok"]:
		push_error("Surrender failed")
		return false
	if session.winner != team_b_id:
		push_error("Expected %s to win by surrender" % team_b_id)
		return false
	if session.phase != MinigameSessionScript.Phase.ENDED:
		push_error("Expected ENDED phase")
		return false
	return true

func _teleport_legion(session, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

func _test_victory_by_elimination() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a_id)
	var slots_b: Array = session.get_deploy_slots(team_b_id)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots_a[0],
		"unit_type": "SCORPION_RIDER",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_a_id})
	session.apply({
		"type": "draft_set_legion",
		"team": team_b_id,
		"coords": slots_b[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_b_id})

	var demon: Legion = null
	var goblin: Legion = null
	for legion in session.legions:
		if legion.team_id == team_a_id:
			demon = legion
		elif legion.team_id == team_b_id:
			goblin = legion
	if demon == null or goblin == null:
		push_error("Expected demon and goblin legions")
		return false

	var demon_coords := Vector2i(0, -1)
	var goblin_coords := Vector2i(1, -1)
	_teleport_legion(session, demon, demon_coords)
	_teleport_legion(session, goblin, goblin_coords)

	var target: Vector2i = goblin_coords

	var attack: Dictionary = session.apply({
		"type": "use_action",
		"action_id": "melee_attack",
		"from": demon_coords,
		"to": target,
		"rng_seed": 42,
	})
	if not attack["ok"]:
		push_error("Attack failed: %s" % attack["error"])
		return false
	if session.phase != MinigameSessionScript.Phase.ENDED:
		push_error("Expected match to end after elimination")
		return false
	if session.winner != team_a_id:
		push_error("Expected %s to win by elimination" % team_a_id)
		return false
	return true
