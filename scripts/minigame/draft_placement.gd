class_name DraftPlacement
extends RefCounted

var coords: Vector2i
var unit_type: String
var unit_count: int

func _init(p_coords: Vector2i, p_unit_type: String, p_unit_count: int) -> void:
	coords = p_coords
	unit_type = p_unit_type
	unit_count = p_unit_count
