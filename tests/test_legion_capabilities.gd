extends RefCounted

## Legion capabilities aggregate over all units (not units[0]) — groundwork for mixed legions.

func run(_tree: SceneTree) -> bool:
	if not _test_unit_count_tracks_units():
		return false
	if not _test_ranged_capability_not_first_unit():
		return false
	if not _test_action_ids_union_over_unit_types():
		return false
	print("Success: Legion capability tests")
	return true

func _ranged_type() -> String:
	for id in ["ARCHER", "RAT_ARCHER", "MAGE"]:
		var def: UnitDefinition = UnitDefs.get_def(id)
		if def and def.has_ranged():
			return id
	return ""

func _test_unit_count_tracks_units() -> bool:
	var legion := Legion.new("GOBLIN", 3, Vector2i.ZERO, "GREEN")
	if legion.unit_count != 3:
		push_error("unit_count should start at 3")
		return false
	legion.units.pop_back()
	if legion.unit_count != 2:
		push_error("unit_count must follow units.size()")
		return false
	return true

func _test_ranged_capability_not_first_unit() -> bool:
	var ranged_id := _ranged_type()
	if ranged_id.is_empty():
		push_error("No ranged unit type in the DB")
		return false
	var legion := Legion.new("GOBLIN", 2, Vector2i.ZERO, "GREEN")
	if legion.has_ranged():
		push_error("Goblin-only legion should not have ranged")
		return false
	var archer := Unit.new(ranged_id)
	legion.units.append(archer)
	if not legion.has_ranged():
		push_error("A ranged unit anywhere in the legion grants ranged")
		return false
	if legion.max_attack_range() != archer.attack_range:
		push_error("max_attack_range should come from the ranged unit")
		return false
	if not ActionTargeting._legion_has_ranged(legion):
		push_error("Targeting must use the aggregated capability")
		return false
	return true

func _test_action_ids_union_over_unit_types() -> bool:
	var ranged_id := _ranged_type()
	var legion := Legion.new("GOBLIN", 1, Vector2i.ZERO, "GREEN")
	legion.units.append(Unit.new(ranged_id))
	var ids := ActionDefs.legion_action_ids(legion)
	var ranged_def: UnitDefinition = UnitDefs.get_def(ranged_id)
	var expected: Array[String] = []
	for type_id in ["GOBLIN", ranged_id]:
		var def: UnitDefinition = UnitDefs.get_def(type_id)
		for id in def.action_ids:
			if id not in expected:
				expected.append(id)
	if ranged_def.action_ids.is_empty():
		return true
	for id in expected:
		if id not in ids:
			push_error("legion_action_ids missing %s from a member unit type" % id)
			return false
	return true
