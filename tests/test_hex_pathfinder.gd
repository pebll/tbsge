extends RefCounted

const HexPathfinder = preload("res://scripts/ai/hex_pathfinder.gd")
const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_straight_path():
		return false
	if not _test_path_around_blocked_legion():
		return false
	if not _test_no_path_to_water_goal():
		return false
	if not _test_hex_distance():
		return false
	print("Success: Hex pathfinder tests")
	return true

func _make_grid(radius: int = 3) -> Dictionary:
	var grid := MapBuilderScript.build_grid(radius)
	for tile in grid.values():
		tile.terrain_type = "GRASS"
		tile.walkable = true
	return grid

func _blocked_except(grid: Dictionary, except: Array[Vector2i] = []) -> Dictionary:
	var blocked: Dictionary = {}
	for tile in grid.values():
		if tile.has_legion() and tile.coords not in except:
			blocked[tile.coords] = true
	return blocked

func _place_legion(grid: Dictionary, coords: Vector2i, team_id: String = "GREEN") -> Legion:
	var legion := Legion.new("ARCHER", 1, coords, team_id)
	var tile: Tile = grid.get(coords)
	tile.legion = legion
	return legion

func _test_hex_distance() -> bool:
	if HexPathfinder.hex_distance(Vector2i(0, 0), Vector2i(0, 0)) != 0:
		push_error("Distance to self should be 0")
		return false
	if HexPathfinder.hex_distance(Vector2i(0, 0), Vector2i(1, 0)) != 1:
		push_error("Adjacent hex distance should be 1")
		return false
	if HexPathfinder.hex_distance(Vector2i(0, 0), Vector2i(2, -1)) != 2:
		push_error("Expected distance 2")
		return false
	return true

func _test_straight_path() -> bool:
	var grid := _make_grid()
	var path := HexPathfinder.find_path(grid, Vector2i(0, 0), Vector2i(2, 0), {})
	if path.is_empty():
		push_error("Expected a path on open grass")
		return false
	if path[0] != Vector2i(0, 0) or path[path.size() - 1] != Vector2i(2, 0):
		push_error("Path should connect start and goal")
		return false
	return true

func _test_path_around_blocked_legion() -> bool:
	var grid := _make_grid()
	_place_legion(grid, Vector2i(1, 0), "BLUE")
	var blocked := _blocked_except(grid, [Vector2i(0, 0)])
	var path := HexPathfinder.find_path(grid, Vector2i(0, 0), Vector2i(2, 0), blocked)
	if path.is_empty():
		push_error("Expected a path around the blocking legion")
		return false
	if Vector2i(1, 0) in path:
		push_error("Path should not pass through an occupied tile")
		return false
	return true

func _test_no_path_to_water_goal() -> bool:
	var grid := _make_grid()
	var water: Tile = grid.get(Vector2i(2, 0))
	if water:
		water.terrain_type = "WATER"
		water.walkable = false
	var path := HexPathfinder.find_path(grid, Vector2i(0, 0), Vector2i(2, 0), {})
	if not path.is_empty():
		push_error("Expected no path when goal is water")
		return false
	return true
