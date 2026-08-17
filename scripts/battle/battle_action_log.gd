class_name BattleActionLog
extends RefCounted

signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 80

var entries: Array[Dictionary] = []
var _seq: int = 0

func clear() -> void:
	entries.clear()
	_seq = 0

func append(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	_seq += 1
	entry["log_seq"] = _seq
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)

## Visibility always follows GameSettings so UI never desyncs from Options.
## Teleport stays visible; only walk/swap relocations follow "Show moves".
func is_entry_visible(entry: Dictionary) -> bool:
	var action_id := String(entry.get("action_id", ""))
	var result_summary := String(entry.get("result_summary", ""))
	# Wait/pass is never shown (and no longer appended).
	if action_id == "pass" or result_summary == "waited":
		return false
	if (
		action_id in ["move", "swap"]
		or result_summary in ["moved", "swapped"]
	):
		return GameSettings.show_battle_log_moves
	if action_id == "end_turn" or action_id == "turn_start":
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
