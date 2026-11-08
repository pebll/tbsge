extends "res://scripts/effects/status_behavior.gd"

## Empowered: every strike the legion makes deals +stacks damage.

func outgoing_damage(_o: Legion, effect: Dictionary, _u: Unit, _t: Legion, _tu: Unit, _m: String, damage: float) -> float:
	return damage + float(effect["stacks"])
