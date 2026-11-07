class_name HypotheticalPosition
extends RefCounted

## AI "what if this legion stood there?" queries.
##
## Temporarily relocates `legion` on the grid, runs `query` (which must return its
## result — GDScript lambdas capture locals by value), then restores occupancy and
## coords exactly. All hypothetical relocation goes through here so no caller can
## forget (or early-return past) the restore step.
static func evaluate(
	grid: Dictionary,
	legion: Legion,
	at_coords: Vector2i,
	query: Callable,
	fallback: Variant = null
) -> Variant:
	if legion == null:
		return fallback
	var tile_new: Tile = grid.get(at_coords)
	if tile_new == null:
		return fallback
	var old := legion.tile_coords
	var tile_old: Tile = grid.get(old)
	var prev_new: Legion = tile_new.legion
	var owned_old := tile_old != null and tile_old.legion == legion

	if owned_old:
		tile_old.legion = null
	tile_new.legion = legion
	legion.tile_coords = at_coords

	var result: Variant = query.call()

	tile_new.legion = prev_new
	legion.tile_coords = old
	if owned_old:
		tile_old.legion = legion
	return result
