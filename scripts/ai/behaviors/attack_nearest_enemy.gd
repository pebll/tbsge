class_name AttackNearestEnemyBehavior
extends RefCounted

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const Utils = preload("res://scripts/core/utils.gd")

static func decide(session: MinigameSession, legion: Legion) -> Dictionary:
	if legion == null or not session.can_act_legion(legion):
		return {"type": "pass", "coords": legion.tile_coords if legion else Vector2i.ZERO}

	var enemies := _enemy_legions(session, legion.team_id)
	if enemies.is_empty():
		return {"type": "pass", "coords": legion.tile_coords}

	var nearest: Legion = _find_nearest_enemy(legion.tile_coords, enemies)
	var nearest_coords := nearest.tile_coords
	var from_coords := legion.tile_coords

	var attackable := session.get_attackable_coords(from_coords)
	if nearest_coords in attackable:
		return {"type": "attack", "from": from_coords, "to": nearest_coords}

	if not legion.can_afford(1):
		return {"type": "pass", "coords": from_coords}

	var movable := session.get_movable_coords(from_coords)
	if movable.is_empty():
		return {"type": "pass", "coords": from_coords}

	var blocked := _blocked_coords(session, from_coords)
	var best_step: Variant = _best_step_toward(session.grid, from_coords, nearest_coords, movable, blocked)
	if best_step == null:
		return {"type": "pass", "coords": from_coords}

	return {"type": "move", "from": from_coords, "to": best_step}

static func _enemy_legions(session: MinigameSession, team_id: String) -> Array[Legion]:
	var out: Array[Legion] = []
	for legion in session.legions:
		if legion.team_id != team_id and not legion.units.is_empty():
			out.append(legion)
	return out

static func _find_nearest_enemy(from_coords: Vector2i, enemies: Array[Legion]) -> Legion:
	var best: Legion = enemies[0]
	var best_dist := HexPathfinder.hex_distance(from_coords, best.tile_coords)
	for i in range(1, enemies.size()):
		var enemy: Legion = enemies[i]
		var dist := HexPathfinder.hex_distance(from_coords, enemy.tile_coords)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best

static func _blocked_coords(session: MinigameSession, ignore_coords: Vector2i) -> Dictionary:
	var blocked: Dictionary = {}
	for legion in session.legions:
		if legion.tile_coords != ignore_coords:
			blocked[legion.tile_coords] = true
	return blocked

static func _best_step_toward(
	grid: Dictionary,
	from_coords: Vector2i,
	enemy_coords: Vector2i,
	movable: Array[Vector2i],
	blocked: Dictionary
) -> Variant:
	var best_path: Array[Vector2i] = []
	for goal in Utils.get_surrounding_coords(enemy_coords):
		if goal == enemy_coords:
			continue
		var goal_tile: Tile = grid.get(goal)
		if goal_tile == null or not goal_tile.walkable or goal_tile.has_legion():
			continue
		var path := HexPathfinder.find_path(grid, from_coords, goal, blocked)
		if path.size() < 2:
			continue
		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path

	if best_path.size() < 2:
		return _greedy_step(from_coords, enemy_coords, movable)

	var next_step: Vector2i = best_path[1]
	if next_step in movable:
		return next_step
	return _greedy_step(from_coords, enemy_coords, movable)

static func _greedy_step(
	from_coords: Vector2i,
	enemy_coords: Vector2i,
	movable: Array[Vector2i]
) -> Variant:
	var current_dist := HexPathfinder.hex_distance(from_coords, enemy_coords)
	var best: Vector2i = Vector2i(2147483646, 2147483646)
	var best_dist := current_dist
	for coords in movable:
		var dist := HexPathfinder.hex_distance(coords, enemy_coords)
		if dist < best_dist:
			best_dist = dist
			best = coords
	if best_dist < current_dist:
		return best
	return null
