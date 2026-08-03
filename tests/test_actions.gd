extends RefCounted

const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_self_heal_costs_two_ap_and_ends_turn():
		return false
	if not _test_move_then_heal_impossible():
		return false
	if not _test_swap_via_move_action():
		return false
	if not _test_stale_legion_not_actionable():
		return false
	if not _test_self_heal_unavailable_at_full_hp():
		return false
	if not _test_move_onto_wiped_attacker_tile_can_still_act():
		return false
	if not _test_ranged_attack_session_e2e():
		return false
	if not _test_ranged_targeting_bounds():
		return false
	if not _test_action_failures():
		return false
	if not _test_wait_stain_survivor_and_end_turn():
		return false
	if not _test_swap_onto_stained_empty_tile():
		return false
	if not _test_heal_ally_basic_and_terminal():
		return false
	if not _test_heal_ally_rejects_enemy_and_full_hp():
		return false
	if not _test_heal_ally_param_override_range():
		return false
	print("Success: Action system tests")
	return true

func _test_self_heal_costs_two_ap_and_ends_turn() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	for u in green.units:
		u.current_health = max(1, u.max_health - 4)

	var result := session.apply({
		"type": "use_action",
		"action_id": "self_heal",
		"from": green.tile_coords,
		"to": green.tile_coords,
	})
	if not result["ok"]:
		push_error("Self heal failed: %s" % result.get("error"))
		return false
	if green.current_ap != 0:
		push_error("Heal should spend all AP (terminal)")
		return false
	if green.tile_coords not in session.turn_manager.waited_coords:
		push_error("Heal should end legion turn")
		return false
	return true

func _test_move_then_heal_impossible() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	var move_targets := session.get_action_targets(green, "move")
	if move_targets.is_empty():
		push_error("Expected a move target")
		return false
	var move := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": green.tile_coords,
		"to": move_targets[0],
	})
	if not move["ok"]:
		push_error("Move failed")
		return false
	if green.current_ap != 1:
		push_error("Move should leave 1 AP")
		return false
	var heal_def: ActionDefinition = ActionDefs.get_def("self_heal")
	if ActionTargetingScript.can_use(session.battle_state(), green, heal_def):
		push_error("Should not be able to heal after move with only 1 AP left")
		return false
	return true

func _test_swap_via_move_action() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a_id: String = MinigameTestHelpersScript.team_a(session)
	var green_a: Legion = legions["a"]
	var green_slots: Array = session.get_deploy_slots(team_a_id)
	if green_slots.size() < 2:
		return true
	var swap_coords: Vector2i = green_slots[1]
	var swap_tile: Tile = session.grid.get(swap_coords)
	if swap_tile == null or swap_tile.has_legion():
		return true
	var green_b := Legion.new("GOBLIN", 2, swap_coords, team_a_id)
	swap_tile.legion = green_b
	session.legions.append(green_b)

	var result := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": green_a.tile_coords,
		"to": swap_coords,
	})
	if not result["ok"]:
		push_error("Swap via move failed: %s" % result.get("error"))
		return false
	if "legions_swapped" not in result.get("events", []):
		push_error("Expected legions_swapped event")
		return false
	return true

func _test_stale_legion_not_actionable() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	var coords := green.tile_coords
	var tile: Tile = session.grid.get(coords)
	tile.legion = null
	if coords in session.get_actionable_coords():
		push_error("Stale legion should not be actionable")
		return false
	session.pass_legion_or_force_wait(coords)
	if coords not in session.turn_manager.waited_coords:
		push_error("force-wait should mark coords as waited")
		return false
	return true

func _test_self_heal_unavailable_at_full_hp() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var legions: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = legions["a"]
	var heal_def: ActionDefinition = ActionDefs.get_def("self_heal")
	if ActionTargetingScript.can_use(session.battle_state(), green, heal_def):
		push_error("Self heal should be unavailable at full HP")
		return false
	if not session.get_action_targets(green, "self_heal").is_empty():
		push_error("Self heal should have no targets at full HP")
		return false
	return true

func _test_move_onto_wiped_attacker_tile_can_still_act() -> bool:
	## Terminal combat that wipes the attacker used to leave a waited-coords stain.
	## A follow-up ally moving onto that tile must still be allowed to act.
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a: String = MinigameTestHelpersScript.team_a(session)
	var attacker: Legion = started["a"]
	var defender: Legion = started["b"]

	var old_a := attacker.tile_coords
	var old_b := defender.tile_coords
	if session.grid.get(old_a):
		session.grid[old_a].legion = null
	if session.grid.get(old_b):
		session.grid[old_b].legion = null

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

	# Keep team A alive after the wipe so the match does not end.
	var ally := Legion.new("GOBLIN", 2, ally_from, team_a)
	session.grid[ally_from].legion = ally
	session.legions.append(ally)

	for u in attacker.units:
		u.current_health = 1
		u.attack = 1
	for u in defender.units:
		u.current_health = 100
		u.attack = 100

	var result := session.apply({
		"type": "use_action",
		"action_id": "melee_attack",
		"from": atk_coords,
		"to": def_coords,
		"rng_seed": 1,
	})
	if not result["ok"]:
		push_error("Setup attack failed: %s" % result.get("error"))
		return false
	if session.grid[atk_coords].legion != null:
		push_error("Expected attacker tile to be empty after wipe")
		return false
	if atk_coords in session.turn_manager.waited_coords:
		push_error("Wait stain should clear when attacker tile is vacated")
		return false

	var move := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": ally_from,
		"to": atk_coords,
	})
	if not move["ok"]:
		push_error("Ally move onto wiped tile failed: %s" % move.get("error"))
		return false
	if ally.tile_coords != atk_coords:
		push_error("Ally should occupy wiped tile")
		return false
	if atk_coords not in session.get_actionable_coords():
		push_error("Ally on former wipe tile should still be actionable with remaining AP")
		return false

	var melee := session.apply({
		"type": "use_action",
		"action_id": "melee_attack",
		"from": atk_coords,
		"to": def_coords,
		"rng_seed": 2,
	})
	if not melee["ok"]:
		push_error("Ally melee from former wipe tile rejected: %s" % melee.get("error"))
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

func _test_ranged_attack_session_e2e() -> bool:
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
	var to_coords := Vector2i(2, -1) # hex distance 2
	if session.grid.get(from_coords) == null or session.grid.get(to_coords) == null:
		return true
	_teleport(session, archer, from_coords)
	_teleport(session, goblin, to_coords)

	var result := session.apply({
		"type": "use_action",
		"action_id": "ranged_attack",
		"from": from_coords,
		"to": to_coords,
		"rng_seed": 7,
	})
	if not result["ok"]:
		push_error("Ranged attack failed: %s" % result.get("error"))
		return false
	if archer.tile_coords != from_coords:
		push_error("Ranged attacker should not move")
		return false
	if goblin.tile_coords != to_coords:
		push_error("Ranged defender should stay put")
		return false
	if from_coords not in session.turn_manager.waited_coords:
		push_error("Ranged attack is terminal and should wait attacker tile")
		return false
	if "combat_resolved" not in result.get("events", []):
		push_error("Expected combat_resolved event")
		return false
	return true

func _test_ranged_targeting_bounds() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]

	# Goblin (melee-only) cannot use ranged_attack.
	var goblin_targets := session.get_action_targets(green, "ranged_attack")
	if not goblin_targets.is_empty():
		push_error("Melee-only unit should have no ranged targets")
		return false

	# Replace green with archer for targeting check.
	var from_coords := Vector2i(0, 0)
	var near := Vector2i(1, 0)
	var far := Vector2i(2, -1)
	var too_far := Vector2i(3, -1)
	for c in [from_coords, near, far, too_far]:
		if session.grid.get(c) == null:
			return true

	for c in [green.tile_coords, blue.tile_coords]:
		if session.grid.get(c):
			session.grid[c].legion = null
	session.legions.erase(green)

	var archer := Legion.new("ARCHER", 1, from_coords, MinigameTestHelpersScript.team_a(session))
	session.grid[from_coords].legion = archer
	session.legions.append(archer)
	_teleport(session, blue, far)

	var targets := session.get_action_targets(archer, "ranged_attack")
	if far not in targets:
		push_error("Enemy at distance 2 should be ranged-targetable")
		return false
	_teleport(session, blue, too_far)
	targets = session.get_action_targets(archer, "ranged_attack")
	if too_far in targets:
		push_error("Enemy beyond attack_range should not be ranged-targetable")
		return false
	_teleport(session, blue, near)
	targets = session.get_action_targets(archer, "ranged_attack")
	if near not in targets:
		push_error("Enemy at distance 1 should still be ranged-targetable")
		return false
	return true

func _test_action_failures() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]

	var bad_target := session.apply({
		"type": "use_action",
		"action_id": "melee_attack",
		"from": green.tile_coords,
		"to": green.tile_coords,
		"rng_seed": 1,
	})
	if bad_target["ok"]:
		push_error("Melee self-target should fail")
		return false

	green.spend_all_ap()
	var no_ap := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": green.tile_coords,
		"to": session.get_movable_coords(green.tile_coords)[0] if not session.get_movable_coords(green.tile_coords).is_empty() else green.tile_coords,
	})
	if no_ap["ok"]:
		push_error("Move with 0 AP should fail")
		return false

	# Empty defender tile (after clearing blue).
	var empty := blue.tile_coords
	session.grid[empty].legion = null
	session.legions.erase(blue)
	green.refresh_ap()
	session.turn_manager.waited_coords.clear()
	# Place green adjacent if needed.
	var adj := Vector2i(0, 0)
	var enemy_spot := Vector2i(1, 0)
	if session.grid.get(adj) and session.grid.get(enemy_spot):
		_teleport(session, green, adj)
		var empty_atk := session.apply({
			"type": "use_action",
			"action_id": "melee_attack",
			"from": adj,
			"to": enemy_spot,
			"rng_seed": 1,
		})
		if empty_atk["ok"]:
			push_error("Melee into empty tile should fail")
			return false
	return true

func _test_wait_stain_survivor_and_end_turn() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	var blue: Legion = started["b"]
	var team_b: String = MinigameTestHelpersScript.team_b(session)

	var atk := Vector2i(0, 0)
	var def := Vector2i(1, 0)
	if session.grid.get(atk) == null or session.grid.get(def) == null:
		return true
	for c in [green.tile_coords, blue.tile_coords]:
		if session.grid.get(c):
			session.grid[c].legion = null
	_teleport(session, green, atk)
	_teleport(session, blue, def)
	for u in green.units:
		u.current_health = 100
		u.attack = 1
	for u in blue.units:
		u.current_health = 100
		u.attack = 1

	var melee := session.apply({
		"type": "use_action",
		"action_id": "melee_attack",
		"from": atk,
		"to": def,
		"rng_seed": 3,
	})
	if not melee["ok"]:
		push_error("Survivor melee failed: %s" % melee.get("error"))
		return false
	if atk not in session.turn_manager.waited_coords:
		push_error("Surviving attacker tile should remain waited")
		return false

	var end := session.apply({"type": "end_turn"})
	if not end["ok"]:
		push_error("end_turn failed")
		return false
	if not session.turn_manager.waited_coords.is_empty():
		push_error("end_turn should clear wait stains")
		return false
	if session.turn_manager.active_team_id != team_b:
		push_error("Expected team B after end_turn")
		return false
	return true

func _test_swap_onto_stained_empty_tile() -> bool:
	## Wait stain on the swap destination must not block the arriving legion.
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a: String = MinigameTestHelpersScript.team_a(session)
	var green_a: Legion = started["a"]
	var blue: Legion = started["b"]

	var a_coords := Vector2i(0, 0)
	var b_coords := Vector2i(1, 0)
	if session.grid.get(a_coords) == null or session.grid.get(b_coords) == null:
		return true
	for c in [green_a.tile_coords, blue.tile_coords]:
		if session.grid.get(c):
			session.grid[c].legion = null
	_teleport(session, green_a, a_coords)

	var green_b := Legion.new("GOBLIN", 2, b_coords, team_a)
	session.grid[b_coords].legion = green_b
	session.legions.append(green_b)
	# Stale wait on destination (e.g. wiped previous occupant).
	session.turn_manager.wait_legion(b_coords)

	var result := session.apply({
		"type": "use_action",
		"action_id": "move",
		"from": a_coords,
		"to": b_coords,
	})
	if not result["ok"]:
		push_error("Swap onto stained tile failed: %s" % result.get("error"))
		return false
	if "legions_swapped" not in result.get("events", []):
		push_error("Expected swap event")
		return false
	if b_coords in session.turn_manager.waited_coords:
		push_error("Swap should clear wait stain on destination")
		return false
	if a_coords in session.turn_manager.waited_coords:
		push_error("Swap should clear wait stain on source")
		return false
	if green_a.tile_coords != b_coords:
		push_error("Swap mover should land on destination")
		return false
	if not session.can_act_legion(green_a) and green_a.has_ap():
		push_error("Arriving legion should be able to act after swap cleared stain")
		return false
	return true

func _test_heal_ally_basic_and_terminal() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a: String = started["team_a"]
	var blue: Legion = started["b"]
	# Clear opposing legion off the board for a quiet ally-heal setup.
	if blue:
		session.grid[blue.tile_coords].legion = null
		session.legions.erase(blue)

	var mage_coords := Vector2i(0, 0)
	var ally_coords := Vector2i(2, 0)
	if session.grid.get(mage_coords) == null or session.grid.get(ally_coords) == null:
		return true
	for legion in session.legions.duplicate():
		if session.grid.get(legion.tile_coords):
			session.grid[legion.tile_coords].legion = null
		session.legions.erase(legion)

	var mage := Legion.new("MAGE", 1, mage_coords, team_a)
	var ally := Legion.new("GOBLIN", 2, ally_coords, team_a)
	session.grid[mage_coords].legion = mage
	session.grid[ally_coords].legion = ally
	session.legions.append(mage)
	session.legions.append(ally)
	mage.refresh_ap()
	for u in ally.units:
		u.current_health = max(1, u.max_health - 5)

	var before_hp := int(ally.units[0].current_health)
	var result := session.apply({
		"type": "use_action",
		"action_id": "heal_ally",
		"from": mage_coords,
		"to": ally_coords,
	})
	if not result["ok"]:
		push_error("heal_ally failed: %s" % result.get("error"))
		return false
	if "legion_healed" not in result.get("events", []):
		push_error("Expected legion_healed event")
		return false
	var after_hp := int(ally.units[0].current_health)
	if after_hp <= before_hp:
		push_error("Ally should gain HP")
		return false
	# Mage override heal_amount is 3.
	if after_hp - before_hp != 3:
		push_error("Expected Mage heal override of 3, got %d" % (after_hp - before_hp))
		return false
	if mage.current_ap != 0:
		push_error("heal_ally should be terminal")
		return false
	if mage_coords not in session.turn_manager.waited_coords:
		push_error("heal_ally should end caster turn")
		return false
	var entry: Dictionary = session.action_log.latest()
	if String(entry.get("action_id", "")) != "heal_ally":
		push_error("Action log should record heal_ally")
		return false
	return true

func _test_heal_ally_rejects_enemy_and_full_hp() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a: String = started["team_a"]
	var team_b: String = started["team_b"]
	for legion in session.legions.duplicate():
		if session.grid.get(legion.tile_coords):
			session.grid[legion.tile_coords].legion = null
		session.legions.erase(legion)

	var mage_coords := Vector2i(0, 0)
	var enemy_coords := Vector2i(1, 0)
	var full_ally_coords := Vector2i(0, 1)
	for c in [mage_coords, enemy_coords, full_ally_coords]:
		if session.grid.get(c) == null:
			return true

	var mage := Legion.new("MAGE", 1, mage_coords, team_a)
	var enemy := Legion.new("RAT_SPEAR", 1, enemy_coords, team_b)
	var full_ally := Legion.new("GOBLIN", 1, full_ally_coords, team_a)
	session.grid[mage_coords].legion = mage
	session.grid[enemy_coords].legion = enemy
	session.grid[full_ally_coords].legion = full_ally
	session.legions.append_array([mage, enemy, full_ally])
	mage.refresh_ap()

	var heal_def: ActionDefinition = ActionDefs.get_def("heal_ally")
	var targets := ActionTargetingScript.get_targets(session.battle_state(), mage, heal_def)
	if enemy_coords in targets:
		push_error("Enemy must not be a heal_ally target")
		return false
	if full_ally_coords in targets:
		push_error("Full-HP ally must not be a heal_ally target")
		return false

	var bad := session.apply({
		"type": "use_action",
		"action_id": "heal_ally",
		"from": mage_coords,
		"to": enemy_coords,
	})
	if bad["ok"]:
		push_error("heal_ally on enemy should fail")
		return false
	return true

func _test_heal_ally_param_override_range() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var team_a: String = started["team_a"]
	for legion in session.legions.duplicate():
		if session.grid.get(legion.tile_coords):
			session.grid[legion.tile_coords].legion = null
		session.legions.erase(legion)

	var mage_coords := Vector2i(0, 0)
	var near_ally := Vector2i(2, 0)
	var far_ally := Vector2i(3, 0)
	for c in [mage_coords, near_ally, far_ally]:
		if session.grid.get(c) == null:
			return true

	var mage := Legion.new("MAGE", 1, mage_coords, team_a)
	var ally_near := Legion.new("GOBLIN", 1, near_ally, team_a)
	var ally_far := Legion.new("GOBLIN", 1, far_ally, team_a)
	session.grid[mage_coords].legion = mage
	session.grid[near_ally].legion = ally_near
	session.grid[far_ally].legion = ally_far
	session.legions.append_array([mage, ally_near, ally_far])
	for u in ally_near.units + ally_far.units:
		u.current_health = max(1, u.max_health - 2)
	mage.refresh_ap()

	var heal_def: ActionDefinition = ActionDefs.get_def("heal_ally")
	# Mage default override range is 2 — far ally at dist 3 should be excluded.
	var targets := ActionTargetingScript.get_targets(session.battle_state(), mage, heal_def)
	if near_ally not in targets:
		push_error("Ally at range 2 should be healable")
		return false
	if far_ally in targets:
		push_error("Ally at range 3 should be out of Mage heal range")
		return false

	# Temporary override to range 3 on the shared unit def — restore after.
	var unit_def: UnitDefinition = UnitDefs.get_def("MAGE")
	var original: Dictionary = unit_def.action_params.duplicate(true)
	unit_def.action_params = {"heal_ally": {"heal_amount": 3, "target_range": 3}}
	targets = ActionTargetingScript.get_targets(session.battle_state(), mage, heal_def)
	unit_def.action_params = original
	if far_ally not in targets:
		push_error("Override range 3 should include far ally")
		return false
	return true
