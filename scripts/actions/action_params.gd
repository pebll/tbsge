class_name ActionParams
extends RefCounted

## Resolve a numeric/string param for an action: unit override ?? action default ?? fallback.
static func resolve(
	legion: Legion,
	action: ActionDefinition,
	key: String,
	fallback: Variant = null
) -> Variant:
	if action == null:
		return fallback
	var unit_override: Variant = _unit_override(legion, action.id, key)
	if unit_override != null:
		return unit_override
	var action_default: Variant = _action_default(action, key)
	if action_default != null:
		return action_default
	return fallback

static func resolve_int(
	legion: Legion,
	action: ActionDefinition,
	key: String,
	fallback: int = 0
) -> int:
	return int(resolve(legion, action, key, fallback))

## Legion-wide value: over the unit types present that can perform the action, the
## largest numeric override (range, cooldown, heal...), else the first non-numeric one.
static func _unit_override(legion: Legion, action_id: String, key: String) -> Variant:
	if legion == null or action_id.is_empty():
		return null
	var best: Variant = null
	for type_id in legion.unit_types():
		if action_id not in ActionDefs.unit_type_action_ids(type_id):
			continue
		var v: Variant = _type_override(type_id, action_id, key)
		if v == null:
			continue
		if best == null:
			best = v
		elif (v is int or v is float) and (best is int or best is float) and float(v) > float(best):
			best = v
	return best

static func _type_override(type_id: String, action_id: String, key: String) -> Variant:
	var unit_def: UnitDefinition = UnitDefs.get_def(type_id)
	if unit_def == null or not unit_def.action_params.has(action_id):
		return null
	var params: Variant = unit_def.action_params[action_id]
	if not (params is Dictionary):
		return null
	var dict: Dictionary = params
	return dict.get(key)

## A param as one unit type sees it: its override ?? action default ?? fallback.
static func resolve_for_type(
	type_id: String, action: ActionDefinition, key: String, fallback: Variant = null
) -> Variant:
	if action == null:
		return fallback
	var v: Variant = _type_override(type_id, action.id, key)
	if v != null:
		return v
	var d: Variant = _action_default(action, key)
	return d if d != null else fallback

## Heal each unit of the caster contributes, in `units` order: its own type's heal amount,
## or 0 if its type can't perform the heal (a mixed legion heals with its healers only).
static func unit_heal_amounts(legion: Legion, action: ActionDefinition) -> Array[int]:
	var out: Array[int] = []
	if legion == null or action == null:
		return out
	for unit in legion.units:
		if unit == null or action.id not in ActionDefs.unit_type_action_ids(unit.unit_type):
			out.append(0)
			continue
		out.append(int(resolve_for_type(unit.unit_type, action, "heal_amount", action.heal_amount)))
	return out

static func total_heal(legion: Legion, action: ActionDefinition) -> int:
	var t := 0
	for h in unit_heal_amounts(legion, action):
		t += h
	return t

static func _action_default(action: ActionDefinition, key: String) -> Variant:
	match key:
		"heal_amount", "heal":
			return action.heal_amount
		"target_range", "range":
			return action.target_range
		"ap_cost":
			return action.ap_cost
		"cooldown":
			return action.cooldown
		"status_stacks":
			return action.status_stacks
		"status_turns":
			return action.status_turns
		_:
			return null
