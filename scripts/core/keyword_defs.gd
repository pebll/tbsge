extends Node

const PATH := "res://data/keyword_glossary.tres"

var _glossary: Resource

func _ready() -> void:
	_ensure_loaded()

func _ensure_loaded() -> void:
	if _glossary != null:
		return
	_glossary = load(PATH)
	if _glossary == null:
		push_error("KeywordDefs failed to load glossary at %s" % PATH)

func glossary() -> Resource:
	_ensure_loaded()
	return _glossary

func has_keyword(id: String) -> bool:
	var g := glossary()
	return g != null and g.has_method("has_keyword") and g.has_keyword(id)

func get_label(id: String) -> String:
	var g := glossary()
	if g != null and g.has_method("get_label"):
		return String(g.get_label(id))
	return id.capitalize()

func get_definition(id: String) -> String:
	var g := glossary()
	if g != null and g.has_method("get_definition"):
		return String(g.get_definition(id))
	return ""
