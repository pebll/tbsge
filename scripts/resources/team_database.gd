class_name TeamDatabase
extends Resource

@export var defs: Array[Resource] = []

var _by_id: Dictionary = {}

func _ready_cache() -> void:
	if not _by_id.is_empty():
		return
	for d in defs:
		if d and not String(d.id).is_empty():
			_by_id[d.id] = d

func get_def(id: String) -> Resource:
	_ready_cache()
	return _by_id.get(id)
