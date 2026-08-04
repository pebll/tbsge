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

static func _unit_override(legion: Legion, action_id: String, key: String) -> Variant:
	if legion == null or action_id.is_empty():
		return null
	var unit_def: UnitDefinition = UnitDefs.get_def(legion.unit_type)
	if unit_def == null:
		return null
	if not unit_def.action_params.has(action_id):
		return null
	var params: Variant = unit_def.action_params[action_id]
	if not (params is Dictionary):
		return null
	var dict: Dictionary = params
	if not dict.has(key):
		return null
	return dict[key]

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
		_:
			return null
