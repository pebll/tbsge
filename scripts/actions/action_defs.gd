extends Node

const ActionDb = preload("res://scripts/actions/action_database.gd")
const ActionDef = preload("res://scripts/actions/action_definition.gd")

const DB_PATH := "res://data/action_db.tres"

const DEFAULT_ACTION_IDS: Array[String] = ["move", "melee_attack", "self_heal"]

var _db: ActionDb

func _ready() -> void:
	_db = load(DB_PATH)
	if _db == null:
		push_error("ActionDefs failed to load DB at %s" % DB_PATH)

func get_def(id: String) -> ActionDef:
	if _db == null:
		_db = load(DB_PATH)
	return _db.get_def(id) if _db else null

func default_action_ids() -> Array[String]:
	return DEFAULT_ACTION_IDS.duplicate()

func legion_action_ids(legion: Legion) -> Array[String]:
	if legion == null:
		return []
	var unit_def: UnitDefinition = UnitDefs.get_def(legion.unit_type)
	if unit_def and not unit_def.action_ids.is_empty():
		return unit_def.action_ids.duplicate()
	return default_action_ids()
