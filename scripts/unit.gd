class_name Unit
extends RefCounted

var unit_type: String
var max_health : float
var attack : float
var current_health : float

func _init(unit_type: String) -> void:
	self.unit_type = unit_type
	max_health = 10
	attack = 3
	current_health = max_health
	
