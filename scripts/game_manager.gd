class_name GameManager
extends Node2D

@export var map_radius: int = 3
var tile_size: float = 135.3
var tile_size_xy_ratio: float = 0.75
const UNITS = ["AXEMAN", "ARCHER", "DRAGON_RIDER", "OGRE", "MAGE", "FLAME", "NECROMANCER", "TREANT"]


@onready var grid_visu : Dictionary[Vector2i, TileVisu] = {}
@onready var grid_model : Dictionary[Vector2i, Tile] = {}
@onready var legions : Array[Legion] = []

var tilesContainer : Node
var ui : UserInterface
var mapGenerator : MapGenerator

func _ready():
	ui = UserInterface.new(self)
	mapGenerator = MapGenerator.new(tile_size, tile_size_xy_ratio)
	# TODO: fix this when refactor mapgenerator
	tilesContainer = Node.new()
	tilesContainer.name = "Tiles" 
	get_tree().root.add_child.call_deferred(tilesContainer)
	mapGenerator.generate_hex_map(map_radius, tilesContainer, self.grid_visu, self.grid_model)

# Todo: refactor HexTile to have a logic side?
func spawn_unit(coords: Vector2i):
	var tile = grid_model.get(coords)
	var tile_visu = grid_visu.get(coords)
	if not tile or not tile_visu:
		return

	# Spawns random legion at given coords
	if tile.has_legion() or not tile.walkable:
		print("tile not adequate for spawning")
		return # only spawn if tile is empty
	var legion = Legion.new(UNITS[randi()%8], randi()%8+1, coords)
	var legionVisu = preload("res://scenes/legion.tscn").instantiate()
	# TODO: refactor this into own folder (like for the tiles)
	self.add_child(legionVisu)
	legions.append(legion)
	tile.legion = legion
	tile_visu.legion_visu = legionVisu
	legionVisu.init(legion)
	legionVisu.position = tile_visu.position
	legionVisu.z_index = tile_visu.z_index + 1

func move_unit(from_coords: Vector2i, to_coords: Vector2i):
	var from_tile = grid_model.get(from_coords)
	var to_tile = grid_model.get(to_coords)
	var from_visu = grid_visu.get(from_coords)
	var to_visu = grid_visu.get(to_coords)
	if not from_tile or not to_tile or not from_visu or not to_visu:
		return
	if not from_tile.legion:
		return
	if to_tile.has_legion():
		return

	var legion: Legion = from_tile.legion
	var legion_visu: LegionVisu = from_visu.legion_visu

	from_tile.legion = null
	from_visu.legion_visu = null
	to_tile.legion = legion
	to_visu.legion_visu = legion_visu
	legion.tile_coords = to_coords

	legion_visu.juice_move(to_visu.position)

func attack_unit(from_coords: Vector2i, to_coords: Vector2i):
	var from_visu = grid_visu.get(from_coords)
	var to_visu = grid_visu.get(to_coords)
	if not from_visu or not to_visu:
		return
	if not from_visu.legion_visu or not to_visu.legion_visu:
		return

	var difference : Vector2 = to_visu.position - from_visu.position
	var dir = difference.normalized()
	from_visu.legion_visu.update_direction(dir)
	from_visu.legion_visu.juice_attack(dir)
	to_visu.legion_visu.juice_hitted(dir)
