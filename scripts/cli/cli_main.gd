extends SceneTree

# Minimal headless entry point.
# Run with:
#   flatpak run org.godotengine.Godot -- --path . --headless --display-driver headless \
#     --audio-driver Dummy --script res://scripts/cli/cli_main.gd
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
		var legion = Legion.new("GOBLIN", 4, center, "BLUE")
		grid_model[center].legion = legion

	quit()

