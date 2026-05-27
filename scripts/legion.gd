class_name Legion
extends RefCounted

var unit_type: String
var units: Array[Unit] = []
var tile: HexTile
var unit_count: int

func _init(unit_type: String, unit_count: int, tile: HexTile) -> void:
	self.unit_type = unit_type
	self.unit_count = unit_count
	self.tile = tile
	for i in range(unit_count):
		var unit = Unit.new(self.unit_type)
		units.append(unit)
