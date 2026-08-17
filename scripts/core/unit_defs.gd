extends Node

const DB_PATH := "res://data/unit_db.tres"
var _db: UnitDatabase

func _ready() -> void:
	_db = load(DB_PATH)
	if _db == null:
		push_error("UnitDefs failed to load DB at %s" % DB_PATH)
		return
	for def in _db.get_all_defs():
		if def and not def.has_allowed_size():
			push_error("Unit '%s' has disallowed size %s" % [def.id, def.size])

func get_def(id: String) -> UnitDefinition:
	if _db == null:
		_db = load(DB_PATH)
	return _db.get_def(id) if _db else null

func get_all_defs() -> Array[UnitDefinition]:
	if _db == null:
		_db = load(DB_PATH)
	return _db.get_all_defs() if _db else []

func get_all_ids() -> Array[String]:
	if _db == null:
		_db = load(DB_PATH)
	return _db.get_all_ids() if _db else []
