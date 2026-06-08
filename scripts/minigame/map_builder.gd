class_name MapBuilder
extends RefCounted

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const Utils = preload("res://scripts/core/utils.gd")

const MAX_CONNECTIVITY_ATTEMPTS := 4096
const WALKABLE_TERRAINS := ["GRASS", "DESERT", "FOREST"]

static func build_grid(radius: int, rng_seed: int = -1, team_ids: Array[String] = []) -> Dictionary:
	var grid: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s := -r - q
			if abs(s) > radius:
				continue
			var tile := Tile.new(q, r)
			if rng_seed >= 0:
				var terrain_idx := rng.randi() % Tile.TERRAINS.size()
				tile.terrain_type = Tile.TERRAINS[terrain_idx]
				tile.walkable = not (tile.terrain_type == "MOUNTAIN" or tile.terrain_type == "WATER")
			grid[Vector2i(q, r)] = tile

	if team_ids.size() >= 2:
		_ensure_deploy_back_rows_walkable(grid, radius, team_ids, rng)
		_ensure_deploy_zones_connected(grid, radius, team_ids, rng)
	return grid

static func _ensure_deploy_back_rows_walkable(
	grid: Dictionary,
	radius: int,
	team_ids: Array[String],
	rng: RandomNumberGenerator
) -> void:
	for team_id in team_ids.slice(0, 2):
		for coords in MinigameRulesScript.deploy_back_row_coords(radius, team_id, team_ids):
			var tile: Tile = grid.get(coords)
			if tile:
				_set_random_walkable(tile, rng)

static func _ensure_deploy_zones_connected(
	grid: Dictionary,
	radius: int,
	team_ids: Array[String],
	rng: RandomNumberGenerator
) -> void:
	var zone_a := MinigameRulesScript.deploy_zone_coords(radius, team_ids[0], 0, team_ids)
	var zone_b := MinigameRulesScript.deploy_zone_coords(radius, team_ids[1], 0, team_ids)
	if zone_a.is_empty() or zone_b.is_empty():
		return

	var protected := _back_row_coords_set(radius, team_ids)
	var attempts := 0
	while not _deploy_zones_have_path(grid, zone_a, zone_b):
		attempts += 1
		if attempts > MAX_CONNECTIVITY_ATTEMPTS:
			push_warning(
				"MapBuilder: could not connect deploy zones after %d attempts" % MAX_CONNECTIVITY_ATTEMPTS
			)
			break
		var candidates := _impassable_tiles_outside_back_rows(grid, protected)
		if candidates.is_empty():
			break
		var coords: Vector2i = candidates[rng.randi() % candidates.size()]
		var tile: Tile = grid.get(coords)
		if tile:
			_set_random_walkable(tile, rng)

static func _set_random_walkable(tile: Tile, rng: RandomNumberGenerator) -> void:
	tile.terrain_type = WALKABLE_TERRAINS[rng.randi() % WALKABLE_TERRAINS.size()]
	tile.walkable = true

static func _back_row_coords_set(radius: int, team_ids: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for team_id in team_ids.slice(0, 2):
		for coords in MinigameRulesScript.deploy_back_row_coords(radius, team_id, team_ids):
			out[coords] = true
	return out

static func _impassable_tiles_outside_back_rows(
	grid: Dictionary,
	protected: Dictionary
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for coords in grid.keys():
		if protected.has(coords):
			continue
		var tile: Tile = grid[coords]
		if not tile.walkable:
			candidates.append(coords)
	return candidates

static func _deploy_zones_have_path(
	grid: Dictionary,
	zone_a: Array[Vector2i],
	zone_b: Array[Vector2i]
) -> bool:
	var goals: Dictionary = {}
	for coords in zone_b:
		var goal_tile: Tile = grid.get(coords)
		if goal_tile != null and goal_tile.walkable:
			goals[coords] = true
	if goals.is_empty():
		return false

	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}
	for coords in zone_a:
		var start_tile: Tile = grid.get(coords)
		if start_tile == null or not start_tile.walkable:
			continue
		if visited.has(coords):
			continue
		visited[coords] = true
		queue.append(coords)

	if queue.is_empty():
		return false

	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if goals.has(current):
			return true
		for neighbor in Utils.get_surrounding_coords(current):
			if visited.has(neighbor):
				continue
			var tile: Tile = grid.get(neighbor)
			if tile == null or not tile.walkable:
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return false
