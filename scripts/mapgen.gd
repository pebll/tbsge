class_name MapGenerator

var tile_size: float = 135.3
var tile_size_xy_ratio: float = 0.75

func _init(p_tile_size: float, p_tile_size_xy_ratio: float) -> void:
	tile_size = p_tile_size
	tile_size_xy_ratio = p_tile_size_xy_ratio

func generate_hex_map(radius: int, parent: Node, grid_visu: Dictionary, grid_model: Dictionary):
	# Clear existing tiles
	for child in parent.get_children():
		child.queue_free()
	grid_visu.clear()
	grid_model.clear()
	
	# Loop through all possible coords in a square
	for q in range(-radius, radius+1):
		for r in range(-radius, radius+1):
			var s = - r - q
			if abs(s) > radius:
				continue
			var tile = Tile.new(q, r)
			var hex_tile: TileVisu = preload("res://scenes/hextile.tscn").instantiate()
			var x = tile_size * (q + 0.5 * r)
			var y = tile_size* tile_size_xy_ratio * (0.75 * r)
			hex_tile.position = Vector2(x, y)
			hex_tile.z_index = y / 10
			parent.add_child(hex_tile)
			hex_tile.init(tile)
			grid_visu[Vector2i(q, r)] = hex_tile
			grid_model[Vector2i(q, r)] = tile
