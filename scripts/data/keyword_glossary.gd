class_name KeywordGlossary
extends Resource

## id -> { "label": String, "definition": String }
@export var entries: Dictionary = {}

func has_keyword(id: String) -> bool:
	return entries.has(id)

func get_label(id: String) -> String:
	var entry: Variant = entries.get(id, null)
	if entry is Dictionary:
		return String(entry.get("label", id.capitalize()))
	return id.capitalize()

func get_definition(id: String) -> String:
	var entry: Variant = entries.get(id, null)
	if entry is Dictionary:
		return String(entry.get("definition", ""))
	return ""
