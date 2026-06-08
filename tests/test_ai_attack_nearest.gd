extends RefCounted

const MinigameSession = preload("res://scripts/minigame/minigame_session.gd")
const MinigameConfig = preload("res://scripts/minigame/minigame_config.gd")
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

func _load_config() -> MinigameConfig:
	return load("res://data/minigame/duel_r3.tres") as MinigameConfig

func _prepare_session() -> MinigameSession:
	var session := MinigameSession.new(_load_config())
	for tile in session.grid.values():
		tile.terrain_type = "GRASS"
		tile.walkable = true
	session.refresh_deploy_slots()
	return session

func _start_battle_with_legions(
	session: MinigameSession,
	green_coords: Vector2i,
	blue_coords: Vector2i
) -> Dictionary:
	var green_slots: Array = session.get_deploy_slots("GREEN")
	var blue_slots: Array = session.get_deploy_slots("BLUE")
	session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": green_coords if green_coords != Vector2i.ZERO else green_slots[0],
		"unit_type": "GOBLIN",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": "GREEN"})
	session.apply({
		"type": "draft_set_legion",
		"team": "BLUE",
		"coords": blue_coords if blue_coords != Vector2i.ZERO else blue_slots[0],
		"unit_type": "RAT_SPEAR",
		"unit_count": 2,
	})
	session.apply({"type": "draft_ready", "team": "BLUE"})
	var green_legion: Legion = null
	var blue_legion: Legion = null
	for legion in session.legions:
		if legion.team_id == "GREEN":
			green_legion = legion
		else:
			blue_legion = legion
	return {"green": green_legion, "blue": blue_legion}

func _teleport_legion(session: MinigameSession, legion: Legion, coords: Vector2i) -> void:
	var old_tile: Tile = session.grid.get(legion.tile_coords)
	if old_tile:
		old_tile.legion = null
	legion.tile_coords = coords
	var new_tile: Tile = session.grid.get(coords)
	if new_tile:
		new_tile.legion = legion

func _test_attacks_adjacent_enemy() -> bool:
	var session := _prepare_session()
	var legions := _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["green"]
	var blue: Legion = legions["blue"]
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
	var session := _prepare_session()
	var legions := _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["green"]
	var blue: Legion = legions["blue"]
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
	var session := _prepare_session()
	var legions := _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["green"]
	green.spend_all_ap()
	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "pass":
		push_error("Expected pass when legion has no AP")
		return false
	return true

func _test_ai_draft_and_battle_turn() -> bool:
	var session := _prepare_session()
	var green_slots: Array = session.get_deploy_slots("GREEN")
	session.apply({
		"type": "draft_set_legion",
		"team": "GREEN",
		"coords": green_slots[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": "GREEN"})

	var AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var draft_cmds: Array = AiDrafter.build_draft_commands(session, "BLUE", rng)
	for cmd in draft_cmds:
		var result := session.apply(cmd)
		if not result["ok"]:
			push_error("AI draft command failed: %s" % result["error"])
			return false
	if session.phase != MinigameSession.Phase.BATTLE:
		push_error("Expected battle after AI draft")
		return false

	session.apply({"type": "end_turn"})
	if session.turn_manager.active_team_id != "BLUE":
		push_error("Expected BLUE turn")
		return false

	var blue_legion: Legion = null
	for legion in session.legions:
		if legion.team_id == "BLUE":
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
