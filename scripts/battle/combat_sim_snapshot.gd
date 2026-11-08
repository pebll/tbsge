class_name CombatSimSnapshot
extends RefCounted

## Deep-enough copies of legions for combat Monte Carlo (does not touch live battle state).

static func clone_unit(unit: Unit) -> Unit:
	if unit == null:
		return null
	var copy := Unit.new(unit.unit_type)
	copy.current_health = unit.current_health
	copy.shield_remaining = unit.shield_remaining
	return copy

static func clone_legion(legion: Legion) -> Legion:
	if legion == null:
		return null
	# Units are copied one by one (each keeps its own type), so mixed legions clone exactly.
	var copy := Legion.new(legion.unit_type, 0, legion.tile_coords, legion.team_id)
	copy.units.clear()
	for unit in legion.units:
		if unit:
			copy.units.append(clone_unit(unit))
	copy.max_ap = legion.max_ap
	copy.current_ap = legion.current_ap
	return copy
