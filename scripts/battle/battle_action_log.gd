class_name BattleActionLog
extends RefCounted

signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 80

var entries: Array[Dictionary] = []

func clear() -> void:
	entries.clear()

func append(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)

func size() -> int:
	return entries.size()

func latest() -> Dictionary:
	if entries.is_empty():
		return {}
	return entries[entries.size() - 1]
