class_name MapGenerator

const HexLayoutScript = preload("res://scripts/core/hex_layout.gd")

var tile_size: float = HexLayoutScript.DEFAULT_TILE_SIZE
var tile_size_xy_ratio: float = HexLayoutScript.DEFAULT_XY_RATIO

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
			var world_pos: Vector2 = HexLayoutScript.axial_to_world(q, r, tile_size, tile_size_xy_ratio)
			hex_tile.position = world_pos
			hex_tile.z_index = HexLayoutScript.depth_sort_z(
				world_pos.y, HexLayoutScript.DEPTH_LAYER_TILE
			)
			parent.add_child(hex_tile)
			hex_tile.init(tile)
			grid_visu[Vector2i(q, r)] = hex_tile
			grid_model[Vector2i(q, r)] = tile
