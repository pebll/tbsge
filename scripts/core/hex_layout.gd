class_name HexLayout
extends RefCounted

const DEFAULT_TILE_SIZE := 135.3
const DEFAULT_XY_RATIO := 0.75

## Iso/hex draw order: z = depth_row(y) * STRIDE + layer.
## Southern (higher Y) rows sort entirely in front of northern ones.
const DEPTH_STRIDE := 10
const DEPTH_LAYER_TILE := 0
const DEPTH_LAYER_TILE_OVERLAY := 1
const DEPTH_LAYER_SHADOW := 2
const DEPTH_LAYER_BANNER := 3
const DEPTH_LAYER_UNITS := 4
const DEPTH_LAYER_LOCAL_FX := 5

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

static func depth_row(world_y: float) -> int:
	return int(world_y / 10.0)

## Layer is clamped into the stride so rows never collide.
static func depth_sort_z(world_y: float, layer: int = DEPTH_LAYER_TILE) -> int:
	var clamped := clampi(layer, 0, DEPTH_STRIDE - 1)
	return depth_row(world_y) * DEPTH_STRIDE + clamped
