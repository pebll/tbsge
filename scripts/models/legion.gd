class_name Legion
extends RefCounted

const DEFAULT_MAX_AP := 2

var unit_type: String
var team_id: String
var units: Array[Unit] = []
var tile_coords: Vector2i
var unit_count: int
var max_ap: int = DEFAULT_MAX_AP
var current_ap: int = DEFAULT_MAX_AP

func _init(unit_type: String, unit_count: int, tile_coords: Vector2i, team_id: String) -> void:
	self.unit_type = unit_type
	self.unit_count = unit_count
	self.tile_coords = tile_coords
	self.team_id = team_id
	_apply_unit_type_defaults()
	for i in range(unit_count):
		var unit = Unit.new(self.unit_type)
		units.append(unit)

func _apply_unit_type_defaults() -> void:
	var def := UnitDefs.get_def(unit_type)
	if def and def.ap > 0:
		max_ap = def.ap
	else:
		max_ap = DEFAULT_MAX_AP
	current_ap = max_ap

func has_ap() -> bool:
	return current_ap > 0

func can_afford(cost: int) -> bool:
	return current_ap >= cost

func spend_ap(cost: int) -> bool:
	if not can_afford(cost):
		return false
	current_ap -= cost
	return true

func spend_all_ap() -> void:
	current_ap = 0

func refresh_ap() -> void:
	current_ap = max_ap
	for unit in units:
		unit.reset_turn_state()
