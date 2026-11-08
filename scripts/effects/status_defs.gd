extends RefCounted

## Registry of status effect types: every data/status/*.tres, plus definitions registered
## at runtime (tests). Behaviour scripts are instantiated once per type.

const DIR := "res://data/status"
const StatusBehaviorScript = preload("res://scripts/effects/status_behavior.gd")

static var _defs: Dictionary = {}       # id -> StatusDefinition
static var _behaviors: Dictionary = {}  # id -> behaviour instance
static var _loaded: bool = false

static func get_def(id: String) -> Resource:
	_ensure_loaded()
	return _defs.get(id)

static func has(id: String) -> bool:
	_ensure_loaded()
	return _defs.has(id)

static func all_ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for k in _defs.keys():
		out.append(String(k))
	out.sort()
	return out

static func behavior(id: String):
	_ensure_loaded()
	if _behaviors.has(id):
		return _behaviors[id]
	var def = _defs.get(id)
	var b = null
	if def != null and def.behavior != null:
		b = def.behavior.new()
	if b == null:
		b = StatusBehaviorScript.new()
	_behaviors[id] = b
	return b

## Add or replace a definition (tests, mods). Replaces its cached behaviour too.
static func register(def: Resource) -> void:
	_ensure_loaded()
	_defs[def.id] = def
	_behaviors.erase(def.id)

static func unregister(id: String) -> void:
	_defs.erase(id)
	_behaviors.erase(id)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f in DirAccess.get_files_at(DIR):
		var name := String(f).trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def = load(DIR + "/" + name)
		if def != null and not String(def.id).is_empty():
			_defs[def.id] = def
