class_name MapBuilder
extends RefCounted

static func build_grid(radius: int, rng_seed: int = -1) -> Dictionary:
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
				# Deterministic terrain pick for seeded maps.
				var terrain_idx := rng.randi() % Tile.TERRAINS.size()
				tile.terrain_type = Tile.TERRAINS[terrain_idx]
				tile.walkable = not (tile.terrain_type == "MOUNTAIN" or tile.terrain_type == "WATER")
			grid[Vector2i(q, r)] = tile
	return grid
