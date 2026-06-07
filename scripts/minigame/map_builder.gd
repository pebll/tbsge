class_name MapBuilder
extends RefCounted

static func build_grid(radius: int, terrain_type: String = "GRASS") -> Dictionary:
	var grid: Dictionary = {}
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s := -r - q
			if abs(s) > radius:
				continue
			var tile := Tile.new(q, r, terrain_type)
			tile.walkable = true
			grid[Vector2i(q, r)] = tile
	return grid
