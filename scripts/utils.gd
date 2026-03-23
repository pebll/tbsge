class_name Utils

static func get_direction(from: HexTile, to: HexTile) -> Vector2:
	var difference : Vector2 = to.position - from.position
	var direction : Vector2 = difference.normalized()
	return direction

static func get_surrounding_tiles(tile: HexTile, grid: Dictionary) -> Array[HexTile]:
	var offsets : Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),Vector2i(0, -1), Vector2i(1, -1)]
	var tiles : Array[HexTile]= []
	for offset in offsets:
		var t = grid.get(tile.coords + offset)
		if t:
			tiles.append(t)
	return tiles

static func get_surrounding_walkable_tiles(tile: HexTile, grid: Dictionary) -> Array[HexTile]:
	var tiles = get_surrounding_tiles(tile, grid)
	var walkable_tiles : Array[HexTile] = []
	for t in tiles:
		if t.walkable:
			walkable_tiles.append(t)
	return walkable_tiles

static func get_movable_tiles(tile: HexTile, grid: Dictionary) -> Array[HexTile]:
	var tiles = get_surrounding_walkable_tiles(tile, grid)
	var new_tiles : Array[HexTile] = []
	for t in tiles:
		if not t.unit:
			new_tiles.append(t)
	return new_tiles

static func get_attackable_tiles(tile: HexTile, grid: Dictionary) -> Array[HexTile]:
	var tiles = get_surrounding_walkable_tiles(tile, grid)
	var new_tiles : Array[HexTile] = []
	for t in tiles:
		if t.unit:
			new_tiles.append(t)
	return new_tiles
