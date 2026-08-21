class_name AiCandidate
extends RefCounted

## One scored option for an activation. May be a multi-step plan; decide() emits step 0.

var action_id: String = ""
var from: Vector2i = Vector2i.ZERO
var to: Vector2i = Vector2i.ZERO
var path: Array[Vector2i] = []
## Optional follow-up after a move lands (same activation intent, next decide).
var followup_action_id: String = ""
var followup_to: Vector2i = Vector2i.ZERO
var reason: String = ""

func to_command() -> Dictionary:
	if action_id == "pass" or action_id.is_empty():
		return {
			"type": "pass",
			"coords": from,
			"reason": reason if not reason.is_empty() else "utility pass",
		}
	var cmd := {
		"type": "use_action",
		"action_id": action_id,
		"from": from,
		"to": to,
		"reason": reason,
	}
	if action_id == "move" and path.size() >= 2:
		cmd["path"] = path
	return cmd

func stand_coords() -> Vector2i:
	if action_id == "move" and path.size() >= 2:
		return path[path.size() - 1]
	if action_id == "teleport":
		return to
	return from
