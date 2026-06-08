class_name HexPathfinder
extends RefCounted

const Utils = preload("res://scripts/core/utils.gd")

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -dq - dr
	return maxi(absi(dq), maxi(absi(dr), absi(ds)))

static func find_path(
	grid: Dictionary,
	from_coords: Vector2i,
	to_coords: Vector2i,
	blocked_coords: Dictionary = {}
) -> Array[Vector2i]:
	if from_coords == to_coords:
		return [from_coords]

	var goal_tile: Tile = grid.get(to_coords)
	if goal_tile == null or not goal_tile.walkable:
		return []
	if blocked_coords.has(to_coords):
		return []

	var open: Array[Vector2i] = [from_coords]
	var open_set: Dictionary = {from_coords: true}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from_coords: 0}
	var f_score: Dictionary = {from_coords: float(hex_distance(from_coords, to_coords))}

	while not open.is_empty():
		open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return float(f_score.get(a, INF)) < float(f_score.get(b, INF))
		)
		var current: Vector2i = open[0]
		open.remove_at(0)
		open_set.erase(current)

		if current == to_coords:
			return _reconstruct_path(came_from, current)

		for neighbor in Utils.get_surrounding_coords(current):
			if not _is_traversable(grid, neighbor, to_coords, blocked_coords):
				continue
			var tentative_g: float = float(g_score.get(current, INF)) + 1.0
			if tentative_g >= float(g_score.get(neighbor, INF)):
				continue
			came_from[neighbor] = current
			g_score[neighbor] = tentative_g
			f_score[neighbor] = tentative_g + float(hex_distance(neighbor, to_coords))
			if not open_set.has(neighbor):
				open.append(neighbor)
				open_set[neighbor] = true

	return []

static func _is_traversable(
	grid: Dictionary,
	coords: Vector2i,
	goal_coords: Vector2i,
	blocked_coords: Dictionary
) -> bool:
	var tile: Tile = grid.get(coords)
	if tile == null or not tile.walkable:
		return false
	if coords == goal_coords:
		return true
	if blocked_coords.has(coords):
		return false
	return not tile.has_legion()

static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)
	return path
