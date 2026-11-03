class_name AiBrain
extends RefCounted

## Pluggable battle AI. Subclasses override decide / sort_actionable.
## EA and duel harness swap brains without touching MatchSession.

var id: String = "base"
var display_name: String = "Base"

func decide(session, legion: Legion) -> Dictionary:
	return {
		"type": "pass",
		"coords": legion.tile_coords if legion else Vector2i.ZERO,
		"reason": "base brain",
	}

func sort_actionable(session, actionable: Array[Vector2i]) -> Array[Vector2i]:
	return actionable.duplicate()
