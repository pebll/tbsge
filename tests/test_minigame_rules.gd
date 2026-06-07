extends RefCounted

const MinigameRules = preload("res://scripts/minigame/minigame_rules.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_pricing_and_sizes():
		return false
	if not _test_deploy_zones():
		return false
	print("Success: Minigame rules tests")
	return true

func _test_pricing_and_sizes() -> bool:
	if MinigameRules.unit_price("ARCHER") != 3:
		push_error("ARCHER price expected 3")
		return false
	if MinigameRules.unit_price("OGRE") != 10:
		push_error("OGRE price expected 10")
		return false
	if MinigameRules.max_units_in_legion("ARCHER") != 8:
		push_error("ARCHER max units expected 8")
		return false
	if MinigameRules.max_units_in_legion("DRAGON_RIDER") != 4:
		push_error("DRAGON_RIDER max units expected 4")
		return false
	if MinigameRules.legion_cost("ARCHER", 4) != 12:
		push_error("4 archers should cost 12 gold")
		return false
	return true

func _test_deploy_zones() -> bool:
	var teams: Array[String] = ["GREEN", "BLUE"]
	var green := MinigameRules.deploy_zone_coords(3, "GREEN", 7, teams)
	var blue := MinigameRules.deploy_zone_coords(3, "BLUE", 7, teams)
	if green.size() != 7 or blue.size() != 7:
		push_error("Expected 7 deploy slots per team")
		return false
	for c in green:
		if c.y > -1:
			push_error("GREEN deploy slot not in south band: %s" % c)
			return false
	for c in blue:
		if c.y < 1:
			push_error("BLUE deploy slot not in north band: %s" % c)
			return false
	return true
