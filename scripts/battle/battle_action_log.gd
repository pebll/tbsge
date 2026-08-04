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

## Visibility always follows GameSettings so UI never desyncs from Options.
func is_entry_visible(entry: Dictionary) -> bool:
	var action_id := String(entry.get("action_id", ""))
	if action_id in ["move", "swap"]:
		return GameSettings.show_battle_log_moves
	if action_id == "end_turn":
		return GameSettings.show_battle_log_end_turns
	return true

## Entries that reveal outcome before VFX finishes should wait for playback.
static func should_defer_ui(entry: Dictionary) -> bool:
	var action_id := String(entry.get("action_id", ""))
	return action_id in [
		"melee_attack",
		"ranged_attack",
		"self_heal",
		"heal_ally",
		"teleport",
	]

func size() -> int:
	return entries.size()

func latest() -> Dictionary:
	if entries.is_empty():
		return {}
	return entries[entries.size() - 1]
