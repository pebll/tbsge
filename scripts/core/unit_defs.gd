extends Node

const DB_PATH := "res://data/unit_db.tres"
var _db: UnitDatabase

func _ready() -> void:
	_db = load(DB_PATH)
	if _db == null:
		push_error("UnitDefs failed to load DB at %s" % DB_PATH)

func get_def(id: String) -> UnitDefinition:
	if _db == null:
		_db = load(DB_PATH)
	return _db.get_def(id) if _db else null

