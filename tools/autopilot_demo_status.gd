extends "res://scripts/effects/status_behavior.gd"

## Autopilot `status_demo` only: burns `stacks` HP off a random unit at the owner's
## turn start, so badges, tick playback and log cards can be checked on screen.

const StatusEffects = preload("res://scripts/effects/status_effects.gd")

func on_turn_start(owner: Legion, effect: Dictionary) -> Array:
	if owner.units.is_empty():
		return []
	var u: Unit = owner.units[owner.units.size() - 1]
	return [StatusEffects.damage_unit(owner, u, float(effect["stacks"]) * 3.0, String(effect["id"]))]
