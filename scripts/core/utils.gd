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
	var tiles = get_surrounding_walkable_tiles(tile, grid)
	var new_tiles : Array[Tile] = []
	for t in tiles:
		if t.has_legion():
			new_tiles.append(t)
	return new_tiles
