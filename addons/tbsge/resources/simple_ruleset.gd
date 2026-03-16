class_name TbsSimpleRuleset
extends TbsRuleset


@export var board_config: TbsBoardConfig


func _get_move_range(unit: TbsUnitState) -> int:
	if not board_config:
		return 1
	var def := board_config.get_unit_def(unit.unit_def_id)
	if def:
		return max(def.move_range, 0)
	return 1


func _get_attack_range(unit: TbsUnitState) -> int:
	if not board_config:
		return 1
	var def := board_config.get_unit_def(unit.unit_def_id)
	if def:
		return max(def.attack_range, 0)
	return 1


func _is_walkable(board: TbsBoardState, coords: Vector2i) -> bool:
	if not board.has_tile(coords):
		return false
	var tile := board.get_tile(coords)
	if not board_config:
		return board.get_unit_at(coords) == null
	var terrain_def := board_config.get_terrain_def(tile.terrain_id)
	if terrain_def and not terrain_def.walkable:
		return false
	return board.get_unit_at(coords) == null


func get_movable_tiles(board: TbsBoardState, unit: TbsUnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [unit.coords]
	var distance := {unit.coords: 0}
	var max_range := _get_move_range(unit)

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for n in TbsHexCoord.neighbors_axial(current.x, current.y):
			if not board.has_tile(n):
				continue
			var new_dist: int = distance[current] + 1
			if new_dist > max_range:
				continue
			if distance.has(n):
				continue
			if not _is_walkable(board, n) and n != unit.coords:
				continue
			distance[n] = new_dist
			frontier.append(n)

	distance.erase(unit.coords)
	result = distance.keys()
	return result


func get_attackable_tiles(board: TbsBoardState, unit: TbsUnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var max_range := _get_attack_range(unit)
	var visited: Dictionary = {unit.coords: 0}
	var frontier: Array[Vector2i] = [unit.coords]

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var dist: int = visited[current]
		for n in TbsHexCoord.neighbors_axial(current.x, current.y):
			if not board.has_tile(n):
				continue
			var new_dist := dist + 1
			if new_dist > max_range:
				continue
			if visited.has(n):
				continue
			visited[n] = new_dist
			frontier.append(n)
			var target_unit := board.get_unit_at(n)
			if target_unit and target_unit.team_id != unit.team_id:
				if n not in result:
					result.append(n)

	return result


func resolve_attack(board: TbsBoardState, attacker: TbsUnitState, target: TbsUnitState) -> void:
	if not board_config:
		return
	var attacker_def := board_config.get_unit_def(attacker.unit_def_id)
	if not attacker_def:
		return
	var damage := max(attacker_def.attack_power, 0)
	target.hp -= damage
	if target.hp <= 0:
		board.remove_unit(target.id)
