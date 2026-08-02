class_name Utils

static func get_surrounding_coords(coords: Vector2i) -> Array[Vector2i]:
	return [
		coords + Vector2i(1, 0),
		coords + Vector2i(0, 1),
		coords + Vector2i(-1, 1),
		coords + Vector2i(-1, 0),
		coords + Vector2i(0, -1),
		coords + Vector2i(1, -1),
	]

static func get_surrounding_tiles(tile: Tile, grid: Dictionary) -> Array[Tile]:
	var offsets : Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),Vector2i(0, -1), Vector2i(1, -1)]
	var tiles : Array[Tile]= []
	for offset in offsets:
		var t = grid.get(tile.coords + offset)
		if t:
			tiles.append(t)
	return tiles

static func get_surrounding_walkable_tiles(tile: Tile, grid: Dictionary) -> Array[Tile]:
	var tiles = get_surrounding_tiles(tile, grid)
	var walkable_tiles : Array[Tile] = []
	for t in tiles:
		if t.walkable:
			walkable_tiles.append(t)
	return walkable_tiles

static func get_movable_tiles(tile: Tile, grid: Dictionary) -> Array[Tile]:
	var tiles = get_surrounding_walkable_tiles(tile, grid)
	var new_tiles : Array[Tile] = []
	for t in tiles:
		if not t.has_legion():
			new_tiles.append(t)
	return new_tiles

static func get_attackable_tiles(tile: Tile, grid: Dictionary) -> Array[Tile]:
	if not tile.has_legion():
		return []
	var team_id: String = tile.legion.team_id
	var tiles = get_surrounding_walkable_tiles(tile, grid)
	var new_tiles: Array[Tile] = []
	for t in tiles:
		if t.has_legion() and t.legion.team_id != team_id:
			new_tiles.append(t)
	return new_tiles

## Enemies within [1, max_range] hexes. No line-of-sight check.
static func get_ranged_attackable_tiles(tile: Tile, grid: Dictionary, max_range: int) -> Array[Tile]:
	if not tile.has_legion() or max_range <= 0:
		return []
	var team_id: String = tile.legion.team_id
	var from_coords := tile.coords
	var out: Array[Tile] = []
	for coords in grid.keys():
		var t: Tile = grid[coords]
		if t == null or not t.has_legion():
			continue
		if t.legion.team_id == team_id:
			continue
		var dist := HexPathfinder.hex_distance(from_coords, t.coords)
		if dist >= 1 and dist <= max_range:
			out.append(t)
	return out

static func get_swappable_tiles(tile: Tile, grid: Dictionary) -> Array[Tile]:
	if not tile.has_legion():
		return []
	var team_id: String = tile.legion.team_id
	var tiles = get_surrounding_walkable_tiles(tile, grid)
	var new_tiles: Array[Tile] = []
	for t in tiles:
		if t.has_legion() and t.legion.team_id == team_id:
			new_tiles.append(t)
	return new_tiles
