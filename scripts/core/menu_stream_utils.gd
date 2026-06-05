class_name MenuStreamUtils

static func axial_to_world(q: int, r: int, tile_size: float, ratio: float) -> Vector2:
	var x := tile_size * (float(q) + 0.5 * float(r))
	var y := tile_size * ratio * (0.75 * float(r))
	return Vector2(x, y)

static func world_to_axial_approx(world: Vector2, tile_size: float, ratio: float) -> Vector2:
	var r_approx := world.y / (tile_size * ratio * 0.75)
	var q_approx := world.x / tile_size - 0.5 * r_approx
	return Vector2(q_approx, r_approx)

static func coord_bounds_for_rect(rect: Rect2, tile_size: float, ratio: float, margin: int) -> Dictionary:
	var corners: Array[Vector2] = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
		rect.position + rect.size,
	]
	var q_min := 1_000_000
	var q_max := -1_000_000
	var r_min := 1_000_000
	var r_max := -1_000_000
	for corner in corners:
		var axial := world_to_axial_approx(corner, tile_size, ratio)
		q_min = mini(q_min, int(floor(axial.x)) - margin)
		q_max = maxi(q_max, int(ceil(axial.x)) + margin)
		r_min = mini(r_min, int(floor(axial.y)) - margin)
		r_max = maxi(r_max, int(ceil(axial.y)) + margin)
	return {"q_min": q_min, "q_max": q_max, "r_min": r_min, "r_max": r_max}

static func coord_in_bounds(coords: Vector2i, bounds: Dictionary) -> bool:
	return (
		coords.x >= bounds.q_min
		and coords.x <= bounds.q_max
		and coords.y >= bounds.r_min
		and coords.y <= bounds.r_max
	)

static func iter_coords_in_bounds(bounds: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(bounds.q_min, bounds.q_max + 1):
		for r in range(bounds.r_min, bounds.r_max + 1):
			result.append(Vector2i(q, r))
	return result
