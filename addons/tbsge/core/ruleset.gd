class_name TbsRuleset
extends Resource


func get_movable_tiles(board: TbsBoardState, unit: TbsUnitState) -> Array[Vector2i]:
	return []


func get_attackable_tiles(board: TbsBoardState, unit: TbsUnitState) -> Array[Vector2i]:
	return []


func resolve_attack(board: TbsBoardState, attacker: TbsUnitState, target: TbsUnitState) -> void:
	pass


func can_end_turn(board: TbsBoardState, current_team_id: int) -> bool:
	return true

