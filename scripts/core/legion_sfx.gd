class_name LegionSfx
extends RefCounted

const LegionSfxActionScript = preload("res://scripts/core/legion_sfx_action.gd")
const LegionSfxDefaultsScript = preload("res://scripts/core/legion_sfx_defaults.gd")

## Resolves the stream for a legion action: unit override first, then global default.
## HIT with no override returns null so AudioManager can pick a random default hit.
static func stream_for(unit_type: String, action: LegionSfxAction.Kind) -> AudioStream:
	var custom := _custom_stream(unit_type, action)
	if custom:
		return custom
	return LegionSfxDefaultsScript.stream(action)

static func uses_random_default_hit(unit_type: String) -> bool:
	return _custom_stream(unit_type, LegionSfxAction.Kind.HIT) == null

static func _custom_stream(unit_type: String, action: LegionSfxAction.Kind) -> AudioStream:
	var property := _property_for(action)
	if property.is_empty():
		return null
	var def := UnitDefs.get_def(unit_type)
	if def == null:
		return null
	var stream: Variant = def.get(property)
	return stream if stream is AudioStream else null

static func _property_for(action: LegionSfxAction.Kind) -> String:
	match action:
		LegionSfxAction.Kind.SELECT:
			return "sfx_select"
		LegionSfxAction.Kind.MOVE:
			return "sfx_move"
		LegionSfxAction.Kind.HIT:
			return "sfx_hit"
		LegionSfxAction.Kind.DEATH:
			return "sfx_death"
	return ""
