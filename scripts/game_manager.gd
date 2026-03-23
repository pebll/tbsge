class_name GameManager
extends Node2D

@export var map_radius: int = 3
var tile_size: float = 135.3
var tile_size_xy_ratio: float = 0.75

@onready var grid : Dictionary[Vector2i, HexTile] = {}
@onready var units : Array[Unit] = []

@onready var utils : Utils = UtilsGlobal
@onready var mapGenerator : MapGenerator = MapGeneratorGlobal

var tilesContainer : Node

func _ready():
	mapGenerator.init(tile_size, tile_size_xy_ratio)
	tilesContainer = Node.new()
	tilesContainer.name = "Tiles" 
	get_tree().root.add_child.call_deferred(tilesContainer)
	
	setup_game.call_deferred()

func setup_game():
	# Generate map
	mapGenerator.generate_hex_map(map_radius, tilesContainer)
	
func spawn_unit(tile: HexTile):
	# Spawns random unit at given coords
	if tile.unit or not tile.walkable:
		print("tile not adequate for spawning")
		return # only spawn if tile is empty
	var unit = preload("res://scenes/unit.tscn").instantiate()
	self.add_child(unit)
	units.append(unit)
	tile.unit = unit
	unit.sprite.z_index = 100
	unit.position = tile.position

func move_unit(from: HexTile, to: HexTile):
	var unit = from.unit
	from.unit = null
	to.unit = unit
	unit.juice_move(to.position)

func attack_unit(from: HexTile, to: HexTile):
	var dir = utils.get_direction(from, to)
	from.unit.update_direction(dir)
	from.unit.juice_attack(dir)
	to.unit.juice_hitted(dir)
