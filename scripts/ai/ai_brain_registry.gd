class_name AiBrainRegistry
extends RefCounted

## String id → AiBrain instance. Keep ids stable for CLI / EA configs.

const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")

const KNOWN_IDS: Array[String] = ["cascade"]

static func create(brain_id: String) -> AiBrain:
	var key := brain_id.strip_edges().to_lower()
	if key.is_empty():
		key = "cascade"
	match key:
		"cascade":
			return CascadeBrainScript.new()
		_:
			push_error("Unknown AI brain id '%s'; falling back to cascade" % brain_id)
			return CascadeBrainScript.new()

static func is_known(brain_id: String) -> bool:
	return brain_id.strip_edges().to_lower() in KNOWN_IDS
