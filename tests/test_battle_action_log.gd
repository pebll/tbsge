extends RefCounted

const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_move_and_heal_log_fields():
		return false
	if not _test_pass_and_end_turn_log():
		return false
	if not _test_filter_defaults():
		return false
	if not _test_path_coalesce_logs_once():
		return false
	if not _test_combat_wipe_and_teams():
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
	if not bool(move_entry.get("show_coords", false)):
		push_error("Move log should flag show_coords")
		return false
	if String(move_entry.get("coord_text", "")).is_empty():
		push_error("Move log should include coord_text")
		return false
	if String(move_entry.get("caster_summary", "")).is_empty():
		push_error("Move log missing caster_summary")
		return false
	if not move_entry.has("from") or not move_entry.has("to"):
		push_error("Move log missing from/to")
		return false
	if String(move_entry.get("caster_team_id", "")).is_empty():
		push_error("Move log should store caster_team_id for banners")
		return false

	# Fresh legion with enough AP for heal (move spent 1).
	if green.current_ap < 2:
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
	if int(heal_entry.get("healed_total", 0)) <= 0:
		push_error("Heal log should store healed_total for icon UI")
		return false
	if not BattleActionLog.should_defer_ui(heal_entry):
		push_error("Heal log should defer UI until playback finishes")
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
	if session.action_log.size() != 0:
		push_error("Wait/pass should not write battle log entries")
		return false

	var end := session.apply({"type": "end_turn"})
	if not end["ok"]:
		push_error("End turn failed")
		return false
	var end_entry: Dictionary = session.action_log.latest()
	if String(end_entry.get("action_id", "")) != "turn_start":
		push_error("Expected turn_start log, got %s" % end_entry.get("action_id", ""))
		return false
	var summary := String(end_entry.get("result_summary", ""))
	if not summary.begins_with("Turn start:"):
		push_error("Expected 'Turn start: …' summary, got %s" % summary)
		return false
	# After GREEN ends global turn 1, BLUE's first turn is team-turn 1.
	if int(end_entry.get("turn", -1)) != 1:
		push_error("Expected team-local turn 1 for second player, got %s" % end_entry.get("turn"))
		return false
	return true

func _test_filter_defaults() -> bool:
	GameSettings.set_show_battle_log_moves(false, false)
	GameSettings.set_show_battle_log_end_turns(false, false)
	var log := BattleActionLog.new()
	if log.is_entry_visible({"action_id": "move"}):
		push_error("Move entries should be hidden by default")
		return false
	if log.is_entry_visible({"action_id": "swap"}):
		push_error("Swap entries should be hidden by default")
		return false
	if log.is_entry_visible({"action_id": "move", "result_summary": "moved"}):
		push_error("Moved result_summary should follow moves filter")
		return false
	if log.is_entry_visible({"action_id": "end_turn"}):
		push_error("Turn start entries should be hidden by default")
		return false
	if log.is_entry_visible({"action_id": "turn_start"}):
		push_error("Turn start entries should be hidden by default")
		return false
	if not log.is_entry_visible({"action_id": "melee_attack"}):
		push_error("Combat entries should stay visible")
		return false
	if log.is_entry_visible({"action_id": "pass"}):
		push_error("Wait/pass entries should never show")
		return false
	if not log.is_entry_visible({"action_id": "teleport"}):
		push_error("Teleport entries should stay visible")
		return false
	if not log.is_entry_visible({"action_id": "teleport", "show_coords": true}):
		push_error("Teleport coord cards should stay visible when moves are off")
		return false
	GameSettings.set_show_battle_log_moves(true, false)
	if not log.is_entry_visible({"action_id": "move"}):
		push_error("Moves should appear when option enabled")
		return false
	if not log.is_entry_visible({"action_id": "teleport"}):
		push_error("Teleport should still appear when moves are enabled")
		return false
	GameSettings.set_show_battle_log_end_turns(true, false)
	if not log.is_entry_visible({"action_id": "turn_start"}):
		push_error("Turn starts should appear when option enabled")
		return false
	if not log.is_entry_visible({"action_id": "end_turn"}):
		push_error("Legacy end_turn id should still follow turn-start filter")
		return false
	GameSettings.set_show_battle_log_moves(false, false)
	GameSettings.set_show_battle_log_end_turns(false, false)
	return true

func _test_path_coalesce_logs_once() -> bool:
	## Multi-hex move with skip_action_log + log_move_relocation → one card.
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	green.current_ap = max(green.current_ap, 3)
	session.turn_manager.clear_wait(green.tile_coords)

	var start: Vector2i = green.tile_coords
	var move_targets := session.get_action_targets(green, "move")
	if move_targets.is_empty():
		push_error("Expected move targets for path coalesce test")
		return false
	var mid: Vector2i = move_targets[0]

	session.action_log.clear()
	var step1 := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": start,
		"to": mid,
		"skip_action_log": true,
	})
	if not step1["ok"]:
		push_error("Path step 1 failed: %s" % step1.get("error"))
		return false
	if session.action_log.size() != 0:
		push_error("skip_action_log should not append after step 1")
		return false

	# Prefer a second hop when AP + geometry allow; else coalesce the single hop.
	var end: Vector2i = mid
	var second_targets := session.get_action_targets(green, "move")
	for t in second_targets:
		if t == start:
			continue
		var step2 := session.apply({
			"type": "use_action",
			"action_id": "move",
			"from": mid,
			"to": t,
			"skip_action_log": true,
		})
		if step2.get("ok", false):
			end = t
			break

	if session.action_log.size() != 0:
		push_error("Silent path steps should not log, got %d" % session.action_log.size())
		return false
	session.log_move_relocation(start, end, false)
	if session.action_log.size() != 1:
		push_error("Expected exactly one coalesced path log, got %d" % session.action_log.size())
		return false
	var entry: Dictionary = session.action_log.latest()
	if String(entry.get("action_id", "")) != "move":
		push_error("Coalesced entry should be move")
		return false
	if entry.get("from") != start or entry.get("to") != end:
		push_error("Coalesced entry should span full path %s -> %s, got %s -> %s"
			% [start, end, entry.get("from"), entry.get("to")])
		return false
	if String(entry.get("coord_text", "")) != "%d,%d" % [end.x, end.y]:
		push_error("Coalesced coord_text should be final tile")
		return false
	return true

func _test_combat_wipe_and_teams() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	var red: Legion = legions["b"]
	var atk := Vector2i(0, 0)
	var def := Vector2i(1, 0)
	if session.grid.get(atk) == null or session.grid.get(def) == null:
		push_error("Expected adjacent tiles for wipe log test")
		return false
	for c in [green.tile_coords, red.tile_coords]:
		if session.grid.get(c):
			session.grid[c].legion = null
	_teleport(session, green, atk)
	_teleport(session, red, def)

	# Leave defender on one low-HP unit so a hit can wipe the legion.
	while red.units.size() > 1:
		red.units.pop_back()
	if red.units.is_empty():
		push_error("Expected at least one defender unit")
		return false
	red.units[0].current_health = 1
	for u in green.units:
		u.attack = 50

	session.action_log.clear()
	var attack_targets := session.get_action_targets(green, "melee_attack")
	if attack_targets.is_empty():
		push_error("Expected melee targets for wipe log test")
		return false

	var attack := session.apply({
		"type": "use_action",
		"action_id": "melee_attack",
		"from": green.tile_coords,
		"to": attack_targets[0],
		"rng_seed": 1,
	})
	if not attack["ok"]:
		push_error("Melee failed in wipe log test: %s" % attack.get("error"))
		return false
	var entry: Dictionary = session.action_log.latest()
	if String(entry.get("action_id", "")) != "melee_attack":
		push_error("Expected melee log entry")
		return false
	if String(entry.get("caster_team_id", "")).is_empty():
		push_error("Combat log missing caster_team_id")
		return false
	if String(entry.get("target_team_id", "")).is_empty():
		push_error("Combat log missing target_team_id")
		return false
	if not BattleActionLog.should_defer_ui(entry):
		push_error("Combat log should defer UI")
		return false
	if not entry.has("target_wiped") or not entry.has("caster_wiped"):
		push_error("Combat log should include wipe flags")
		return false
	if not bool(entry.get("target_wiped", false)):
		push_error("Expected target_wiped after overkill melee")
		return false
	return true

func _teleport(session, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

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
			"caster_unit_type": "GOBLIN",
			"target_unit_type": "",
			"caster_team_id": "t",
			"target_team_id": "",
			"caster_hp_lost": 0,
			"caster_deaths": 0,
			"target_hp_lost": 0,
			"target_deaths": 0,
			"caster_wiped": false,
			"target_wiped": false,
			"healed_total": 0,
			"show_coords": true,
			"coord_text": "%d,0" % i,
			"payload": {},
		})
	if session.action_log.size() != cap:
		push_error("Expected log cap %d, got %d" % [cap, session.action_log.size()])
		return false
	return true
