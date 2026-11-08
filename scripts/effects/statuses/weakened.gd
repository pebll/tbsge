extends "res://scripts/effects/status_behavior.gd"

## Weakened: every strike the legion makes deals -stacks damage (not below 0).

func outgoing_damage(_o: Legion, effect: Dictionary, _u: Unit, _t: Legion, _tu: Unit, _m: String, damage: float) -> float:
	return maxf(0.0, damage - float(effect["stacks"]))
