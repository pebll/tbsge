extends RefCounted

## Base class for status effect behaviour. Override the hooks an effect needs; the rest
## are no-ops. `effect` is the instance dictionary on the legion:
##   {"id", "stacks", "turns_left", "source_team"}
## Hooks that change the board return event dictionaries (see StatusEffects.damage_unit /
## heal_unit for the shape) so playback, the battle log and tests see the same thing.
##
## Timing: effects belong to the legion that carries them ("owner").
##   on_turn_start: start of the owner's team turn, after AP and shields refill.
##   on_turn_end:   end of the owner's team turn, before its duration counts down.
## A duration of N means "for N of the owner's turns, counting the current one".

## Damage one of the owner's units deals with a strike (`mode` "melee" / "ranged").
func outgoing_damage(
	_owner: Legion, _effect: Dictionary, _unit: Unit, _target: Legion, _target_unit: Unit,
	_mode: String, damage: float
) -> float:
	return damage

## Damage one of the owner's units takes from a strike, before shields.
func incoming_damage(
	_owner: Legion, _effect: Dictionary, _unit: Unit, _attacker: Legion, _attacker_unit: Unit,
	_mode: String, damage: float
) -> float:
	return damage

## After a strike by one of the owner's units landed (`hit` = CombatResolver hit row).
func on_hit_dealt(_owner: Legion, _effect: Dictionary, _hit: Dictionary) -> Array:
	return []

## After one of the owner's units was struck.
func on_hit_taken(_owner: Legion, _effect: Dictionary, _hit: Dictionary) -> Array:
	return []

## After one of the owner's units died in combat.
func on_unit_death(_owner: Legion, _effect: Dictionary, _unit: Unit) -> Array:
	return []

func on_turn_start(_owner: Legion, _effect: Dictionary) -> Array:
	return []

func on_turn_end(_owner: Legion, _effect: Dictionary) -> Array:
	return []
