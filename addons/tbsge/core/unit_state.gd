class_name TbsUnitState
extends RefCounted


var id: int = -1
var unit_def_id: String = ""
var coords: Vector2i
var team_id: int = 0
var hp: int = 1
var max_hp: int = 1
var action_points: int = 1


func _init(p_id: int, p_unit_def_id: String, p_coords: Vector2i, p_team_id: int) -> void:
	id = p_id
	unit_def_id = p_unit_def_id
	coords = p_coords
	team_id = p_team_id

