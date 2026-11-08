extends RefCounted

## Fog of war: which hexes a team sees. Each legion sees BASE_VISION hexes around it
## (+ terrain vision_mod, e.g. forest -1; flyers +1), blocked by line of sight
## (mountains). A team always sees its own legions' hexes.
##
## Rules use it to stop targeting unseen enemies (ActionTargeting). The AI plans with full
## knowledge (decided 2026-11-07: "the AI sees through fog at first").

const TerrainRules = preload("res://scripts/terrain/terrain_rules.gd")
const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")

const BASE_VISION := 2
const FLYER_BONUS := 1

static func vision_range(legion: Legion, tile: Tile) -> int:
	var v := BASE_VISION
	if tile != null:
		v += TerrainRules.vision_mod(tile.terrain_type)
	if TerrainRules.is_flyer(legion):
		v += FLYER_BONUS
	return maxi(1, v)

## Set (Dictionary coords -> true) of hexes `team` sees on `grid`.
static func visible_set(grid: Dictionary, team: String) -> Dictionary:
	var seen: Dictionary = {}
	var eyes: Array = []
	for c in grid.keys():
		var t: Tile = grid[c]
		if t != null and t.has_legion() and t.legion.team_id == team and not t.legion.units.is_empty():
			eyes.append(t)
	for t in eyes:
		var r := vision_range(t.legion, t)
		seen[t.coords] = true
		for c in grid.keys():
			if seen.has(c):
				continue
			var d := HexPathfinder.hex_distance(t.coords, c)
			if d <= r and (d <= 1 or TerrainRules.has_los(grid, t.coords, c)):
				seen[c] = true
	return seen

static func sees(grid: Dictionary, team: String, coords: Vector2i) -> bool:
	return visible_set(grid, team).has(coords)
