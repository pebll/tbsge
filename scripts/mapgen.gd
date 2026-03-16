class_name MapGenerator
extends Node

var tile_size: float = 135.3
var tile_size_xy_ratio: float = 0.75

@onready var gamemanager : GameManager = GameManagerGlobal


func init(p_tile_size: float, p_tile_size_xy_ratio: float) -> void:
	tile_size = tile_size
	tile_size_xy_ratio = p_tile_size_xy_ratio

func generate_hex_map(radius: int, parent: Node):
	# Clear existing tiles
	for child in parent.get_children():
		child.queue_free()
	
	# Loop through all possible coords in a square
	for q in range(-radius, radius+1):
		for r in range(-radius, radius+1):
			var s = - r - q
			if abs(s) > radius:
				continue
			var hex_tile = preload("res://scenes/hextile.tscn").instantiate()
			var x = tile_size * (q + 0.5 * r)
			var y = tile_size* tile_size_xy_ratio * (0.75 * r)
			hex_tile.position = Vector2(x, y)
			hex_tile.z_index = y / 10
			hex_tile.setup(q, r)
			parent.add_child(hex_tile)
			gamemanager.grid[Vector2i(q, r)] = hex_tile
