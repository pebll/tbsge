class_name AiBrainRegistry
extends RefCounted

## String id → AiBrain instance. Keep ids stable for CLI / EA configs.

const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")
const AiProfileScript = preload("res://scripts/ai/utility/ai_profile.gd")

const KNOWN_IDS: Array[String] = ["cascade", "utility"]

static func create(brain_id: String) -> AiBrain:
	var key := brain_id.strip_edges().to_lower()
	if key.is_empty():
		key = "cascade"
	match key:
		"cascade":
			return CascadeBrainScript.new()
		"utility":
			return UtilityBrainScript.new(AiProfileScript.hand_v1())
		_:
			push_error("Unknown AI brain id '%s'; falling back to cascade" % brain_id)
			return CascadeBrainScript.new()

static func is_known(brain_id: String) -> bool:
	return brain_id.strip_edges().to_lower() in KNOWN_IDS
