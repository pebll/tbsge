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
	var green := MinigameRules.deploy_zone_coords(3, "GREEN", 0, teams)
	var blue := MinigameRules.deploy_zone_coords(3, "BLUE", 0, teams)
	if green.is_empty() or blue.is_empty():
		push_error("Expected deploy zones for both teams")
		return false

	var green_rs: Dictionary = {}
	for c in green:
		green_rs[c.y] = true
		if c.y > -2:
			push_error("GREEN deploy slot outside southern 2 rows: %s" % c)
			return false
	if green_rs.size() != 2:
		push_error("GREEN should span exactly 2 r rows, got %d" % green_rs.size())
		return false

	var blue_rs: Dictionary = {}
	for c in blue:
		blue_rs[c.y] = true
		if c.y < 2:
			push_error("BLUE deploy slot outside northern 2 rows: %s" % c)
			return false
	if blue_rs.size() != 2:
		push_error("BLUE should span exactly 2 r rows, got %d" % blue_rs.size())
		return false

	# Full width: all coords in those rows on the map should be included.
	var expected_green := 0
	for q in range(-3, 4):
		for r in [-3, -2]:
			var s: int = -r - q
			if abs(s) <= 3:
				expected_green += 1
	if green.size() != expected_green:
		push_error("GREEN zone should include full width (%d), got %d" % [expected_green, green.size()])
		return false
	return true
