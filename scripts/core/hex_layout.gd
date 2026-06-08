class_name HexLayout
extends RefCounted

const DEFAULT_TILE_SIZE := 135.3
const DEFAULT_XY_RATIO := 0.75

static func axial_to_world(
	q: int,
	r: int,
	tile_size: float = DEFAULT_TILE_SIZE,
	ratio: float = DEFAULT_XY_RATIO
) -> Vector2:
	var x := tile_size * (float(q) + 0.5 * float(r))
	var y := tile_size * ratio * (0.75 * float(r))
	return Vector2(x, y)

static func axial_to_worldv(
	coords: Vector2i,
	tile_size: float = DEFAULT_TILE_SIZE,
	ratio: float = DEFAULT_XY_RATIO
) -> Vector2:
	return axial_to_world(coords.x, coords.y, tile_size, ratio)

static func depth_sort_z(world_y: float) -> int:
	return int(world_y / 10.0)
