extends RefCounted

## Counter tags: every unit is tagged from the fixed list, every tag has a glossary entry,
## and tags that follow directly from stats/actions agree with them.

const UnitTags = preload("res://scripts/core/unit_tags.gd")

func run(_tree: SceneTree) -> bool:
	var ok := true
	for t in UnitTags.ALL:
		if not KeywordDefs.has_keyword(UnitTags.keyword_id(t)):
			push_error("Glossary has no entry for tag '%s'" % t)
			ok = false
	for path in DirAccess.get_files_at("res://data/units"):
		if not String(path).ends_with(".tres"):
			continue
		var def: UnitDefinition = load("res://data/units/" + path)
		if def == null:
			continue
		ok = _check_unit(def) and ok
	if not _test_legion_union():
		ok = false
	if ok:
		print("Success: unit tag tests")
	return ok

func _check_unit(def: UnitDefinition) -> bool:
	var tags: Array = def.tags
	if tags.is_empty():
		push_error("%s has no counter tags" % def.id)
		return false
	for t in tags:
		if not UnitTags.is_known(String(t)):
			push_error("%s has unknown tag '%s'" % [def.id, t])
			return false
	var ids: Array = ActionDefs.unit_type_action_ids(def.id)
	var derived := {
		UnitTags.RANGED: def.has_ranged(),
		UnitTags.SUPPORT: "heal_ally" in ids or "rally" in ids or "curse" in ids,
		UnitTags.SHIELDED: def.shield > 0,
		UnitTags.MOBILE: def.ap >= 3 or "teleport" in ids,
	}
	# armored / swarm / striker are design judgment (guidelines in unit_tags.gd), not checked.
	for t in derived.keys():
		if bool(derived[t]) != (t in tags):
			push_error("%s: tag '%s' should be %s by its stats (tags %s)" % [def.id, t, derived[t], tags])
			return false
	return true

func _test_legion_union() -> bool:
	var L := Legion.from_composition([["MAGE", 1], ["GOLEM", 1]], Vector2i.ZERO, "GREEN")
	var tags := UnitTags.for_legion(L)
	if tags != [UnitTags.RANGED, UnitTags.SUPPORT, UnitTags.SHIELDED, UnitTags.ARMORED]:
		push_error("Mixed legion tags should be the union in list order: %s" % [tags])
		return false
	if UnitTags.labels_line(tags).find("Support") < 0:
		push_error("Labels line should read from the glossary: %s" % UnitTags.labels_line(tags))
		return false
	return true
