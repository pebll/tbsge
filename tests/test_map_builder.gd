extends RefCounted

const MapBuilder = preload("res://scripts/minigame/map_builder.gd")
const MinigameRules = preload("res://scripts/minigame/minigame_rules.gd")

const TEAMS: Array[String] = ["GREEN", "BLUE"]

func run(_tree: SceneTree) -> bool:
	if not _test_back_rows_always_walkable():
		return false
	if not _test_deploy_zones_connected_across_seeds():
		return false
	if not _test_large_maps_clear_two_back_rows():
		return false
	print("Success: Map builder tests")
	return true

func _test_back_rows_always_walkable() -> bool:
	for seed_val in range(50):
		var grid := MapBuilder.build_grid(3, seed_val, TEAMS)
		for team_id in TEAMS:
			for coords in MinigameRules.deploy_back_row_coords(3, team_id, TEAMS):
				var tile: Tile = grid.get(coords)
				if tile == null:
					push_error("Missing back-row tile at %s" % coords)
					return false
				if not tile.walkable:
					push_error("Back-row tile not walkable at %s (seed %d)" % [coords, seed_val])
					return false
				if tile.terrain_type == "MOUNTAIN" or tile.terrain_type == "WATER":
					push_error("Back-row tile impassable terrain at %s (seed %d)" % [coords, seed_val])
					return false
	return true

func _test_deploy_zones_connected_across_seeds() -> bool:
	for seed_val in range(50):
		var grid := MapBuilder.build_grid(3, seed_val, TEAMS)
		var zone_a := MinigameRules.deploy_zone_coords(3, TEAMS[0], 0, TEAMS)
		var zone_b := MinigameRules.deploy_zone_coords(3, TEAMS[1], 0, TEAMS)
		if not MapBuilder._deploy_zones_have_path(grid, zone_a, zone_b):
			push_error("Deploy zones not connected for seed %d" % seed_val)
			return false
	return true

func _test_large_maps_clear_two_back_rows() -> bool:
	for radius in [4, 5]:
		for seed_val in range(30):
			var grid := MapBuilder.build_grid(radius, seed_val, TEAMS)
			var row_count := MinigameRules.obstacle_free_back_row_count(radius)
			if row_count != 2:
				push_error("Expected 2 obstacle-free rows for radius %d" % radius)
				return false
			for team_id in TEAMS:
				for coords in MinigameRules.deploy_back_rows_coords(radius, team_id, TEAMS, row_count):
					var tile: Tile = grid.get(coords)
					if tile == null or not tile.walkable:
						push_error(
							"Radius %d seed %d: expected walkable at %s"
							% [radius, seed_val, coords]
						)
						return false
					if tile.terrain_type == "MOUNTAIN" or tile.terrain_type == "WATER":
						push_error(
							"Radius %d seed %d: obstacle on back rows at %s (%s)"
							% [radius, seed_val, coords, tile.terrain_type]
						)
						return false
	return true
