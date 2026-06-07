extends RefCounted

const MinigameSession = preload("res://scripts/minigame/minigame_session.gd")
const MinigameConfig = preload("res://scripts/minigame/minigame_config.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_move_and_turns():
		return false
	if not _test_surrender():
		return false
	if not _test_victory_by_elimination():
		return false
	print("Success: Minigame battle tests")
	return true

func _load_config():
	return load("res://data/minigame/duel_r3.tres") as MinigameConfig

func _start_battle(session: MinigameSession) -> void:
	var green_slots: Array = session.get_deploy_slots("GREEN")
	var blue_slots: Array = session.get_deploy_slots("BLUE")
	session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": green_slots[0],
		"unit_type": "ARCHER",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": "GREEN"})
	session.apply({
		"type": "draft_set_legion",
		"team": "BLUE",
		"coords": blue_slots[0],
		"unit_type": "AXEMAN",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": "BLUE"})

func _test_move_and_turns() -> bool:
	var session := MinigameSession.new(_load_config())
	_start_battle(session)
	if session.turn_manager.active_team_id != "GREEN":
		push_error("GREEN should move first")
		return false

	var green_legion: Legion = session.legions[0]
	var from_coords := green_legion.tile_coords
	var movable := session.get_movable_coords(from_coords)
	if movable.is_empty():
		push_error("Expected at least one movable tile")
		return false

	var move := session.apply({
		"type": "move",
		"from": from_coords,
		"to": movable[0],
	})
	if not move["ok"]:
		push_error("Move failed: %s" % move["error"])
		return false

	var end_turn := session.apply({"type": "end_turn"})
	if not end_turn["ok"]:
		push_error("End turn failed")
		return false
	if session.turn_manager.active_team_id != "BLUE":
		push_error("Expected BLUE turn after end_turn")
		return false
	return true

func _test_surrender() -> bool:
	var session := MinigameSession.new(_load_config())
	_start_battle(session)
	var result := session.apply({"type": "surrender", "team": "GREEN"})
	if not result["ok"]:
		push_error("Surrender failed")
		return false
	if session.winner != "BLUE":
		push_error("Expected BLUE to win by surrender")
		return false
	if session.phase != MinigameSession.Phase.ENDED:
		push_error("Expected ENDED phase")
		return false
	return true

func _test_victory_by_elimination() -> bool:
	var session := MinigameSession.new(_load_config())
	var green_slots: Array = session.get_deploy_slots("GREEN")
	var blue_slots: Array = session.get_deploy_slots("BLUE")
	session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": green_slots[0],
		"unit_type": "FLAME",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": "GREEN"})
	session.apply({
		"type": "draft_set_legion",
		"team": "BLUE",
		"coords": blue_slots[0],
		"unit_type": "ARCHER",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": "BLUE"})

	var green_legion: Legion = null
	var blue_legion: Legion = null
	for legion in session.legions:
		if legion.team_id == "GREEN":
			green_legion = legion
		else:
			blue_legion = legion
	if green_legion == null or blue_legion == null:
		push_error("Missing legions")
		return false

	_move_legion_to(session, green_legion, Vector2i(0, -1))
	_move_legion_to(session, blue_legion, Vector2i(1, -1))

	for u in green_legion.units:
		u.attack = 100
	for u in blue_legion.units:
		u.max_health = 1
		u.current_health = 1

	var attack := session.apply({
		"type": "attack",
		"from": green_legion.tile_coords,
		"to": blue_legion.tile_coords,
		"rng_seed": 99,
	})
	if not attack["ok"]:
		push_error("Attack failed: %s" % attack["error"])
		return false
	if session.phase != MinigameSession.Phase.ENDED:
		push_error("Expected match to end after elimination")
		return false
	if session.winner != "GREEN":
		push_error("Expected GREEN to win")
		return false
	return true

func _move_legion_to(session: MinigameSession, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion
