class_name Unit
extends RefCounted

var unit_type: String
var max_health: float
var attack: float
var current_health: float
var definition: UnitDefinition

func _init(unit_type: String) -> void:
	self.unit_type = unit_type
	definition = UnitDefs.get_def(unit_type)
	if definition:
		max_health = definition.max_health
		attack = definition.attack
	else:
		# Safe defaults if unit type not found in DB.
		max_health = 10
		attack = 3
	current_health = max_health
	
