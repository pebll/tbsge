extends RefCounted

const BattleInteractionScript = preload("res://scripts/ui/battle_interaction.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_overlay_states():
		return false
	if not _test_attack_ids_helper():
		return false
	print("Success: Battle interaction helper tests")
	return true

func _test_overlay_states() -> bool:
	if BattleInteractionScript.overlay_state_for_default_actions(["move"]) != "movable":
		push_error("move-only should paint movable")
		return false
	if BattleInteractionScript.overlay_state_for_default_actions(["melee_attack"]) != "attackable":
		push_error("melee-only should paint attackable")
		return false
	if BattleInteractionScript.overlay_state_for_default_actions(["ranged_attack"]) != "ranged_attackable":
		push_error("ranged-only should paint ranged_attackable")
		return false
	if BattleInteractionScript.overlay_state_for_default_actions(["melee_attack", "ranged_attack"]) != "attack_choice":
		push_error("melee+ranged should paint attack_choice")
		return false
	return true

func _test_attack_ids_helper() -> bool:
	var ids := BattleInteractionScript.attack_ids_from_actions(["move", "melee_attack", "ranged_attack"])
	if ids.size() != 2 or ids[0] != "melee_attack" or ids[1] != "ranged_attack":
		push_error("Expected melee+ranged attack ids, got %s" % ids)
		return false
	ids = BattleInteractionScript.attack_ids_from_actions(["move"])
	if not ids.is_empty():
		push_error("move-only should yield no attack ids")
		return false
	return true
