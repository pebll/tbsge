class_name UnitDatabase
extends Resource

@export var defs: Array[UnitDefinition] = []

var _by_id: Dictionary = {}

func _ready_cache() -> void:
	if not _by_id.is_empty():
		return
	for d in defs:
		if d and not String(d.id).is_empty():
			_by_id[d.id] = d

func get_def(id: String) -> UnitDefinition:
	_ready_cache()
	return _by_id.get(id)

func get_all_defs() -> Array[UnitDefinition]:
	_ready_cache()
	var out: Array[UnitDefinition] = []
	for d in defs:
		if d:
			out.append(d)
	return out

func get_all_ids() -> Array[String]:
	var out: Array[String] = []
	for d in get_all_defs():
		if not String(d.id).is_empty():
			out.append(d.id)
	return out
