extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_attacks_adjacent_enemy():
		return false
	if not _test_moves_toward_nearest_enemy():
		return false
	if not _test_passes_when_no_action():
		return false
	if not _test_ai_draft_and_battle_turn():
		return false
	print("Success: AI attack-nearest tests")
	return true

func _start_battle_with_legions(
	session,
	team_a_coords: Vector2i,
	team_b_coords: Vector2i
) -> Dictionary:
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a_id)
	var slots_b: Array = session.get_deploy_slots(team_b_id)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": team_a_coords if team_a_coords != Vector2i.ZERO else slots_a[0],
		"unit_type": "GOBLIN",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": team_a_id})
	session.apply({
		"type": "draft_set_legion",
		"team": team_b_id,
		"coords": team_b_coords if team_b_coords != Vector2i.ZERO else slots_b[0],
		"unit_type": "RAT_SPEAR",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": team_b_id})
	var legion_a: Legion = null
	var legion_b: Legion = null
	for legion in session.legions:
		if legion.team_id == team_a_id:
			legion_a = legion
		else:
			legion_b = legion
	return {"a": legion_a, "b": legion_b}

func _teleport_legion(session, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

func _test_attacks_adjacent_enemy() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]
	_teleport_legion(session, green, Vector2i(0, -1))
	_teleport_legion(session, blue, Vector2i(1, -1))

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "melee_attack":
		push_error("Expected melee_attack command, got %s" % cmd)
		return false
	if cmd.get("from") != green.tile_coords or cmd.get("to") != blue.tile_coords:
		push_error("Attack should target adjacent enemy")
		return false
	return true

func _test_moves_toward_nearest_enemy() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(2, -2))

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Expected move toward enemy, got %s" % cmd)
		return false
	if cmd.get("from") != green.tile_coords:
		push_error("Move should start from the acting legion")
		return false
	var to_coords: Vector2i = cmd.get("to")
	if to_coords not in session.get_movable_coords(green.tile_coords):
		push_error("Move target must be a legal step")
		return false
	return true

func _test_passes_when_no_action() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	green.spend_all_ap()
	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "pass":
		push_error("Expected pass when legion has no AP")
		return false
	return true

func _test_ai_draft_and_battle_turn() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var team_b_id: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a_id)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a_id,
		"coords": slots_a[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_a_id})

	var AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var draft_cmds: Array = AiDrafter.build_draft_commands(session, team_b_id, rng)
	for cmd in draft_cmds:
		var result: Dictionary = session.apply(cmd)
		if not result["ok"]:
			push_error("AI draft command failed: %s" % result["error"])
			return false
	if session.phase != MinigameSessionScript.Phase.BATTLE:
		push_error("Expected battle after AI draft")
		return false

	session.apply({"type": "end_turn"})
	if session.turn_manager.active_team_id != team_b_id:
		push_error("Expected %s turn" % team_b_id)
		return false

	var blue_legion: Legion = null
	for legion in session.legions:
		if legion.team_id == team_b_id:
			blue_legion = legion
			break
	if blue_legion == null:
		push_error("AI should have drafted at least one legion")
		return false

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, blue_legion)
	if cmd.get("type") not in ["use_action", "pass"]:
		push_error("AI should return a battle command")
		return false
	return true
