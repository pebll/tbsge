@tool
extends Node

@export var radius: int = 3:
	set(value):
		radius = value
		generate_hex_map()


@export var tile_size: float = 64.0:
	set(value):
		tile_size = value
		generate_hex_map()

@export var tile_size_xy_ratio: float = 1.4:
	set(value):
		tile_size_xy_ratio = value
		generate_hex_map()
		
@onready var gamemanager : GameManager = GameManagerGlobal


func generate_hex_map():
	if not is_inside_tree():
		return
	
	# Clear existing tiles
	for child in get_children():
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
			add_child(hex_tile)
			gamemanager.grid[Vector2i(q, r)] = hex_tile
func _ready() -> void:
	generate_hex_map()
