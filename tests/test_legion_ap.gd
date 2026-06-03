extends RefCounted

func run(_tree: SceneTree) -> bool:
	if not _test_move_cost():
		return false
	if not _test_attack_spends_attacker_only():
		return false
	if not _test_swap_costs_both():
		return false
	if not _test_refresh_ap():
		return false
	print("Success: Legion AP tests")
	return true

func _test_move_cost() -> bool:
	var legion := Legion.new("ARCHER", 2, Vector2i.ZERO, "GREEN")
	if not legion.spend_ap(1):
		push_error("spend_ap(1) should succeed")
		return false
	if legion.current_ap != 1:
		push_error("Expected 1 AP after move")
		return false
	return true

func _test_attack_spends_attacker_only() -> bool:
	var attacker := Legion.new("ARCHER", 2, Vector2i.ZERO, "GREEN")
	var defender := Legion.new("OGRE", 2, Vector2i.ONE, "BLUE")
	attacker.current_ap = 2
	defender.current_ap = 2
	attacker.spend_all_ap()
	if attacker.current_ap != 0:
		push_error("Attacker should have 0 AP")
		return false
	if defender.current_ap != 2:
		push_error("Defender AP should be unchanged")
		return false
	return true

func _test_swap_costs_both() -> bool:
	var a := Legion.new("ARCHER", 2, Vector2i.ZERO, "GREEN")
	var b := Legion.new("ARCHER", 2, Vector2i.ONE, "GREEN")
	a.spend_ap(1)
	b.spend_ap(1)
	if a.current_ap != 1 or b.current_ap != 1:
		push_error("Swap should cost 1 AP on each legion")
		return false
	return true

func _test_refresh_ap() -> bool:
	var legion := Legion.new("ARCHER", 2, Vector2i.ZERO, "GREEN")
	legion.spend_all_ap()
	legion.refresh_ap()
	if legion.current_ap != legion.max_ap:
		push_error("refresh_ap should restore max AP")
		return false
	return true
