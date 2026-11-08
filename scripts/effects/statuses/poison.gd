extends "res://scripts/effects/status_behavior.gd"

## Poison: at the start of the poisoned legion's turn, every unit loses `stacks` HP
## (no shield). Stacks add up; re-applying refreshes the duration.

const StatusEffects = preload("res://scripts/effects/status_effects.gd")

func on_turn_start(owner: Legion, effect: Dictionary) -> Array:
	var out: Array = []
	for u in owner.units.duplicate():
		var ev: Dictionary = StatusEffects.damage_unit(owner, u, float(effect["stacks"]), String(effect["id"]))
		if not ev.is_empty():
			out.append(ev)
	return out

func projected_hp_change(owner: Legion, effect: Dictionary) -> float:
	# Ticks still to come (turns_left counts down at the end of each owner turn).
	var ticks := 2 if int(effect["turns_left"]) < 0 else mini(2, int(effect["turns_left"]))
	var total := 0.0
	for u in owner.units:
		total -= minf(float(u.current_health), float(effect["stacks"]) * ticks)
	return total
