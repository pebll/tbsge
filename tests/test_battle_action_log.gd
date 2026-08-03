extends RefCounted

const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_move_and_heal_log_fields():
		return false
	if not _test_pass_and_end_turn_log():
		return false
	if not _test_log_cap():
		return false
	print("Success: Battle action log tests")
	return true

func _test_move_and_heal_log_fields() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	for u in green.units:
		u.current_health = max(1, u.max_health - 4)

	session.action_log.clear()
	var move_targets := session.get_action_targets(green, "move")
	if move_targets.is_empty():
		push_error("Expected move targets for log test")
		return false
	var move := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": green.tile_coords,
		"to": move_targets[0],
	})
	if not move["ok"]:
		push_error("Move failed in log test")
		return false
	var move_entry: Dictionary = session.action_log.latest()
	if String(move_entry.get("action_id", "")) != "move":
		push_error("Expected move log entry, got %s" % move_entry)
		return false
	if String(move_entry.get("result_summary", "")) != "moved":
		push_error("Expected moved result, got %s" % move_entry.get("result_summary"))
		return false
	if String(move_entry.get("caster_summary", "")).is_empty():
		push_error("Move log missing caster_summary")
		return false
	if not move_entry.has("from") or not move_entry.has("to"):
		push_error("Move log missing from/to")
		return false

	# Fresh legion with enough AP for heal (move spent 1).
	if green.current_ap < 2:
		# Pass and end turns until green can heal, or just set AP.
		green.current_ap = 2
		session.turn_manager.clear_wait(green.tile_coords)

	var heal := session.apply({
		"type": "use_action",
		"action_id": "self_heal",
		"from": green.tile_coords,
		"to": green.tile_coords,
	})
	if not heal["ok"]:
		push_error("Heal failed in log test: %s" % heal.get("error"))
		return false
	var heal_entry: Dictionary = session.action_log.latest()
	if String(heal_entry.get("action_id", "")) != "self_heal":
		push_error("Expected self_heal log entry")
		return false
	if "healed" not in String(heal_entry.get("result_summary", "")):
		push_error("Heal result_summary wrong: %s" % heal_entry.get("result_summary"))
		return false
	if int(heal_entry.get("turn", 0)) < 1:
		push_error("Log entry missing turn")
		return false
	if String(heal_entry.get("caster_unit_type", "")) != green.unit_type:
		push_error("Heal log should store caster_unit_type for sprites")
		return false
	return true

func _test_pass_and_end_turn_log() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	session.action_log.clear()

	var pass_result := session.apply({
		"type": "pass_legion",
		"coords": green.tile_coords,
	})
	if not pass_result["ok"]:
		push_error("Pass failed: %s" % pass_result.get("error"))
		return false
	var pass_entry: Dictionary = session.action_log.latest()
	if String(pass_entry.get("action_id", "")) != "pass":
		push_error("Expected pass log")
		return false
	if String(pass_entry.get("result_summary", "")) != "waited":
		push_error("Expected waited result")
		return false

	var end := session.apply({"type": "end_turn"})
	if not end["ok"]:
		push_error("End turn failed")
		return false
	var end_entry: Dictionary = session.action_log.latest()
	if String(end_entry.get("action_id", "")) != "end_turn":
		push_error("Expected end_turn log")
		return false
	if "ended" not in String(end_entry.get("result_summary", "")):
		push_error("End turn summary wrong")
		return false
	return true

func _test_log_cap() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	MinigameTestHelpersScript.start_two_legion_battle(session)
	session.action_log.clear()
	var cap: int = session.action_log.MAX_ENTRIES
	for i in range(cap + 25):
		session.action_log.append({
			"turn": 1,
			"team": "t",
			"action_id": "move",
			"from": Vector2i.ZERO,
			"to": Vector2i(i, 0),
			"caster_summary": "x",
			"target_summary": "",
			"result_summary": "moved",
			"payload": {},
		})
	if session.action_log.size() != cap:
		push_error("Expected log cap %d, got %d" % [cap, session.action_log.size()])
		return false
	return true
