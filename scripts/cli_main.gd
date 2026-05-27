extends SceneTree

# Minimal headless entry point.
# Run with:
#   godot --headless --quit --script res://scripts/cli_main.gd
#
# This intentionally avoids any Node2D/scene instantiation and only uses logic models.

func _initialize() -> void:
	var radius = 2
	var grid_model: Dictionary[Vector2i, Tile] = {}

	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var s = -r - q
			if abs(s) > radius:
				continue
			var tile = Tile.new(q, r)
			grid_model[tile.coords] = tile

	# Spawn one legion in the center if possible (no gameplay changes, just data wiring)
	var center = Vector2i(0, 0)
	if grid_model.has(center) and grid_model[center].walkable:
		var legion = Legion.new("ARCHER", 4, center)
		grid_model[center].legion = legion

	quit()

