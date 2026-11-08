class_name MapBuilder
extends RefCounted

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const Utils = preload("res://scripts/core/utils.gd")

const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")

const MAX_CONNECTIVITY_ATTEMPTS := 4096
## Chance a tile takes its neighbours' majority terrain (patches instead of noise).
const CLUSTER_CHANCE := 0.45
const WALKABLE_TERRAINS := ["GRASS", "DESERT", "FOREST"]

static func build_grid(radius: int, rng_seed: int = -1, team_ids: Array[String] = []) -> Dictionary:
	var grid: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		# Global RNG (randomised at startup) so a test can reproduce maps with seed().
		rng.seed = randi()

	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s := -r - q
			if abs(s) > radius:
				continue
			var tile := Tile.new(q, r)
			grid[Vector2i(q, r)] = tile
	if rng_seed >= 0:
		_generate_terrain(grid, rng)

	if team_ids.size() >= 2:
		_ensure_deploy_back_rows_walkable(grid, radius, team_ids, rng)
		_ensure_deploy_zones_connected(grid, radius, team_ids, rng)
	return grid

## Weighted terrain (TerrainDefinition.map_weight), one clustering pass so forests and
## lakes form patches, mirrored through the centre so both sides get the same map.
static func _generate_terrain(grid: Dictionary, rng: RandomNumberGenerator) -> void:
	var ids: Array[String] = []
	var weights: Array[float] = []
	for id in TerrainRules.all_ids():
		var def = TerrainRules.get_def(id)
		if def != null and def.map_weight > 0.0:
			ids.append(id)
			weights.append(def.map_weight)
	if ids.is_empty():
		return
	var half := _canonical_half(grid)
	for c in half:
		_set_terrain(grid, c, _weighted_pick(ids, weights, rng))
	for c in half:
		if rng.randf() < CLUSTER_CHANCE:
			var counts := {}
			for n in Utils.get_surrounding_coords(c):
				var t: Tile = grid.get(n)
				if t:
					counts[t.terrain_type] = int(counts.get(t.terrain_type, 0)) + 1
			var best := ""
			var best_n := 1
			for k in counts.keys():
				if int(counts[k]) > best_n:
					best = k
					best_n = int(counts[k])
			if not best.is_empty():
				_set_terrain(grid, c, best)

## One coords of every mirror pair (q, r) / (-q, -r), plus the centre.
static func _canonical_half(grid: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in grid.keys():
		var v: Vector2i = c
		if v.y < 0 or (v.y == 0 and v.x <= 0):
			out.append(v)
	out.sort()
	return out

## Sets the tile and its mirror (fair maps).
static func _set_terrain(grid: Dictionary, coords: Vector2i, terrain_id: String) -> void:
	for c in [coords, -coords]:
		var t: Tile = grid.get(c)
		if t:
			t.terrain_type = terrain_id
			t.walkable = TerrainRules.ground_walkable(terrain_id)

static func _weighted_pick(ids: Array[String], weights: Array[float], rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for w in weights:
		total += w
	var x := rng.randf() * total
	for i in range(ids.size()):
		x -= weights[i]
		if x <= 0.0:
			return ids[i]
	return ids[ids.size() - 1]

static func _ensure_deploy_back_rows_walkable(
	grid: Dictionary,
	radius: int,
	team_ids: Array[String],
	rng: RandomNumberGenerator
) -> void:
	var row_count := MinigameRulesScript.obstacle_free_back_row_count(radius)
	for team_id in team_ids.slice(0, 2):
		for coords in MinigameRulesScript.deploy_back_rows_coords(radius, team_id, team_ids, row_count):
			var tile: Tile = grid.get(coords)
			if tile and not tile.walkable:
				_set_random_walkable(tile, rng, grid)

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

	var protected := _obstacle_free_coords_set(radius, team_ids)
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
			_set_random_walkable(tile, rng, grid)

static func _set_random_walkable(tile: Tile, rng: RandomNumberGenerator, grid: Dictionary = {}) -> void:
	var id: String = WALKABLE_TERRAINS[rng.randi() % WALKABLE_TERRAINS.size()]
	if grid.is_empty():
		tile.terrain_type = id
		tile.walkable = true
	else:
		_set_terrain(grid, tile.coords, id)

static func _obstacle_free_coords_set(radius: int, team_ids: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	var row_count := MinigameRulesScript.obstacle_free_back_row_count(radius)
	for team_id in team_ids.slice(0, 2):
		for coords in MinigameRulesScript.deploy_back_rows_coords(radius, team_id, team_ids, row_count):
			out[coords] = true
	return out

static func _back_row_coords_set(radius: int, team_ids: Array[String]) -> Dictionary:
	return _obstacle_free_coords_set(radius, team_ids)

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
