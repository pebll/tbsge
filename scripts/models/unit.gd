class_name Unit
extends RefCounted

var unit_type: String
var max_health: float
var attack: float
var current_health: float
var shield_max: int = 0
var shield_remaining: int = 0
var definition: UnitDefinition

func _init(unit_type: String) -> void:
	self.unit_type = unit_type
	definition = UnitDefs.get_def(unit_type)
	if definition:
		max_health = definition.max_health
		attack = definition.attack
		shield_max = maxi(0, definition.shield)
	else:
		# Safe defaults if unit type not found in DB.
		max_health = 10
		attack = 3
		shield_max = 0
	current_health = max_health
	reset_turn_state()

func reset_turn_state() -> void:
	shield_remaining = shield_max

func absorb_damage(raw_damage: float) -> Dictionary:
	var raw := maxf(0.0, raw_damage)
	if shield_remaining <= 0:
		return {"applied": raw, "absorbed": 0.0}
	var absorbed := minf(raw, float(shield_remaining))
	shield_remaining = 0
	return {"applied": raw - absorbed, "absorbed": absorbed}
	
