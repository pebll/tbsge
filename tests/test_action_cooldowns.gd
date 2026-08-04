extends RefCounted

const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")
const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_cooldown_blocks_and_ticks():
		return false
	if not _test_action_use_starts_cooldown_from_def():
		return false
	print("Success: Action cooldown tests")
	return true

func _test_cooldown_blocks_and_ticks() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	for u in green.units:
		u.current_health = max(1, u.max_health - 3)

	var heal_def: ActionDefinition = ActionDefs.get_def("self_heal")
	if not ActionTargetingScript.can_use(session.battle_state(), green, heal_def):
		push_error("Heal should be usable before cooldown")
		return false

	green.start_cooldown("self_heal", 2)
	if ActionTargetingScript.can_use(session.battle_state(), green, heal_def):
		push_error("Heal should be blocked while on cooldown")
		return false
	var reason := ActionTargetingScript.disable_reason(session.battle_state(), green, heal_def)
	if "Ready in 2" not in reason:
		push_error("Expected Ready in 2 reason, got: %s" % reason)
		return false

	# First refresh skips the tick so cooldown 2 still means two blocked turns.
	green.refresh_ap()
	if green.get_cooldown_remaining("self_heal") != 2:
		push_error("First refresh after start should keep cooldown 2, got %d" % green.get_cooldown_remaining("self_heal"))
		return false
	green.refresh_ap()
	if green.get_cooldown_remaining("self_heal") != 1:
		push_error("Second refresh should tick cooldown to 1")
		return false
	green.refresh_ap()
	if green.get_cooldown_remaining("self_heal") != 0:
		push_error("Cooldown should clear after third refresh")
		return false
	if not ActionTargetingScript.can_use(session.battle_state(), green, heal_def):
		push_error("Heal should be usable after cooldown clears")
		return false
	return true

func _test_action_use_starts_cooldown_from_def() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	var started: Dictionary = MinigameTestHelpersScript.start_two_legion_battle(session)
	var green: Legion = started["a"]
	for u in green.units:
		u.current_health = max(1, u.max_health - 3)

	var heal_def: ActionDefinition = ActionDefs.get_def("self_heal")
	var original_cd := heal_def.cooldown
	heal_def.cooldown = 2
	var result := session.apply({
		"type": "use_action",
		"action_id": "self_heal",
		"from": green.tile_coords,
		"to": green.tile_coords,
	})
	heal_def.cooldown = original_cd
	if not result["ok"]:
		push_error("Self heal failed while testing cooldown start: %s" % result.get("error"))
		return false
	if green.get_cooldown_remaining("self_heal") != 2:
		push_error("Expected cooldown 2 after use, got %d" % green.get_cooldown_remaining("self_heal"))
		return false

	# Team turn refresh ticks cooldowns for the newly active team only —
	# force a refresh on green to simulate its next turn start.
	green.refresh_ap()
	if green.get_cooldown_remaining("self_heal") != 2:
		push_error("First refresh after cast should still show cooldown 2 (skip tick)")
		return false
	green.refresh_ap()
	if green.get_cooldown_remaining("self_heal") != 1:
		push_error("Second refresh should tick cooldown to 1")
		return false
	return true
