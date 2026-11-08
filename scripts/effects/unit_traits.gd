extends RefCounted

## Passive unit abilities (UnitDefinition.traits). Unlike status effects they belong to a
## unit type, never expire, and act per unit, so mixed legions work naturally. Called from
## the same hook points as statuses (see StatusEffects).
##
##   regeneration (int)   each unit heals this much at the start of its own turn
##   lifesteal (float)    each unit heals this fraction of the HP its strike took
##   pierce (bool)        strikes ignore and break the target's shield
##   poison_on_hit ({"stacks", "turns"})  each landed strike adds poison to the target

const REGENERATION := "regeneration"
const LIFESTEAL := "lifesteal"
const PIERCE := "pierce"
const POISON_ON_HIT := "poison_on_hit"
const ALL: Array[String] = [REGENERATION, LIFESTEAL, PIERCE, POISON_ON_HIT]

static func of(unit: Unit) -> Dictionary:
	if unit == null or unit.definition == null:
		return {}
	return unit.definition.traits

static func value(unit: Unit, key: String, fallback = null):
	return of(unit).get(key, fallback)

static func has_trait(unit: Unit, key: String) -> bool:
	return of(unit).has(key)

static func legion_has_any(legion: Legion) -> bool:
	if legion == null:
		return false
	for u in legion.units:
		if u != null and not of(u).is_empty():
			return true
	return false

## Trait ids present in the legion, in ALL order.
static func for_legion(legion: Legion) -> Array[String]:
	var present := {}
	if legion != null:
		for u in legion.units:
			for k in of(u).keys():
				present[String(k)] = true
	var out: Array[String] = []
	for k in ALL:
		if present.has(k):
			out.append(k)
	return out

static func for_type(type_id: String) -> Array[String]:
	var def: UnitDefinition = UnitDefs.get_def(type_id)
	var out: Array[String] = []
	if def != null:
		for k in ALL:
			if def.traits.has(k):
				out.append(k)
	return out

static func keyword_id(trait_id: String) -> String:
	return "trait_" + trait_id

static func label(trait_id: String) -> String:
	return KeywordDefs.get_label(keyword_id(trait_id))
