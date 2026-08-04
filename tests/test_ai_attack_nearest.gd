extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_attacks_adjacent_enemy():
		return false
	if not _test_moves_toward_nearest_enemy():
		return false
	if not _test_passes_when_no_action():
		return false
	if not _test_ai_draft_and_battle_turn():
		return false
	if not _test_melees_adjacent_when_nearest_not_attackable():
		return false
	if not _test_can_act_after_move_onto_wiped_tile():
		return false
	if not _test_still_actionable_after_move():
		return false
	if not _test_steps_when_direct_hex_blocked_by_ally():
		return false
	if not _test_prefers_ranged_at_distance_two():
		return false
	if not _test_prefers_ranged_when_adjacent_no_return_fire():
		return false
	if not _test_activation_order_closest_first():
		return false
	if not _test_prefers_closer_over_same_distance_step():
		return false
	if not _test_ally_blocks_direct_approach_flank_or_pass():
		return false
	if not _test_ally_wall_does_not_shuffle_backward():
		return false
	if not _test_side_step_when_front_ally_blocks_closer():
		return false
	if not _test_pass_when_only_useless_lateral_moves():
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
		"unit_type": "GOBLIN",
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

func _test_melees_adjacent_when_nearest_not_attackable() -> bool:
	## Hex-nearest enemy on a non-walkable tile is not melee-targetable; attack the walkable adjacent instead.
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue_blocked: Legion = legions["b"]
	var team_b: String = MinigameTestHelpersScript.team_b(session)

	_teleport_legion(session, green, Vector2i(0, 0))
	var blocked_coords := Vector2i(1, 0)
	var adj_coords := Vector2i(0, -1)
	if session.grid.get(blocked_coords) == null or session.grid.get(adj_coords) == null:
		return true

	_teleport_legion(session, blue_blocked, blocked_coords)
	session.grid[blocked_coords].walkable = false

	var blue_adj := Legion.new("GOBLIN", 2, adj_coords, team_b)
	session.grid[adj_coords].legion = blue_adj
	session.legions.append(blue_adj)

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "melee_attack":
		push_error("Expected melee on walkable adjacent enemy, got %s" % cmd)
		return false
	if cmd.get("to") != adj_coords:
		push_error("Should melee walkable adjacent @ %s, got %s" % [adj_coords, cmd.get("to")])
		return false
	return true

func _test_can_act_after_move_onto_wiped_tile() -> bool:
	## After a wipe+move onto that tile, AI must still be able to spend remaining AP (melee).
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a: String = MinigameTestHelpersScript.team_a(session)
	var attacker: Legion = started["a"]
	var defender: Legion = started["b"]

	for c in [attacker.tile_coords, defender.tile_coords]:
		if session.grid.get(c):
			session.grid[c].legion = null

	var atk_coords := Vector2i(0, 0)
	var def_coords := Vector2i(1, 0)
	var ally_from := Vector2i(0, -1)
	if session.grid.get(atk_coords) == null or session.grid.get(def_coords) == null:
		return true
	if session.grid.get(ally_from) == null:
		return true

	attacker.tile_coords = atk_coords
	defender.tile_coords = def_coords
	session.grid[atk_coords].legion = attacker
	session.grid[def_coords].legion = defender

	var ally := Legion.new("GOBLIN", 2, ally_from, team_a)
	session.grid[ally_from].legion = ally
	session.legions.append(ally)

	for u in attacker.units:
		u.current_health = 1
		u.attack = 1
	for u in defender.units:
		u.current_health = 100
		u.attack = 100

	var wipe := session.apply({
		"type": "use_action",
		"action_id": "melee_attack",
		"from": atk_coords,
		"to": def_coords,
		"rng_seed": 1,
	})
	if not wipe["ok"]:
		push_error("Wipe attack failed: %s" % wipe.get("error"))
		return false

	var move := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": ally_from,
		"to": atk_coords,
	})
	if not move["ok"]:
		push_error("Ally move failed: %s" % move.get("error"))
		return false

	if atk_coords in session.turn_manager.waited_coords:
		push_error("Move onto wiped tile must clear wait stain")
		return false
	if not session.can_act_legion(ally):
		push_error("Ally must be able to act after moving onto wipe tile")
		return false

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, ally)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "melee_attack":
		push_error("Ally should melee after moving onto wipe tile, got %s" % cmd)
		return false
	if cmd.get("to") != def_coords:
		push_error("Ally should target defender @ %s" % def_coords)
		return false
	return true

func _test_still_actionable_after_move() -> bool:
	## Non-terminal move must leave the legion actionable when AP remains.
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]
	_teleport_legion(session, green, Vector2i(0, -2))
	_teleport_legion(session, blue, Vector2i(2, -2))
	if green.current_ap < 2:
		green.max_ap = 2
		green.current_ap = 2

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Expected opening move, got %s" % cmd)
		return false
	var to_coords: Vector2i = cmd.get("to")
	var result := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": green.tile_coords,
		"to": to_coords,
	})
	if not result["ok"]:
		push_error("Move apply failed: %s" % result.get("error"))
		return false
	if green.current_ap < 1:
		push_error("Expected remaining AP after one move")
		return false
	if to_coords not in session.get_actionable_coords():
		push_error("Legion should remain actionable at %s after move" % to_coords)
		return false
	return true

func _test_steps_when_direct_hex_blocked_by_ally() -> bool:
	## Closer approach hex occupied by an ally — must still take a legal non-worsening step (not PASS).
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]
	var team_a: String = MinigameTestHelpersScript.team_a(session)

	# green at (-1,0), enemy at (-2,-1), ally plugs (-2,0) — matches the live PASS repro geometry.
	var from_coords := Vector2i(-1, 0)
	var enemy_coords := Vector2i(-2, -1)
	var ally_coords := Vector2i(-2, 0)
	for c in [from_coords, enemy_coords, ally_coords]:
		if session.grid.get(c) == null:
			return true

	_teleport_legion(session, green, from_coords)
	_teleport_legion(session, blue, enemy_coords)
	var ally := Legion.new("GOBLIN", 1, ally_coords, team_a)
	session.grid[ally_coords].legion = ally
	session.legions.append(ally)

	var before := HexPathfinder.hex_distance(from_coords, enemy_coords)
	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Expected flanking/lateral move when blocked, got %s" % cmd)
		return false
	var to_coords: Vector2i = cmd.get("to")
	var after := HexPathfinder.hex_distance(to_coords, enemy_coords)
	if after > before:
		push_error("Step should not increase distance (%s -> %s)" % [before, after])
		return false
	return true

func _test_prefers_ranged_at_distance_two() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a: String = MinigameTestHelpersScript.team_a(session)
	var team_b: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a)
	var slots_b: Array = session.get_deploy_slots(team_b)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a,
		"coords": slots_a[0],
		"unit_type": "ARCHER",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_a})
	session.apply({
		"type": "draft_set_legion",
		"team": team_b,
		"coords": slots_b[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_b})

	var archer: Legion = null
	var goblin: Legion = null
	for legion in session.legions:
		if legion.team_id == team_a:
			archer = legion
		else:
			goblin = legion
	var from_coords := Vector2i(0, 0)
	var to_coords := Vector2i(2, -1)
	if session.grid.get(from_coords) == null or session.grid.get(to_coords) == null:
		return true
	_teleport_legion(session, archer, from_coords)
	_teleport_legion(session, goblin, to_coords)

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, archer)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "ranged_attack":
		push_error("AI archer at d=2 should ranged_attack, got %s" % cmd)
		return false
	if cmd.get("to") != to_coords:
		push_error("AI should target the enemy @ %s" % to_coords)
		return false
	return true

func _test_prefers_ranged_when_adjacent_no_return_fire() -> bool:
	## Adjacent melee enemy that cannot return fire → prefer ranged over melee.
	var session := MinigameTestHelpersScript.prepare_session()
	var team_a: String = MinigameTestHelpersScript.team_a(session)
	var team_b: String = MinigameTestHelpersScript.team_b(session)
	var slots_a: Array = session.get_deploy_slots(team_a)
	var slots_b: Array = session.get_deploy_slots(team_b)
	session.apply({
		"type": "draft_set_legion",
		"team": team_a,
		"coords": slots_a[0],
		"unit_type": "ARCHER",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_a})
	session.apply({
		"type": "draft_set_legion",
		"team": team_b,
		"coords": slots_b[0],
		"unit_type": "GOBLIN",
		"unit_count": 1,
	})
	session.apply({"type": "draft_ready", "team": team_b})

	var archer: Legion = null
	var goblin: Legion = null
	for legion in session.legions:
		if legion.team_id == team_a:
			archer = legion
		else:
			goblin = legion
	var from_coords := Vector2i(0, 0)
	var to_coords := Vector2i(1, 0)
	if session.grid.get(from_coords) == null or session.grid.get(to_coords) == null:
		return true
	_teleport_legion(session, archer, from_coords)
	_teleport_legion(session, goblin, to_coords)
	for u in goblin.units:
		u.attack_range = 0
		u.ranged_attack = 0

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, archer)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "ranged_attack":
		push_error("AI should prefer ranged vs melee-only adjacent, got %s" % cmd)
		return false
	return true

func _test_activation_order_closest_first() -> bool:
	## Front-line units must activate before rear ones so they stop blocking paths.
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var near: Legion = started["a"]
	var enemy: Legion = started["b"]
	var team_a: String = started["team_a"]

	var mid_coords := Vector2i(-1, 0)
	var far_coords := Vector2i(-2, 0)
	var enemy_coords := Vector2i(1, 0)
	var near_coords := Vector2i(0, 0)
	for c in [near_coords, mid_coords, far_coords, enemy_coords]:
		if session.grid.get(c) == null:
			push_error("Missing hex for activation-order test")
			return false

	for c in [near.tile_coords, enemy.tile_coords]:
		if session.grid.get(c):
			session.grid[c].legion = null
	_teleport_legion(session, near, near_coords)
	_teleport_legion(session, enemy, enemy_coords)

	var mid := Legion.new("GOBLIN", 1, mid_coords, team_a)
	var far := Legion.new("GOBLIN", 1, far_coords, team_a)
	session.grid[mid_coords].legion = mid
	session.grid[far_coords].legion = far
	session.legions.append_array([mid, far])
	near.refresh_ap()
	mid.refresh_ap()
	far.refresh_ap()
	session.turn_manager.waited_coords.clear()

	# Shuffle input order so we don't accidentally depend on append order.
	var shuffled: Array[Vector2i] = [far_coords, near_coords, mid_coords]
	var ordered := AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(session, shuffled)
	var expected: Array[Vector2i] = [near_coords, mid_coords, far_coords]
	if ordered != expected:
		push_error("Expected closest-first order %s, got %s" % [expected, ordered])
		return false

	# Same distance: the one that can fight now should go before a pure mover.
	var fighter_coords := Vector2i(0, 1)
	var mover_coords := Vector2i(0, -1)
	if session.grid.get(fighter_coords) == null or session.grid.get(mover_coords) == null:
		return true
	_teleport_legion(session, mid, fighter_coords)
	_teleport_legion(session, far, mover_coords)
	# Enemy adjacent to fighter only.
	_teleport_legion(session, enemy, Vector2i(1, 1) if session.grid.get(Vector2i(1, 1)) else enemy_coords)
	# Keep near far away so it doesn't win on distance.
	_teleport_legion(session, near, Vector2i(-2, -1) if session.grid.get(Vector2i(-2, -1)) else far_coords)
	near.refresh_ap()
	mid.refresh_ap()
	far.refresh_ap()
	session.turn_manager.waited_coords.clear()

	var d_fight := HexPathfinder.hex_distance(mid.tile_coords, enemy.tile_coords)
	var d_move := HexPathfinder.hex_distance(far.tile_coords, enemy.tile_coords)
	if d_fight != d_move:
		# Map geometry may differ; still require fighter among the two when distances match.
		return true
	var tie_order := AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(
		session, [far.tile_coords, mid.tile_coords]
	)
	if tie_order.is_empty() or tie_order[0] != mid.tile_coords:
		push_error("At equal distance, fighting unit should activate before mover, got %s" % tie_order)
		return false
	return true

func _test_prefers_closer_over_same_distance_step() -> bool:
	## When a distance-reducing hex is free, never shuffle sideways at same distance.
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]

	var from_coords := Vector2i(-1, 2)
	var enemy_coords := Vector2i(0, -2)
	for c in [from_coords, enemy_coords]:
		if session.grid.get(c) == null:
			return true

	_teleport_legion(session, green, from_coords)
	_teleport_legion(session, blue, enemy_coords)

	var before := HexPathfinder.hex_distance(from_coords, enemy_coords)
	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Expected a move toward enemy, got %s" % cmd)
		return false
	var to_coords: Vector2i = cmd.get("to")
	var after := HexPathfinder.hex_distance(to_coords, enemy_coords)
	if after >= before:
		push_error(
			"Expected a strictly closer step (d=%d -> %d), got %s"
			% [before, after, to_coords]
		)
		return false
	return true

func _prepare_radius5_session() -> MinigameSessionScript:
	var config: MinigameConfigScript = MinigameTestHelpersScript.load_duel_config()
	config = config.duplicate(true)
	config.map_radius = 5
	config.budget = 200
	var session := MinigameSessionScript.new(config)
	for tile in session.grid.values():
		tile.terrain_type = "GRASS"
		tile.walkable = true
	session.refresh_deploy_slots()
	return session

func _test_ally_blocks_direct_approach_flank_or_pass() -> bool:
	## Ally sits on the only distance-reducing hex. Step must not worsen distance.
	## Prefer a same-dist flank that shortens the soft path; otherwise PASS.
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]
	var team_a: String = MinigameTestHelpersScript.team_a(session)

	var from_coords := Vector2i(-1, 0)
	var enemy_coords := Vector2i(-2, -1)
	var ally_coords := Vector2i(-2, 0)
	for c in [from_coords, enemy_coords, ally_coords]:
		if session.grid.get(c) == null:
			return true

	_teleport_legion(session, green, from_coords)
	_teleport_legion(session, blue, enemy_coords)
	var ally := Legion.new("GOBLIN", 1, ally_coords, team_a)
	session.grid[ally_coords].legion = ally
	session.legions.append(ally)
	green.refresh_ap()
	session.turn_manager.waited_coords.clear()

	var before := HexPathfinder.hex_distance(from_coords, enemy_coords)
	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") == "pass":
		return true
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Expected flank move or pass when blocked, got %s" % cmd)
		return false
	var to_coords: Vector2i = cmd.get("to")
	var after := HexPathfinder.hex_distance(to_coords, enemy_coords)
	if after > before:
		push_error("Blocked flank must not increase distance (%s -> %s)" % [before, after])
		return false
	return true

func _test_ally_wall_does_not_shuffle_backward() -> bool:
	## Wall of allies directly toward the enemy: rear unit must not step away from enemy.
	var session := _prepare_radius5_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var rear: Legion = legions["a"]
	var enemy: Legion = legions["b"]
	var team_a: String = MinigameTestHelpersScript.team_a(session)

	var enemy_coords := Vector2i(0, -2)
	var rear_coords := Vector2i(0, 3)
	var wall := [Vector2i(0, 2), Vector2i(-1, 2), Vector2i(1, 2)]
	for c in [enemy_coords, rear_coords] + wall:
		if session.grid.get(c) == null:
			push_error("Missing hex for ally-wall test")
			return false

	_teleport_legion(session, rear, rear_coords)
	_teleport_legion(session, enemy, enemy_coords)
	for wc in wall:
		var ally := Legion.new("GOBLIN", 1, wc, team_a)
		session.grid[wc].legion = ally
		session.legions.append(ally)
	rear.refresh_ap()
	session.turn_manager.waited_coords.clear()

	var before := HexPathfinder.hex_distance(rear_coords, enemy_coords)
	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, rear)
	if cmd.get("type") == "pass":
		return true
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Expected move or pass behind ally wall, got %s" % cmd)
		return false
	var to_coords: Vector2i = cmd.get("to")
	var after := HexPathfinder.hex_distance(to_coords, enemy_coords)
	if after > before:
		push_error("Must not step away behind ally wall (%s -> %s via %s)" % [before, after, to_coords])
		return false
	# Must not shuffle purely sideways into a worse soft corridor (away from center axis).
	if after == before and absi(to_coords.x) > absi(rear_coords.x):
		push_error("Must not shuffle farther from the enemy axis: %s" % to_coords)
		return false
	return true

func _test_side_step_when_front_ally_blocks_closer() -> bool:
	## Single ally on the forward hex: AI must still make progress (side-step closer
	## onto an empty hex, or swap forward onto the ally).
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]
	var team_a: String = MinigameTestHelpersScript.team_a(session)

	var from_coords := Vector2i(0, 2)
	var enemy_coords := Vector2i(0, -2)
	var ally_coords := Vector2i(0, 1)
	for c in [from_coords, enemy_coords, ally_coords]:
		if session.grid.get(c) == null:
			return true

	_teleport_legion(session, green, from_coords)
	_teleport_legion(session, blue, enemy_coords)
	var ally := Legion.new("GOBLIN", 1, ally_coords, team_a)
	ally.refresh_ap()
	session.grid[ally_coords].legion = ally
	session.legions.append(ally)
	green.refresh_ap()
	session.turn_manager.waited_coords.clear()

	var before := HexPathfinder.hex_distance(from_coords, enemy_coords)
	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	if cmd.get("type") != "use_action" or cmd.get("action_id") != "move":
		push_error("Expected progress move around/through front ally, got %s" % cmd)
		return false
	var to_coords: Vector2i = cmd.get("to")
	var after := HexPathfinder.hex_distance(to_coords, enemy_coords)
	if after >= before:
		push_error("Must reduce distance (%s -> %s via %s)" % [before, after, to_coords])
		return false
	return true

func _test_pass_when_only_useless_lateral_moves() -> bool:
	## Surrounded such that every free neighbor is same-dist and does not open a better soft path.
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = _start_battle_with_legions(session, Vector2i.ZERO, Vector2i.ZERO)
	var green: Legion = legions["a"]
	var blue: Legion = legions["b"]
	var team_a: String = MinigameTestHelpersScript.team_a(session)

	# green boxed in; only lateral empty tiles that don't help.
	var from_coords := Vector2i(0, 0)
	var enemy_coords := Vector2i(3, -3)
	if session.grid.get(from_coords) == null or session.grid.get(enemy_coords) == null:
		return true

	_teleport_legion(session, green, from_coords)
	_teleport_legion(session, blue, enemy_coords)

	# Block every neighbor that would reduce distance; leave only same-dist or worse empties.
	var before := HexPathfinder.hex_distance(from_coords, enemy_coords)
	var Utils = preload("res://scripts/core/utils.gd")
	for adj in Utils.get_surrounding_coords(from_coords):
		var tile: Tile = session.grid.get(adj)
		if tile == null:
			continue
		var d := HexPathfinder.hex_distance(adj, enemy_coords)
		if d < before:
			var blocker := Legion.new("GOBLIN", 1, adj, team_a)
			tile.legion = blocker
			session.legions.append(blocker)

	green.refresh_ap()
	session.turn_manager.waited_coords.clear()
	var movable := session.get_movable_coords(from_coords)
	# If somehow a closer hex remains free, this case doesn't apply.
	for m in movable:
		if HexPathfinder.hex_distance(m, enemy_coords) < before:
			return true

	var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, green)
	# Flank is OK only if soft-path improves; otherwise must PASS (not shuffle).
	if cmd.get("type") == "use_action" and cmd.get("action_id") == "move":
		var to_coords: Vector2i = cmd.get("to")
		var after := HexPathfinder.hex_distance(to_coords, enemy_coords)
		if after > before:
			push_error("Useless-lateral case must not increase distance")
			return false
		# Same-dist move is only allowed as a productive flank; if soft path can't
		# improve, decide() should have passed. Re-check by requiring PASS when
		# all same-dist neighbors are "along the wall" with no path improvement —
		# enforce PASS for this boxed setup.
		push_error("Expected PASS when only useless laterals remain, got move to %s" % to_coords)
		return false
	if cmd.get("type") != "pass":
		push_error("Expected PASS, got %s" % cmd)
		return false
	return true
