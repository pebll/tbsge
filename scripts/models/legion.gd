class_name Legion
extends RefCounted

var unit_type: String
var team_id: String
var units: Array[Unit] = []
var tile_coords: Vector2i
var unit_count: int

func _init(unit_type: String, unit_count: int, tile_coords: Vector2i, team_id: String) -> void:
	self.unit_type = unit_type
	self.unit_count = unit_count
	self.tile_coords = tile_coords
	self.team_id = team_id
	for i in range(unit_count):
		var unit = Unit.new(self.unit_type)
		units.append(unit)
