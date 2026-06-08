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
