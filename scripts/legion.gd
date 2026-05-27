class_name Legion
extends RefCounted

var unit_type: String
var units: Array[Unit] = []
var tile: HexTile

func _init(unit_type: String, unit_count: int, tile: HexTile) -> void:
	unit_type = unit_type
	tile = tile
	for i in range(unit_count):
		var unit = Unit.new(unit_type)
		units.append(unit)
