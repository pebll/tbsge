class_name GameManager
extends Node2D

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")

@export var map_radius: int = 3
var tile_size: float = 135.3
var tile_size_xy_ratio: float = 0.75
const UNITS = ["AXEMAN", "ARCHER", "DRAGON_RIDER", "OGRE", "MAGE", "FLAME", "NECROMANCER", "TREANT"]


@onready var grid_visu : Dictionary[Vector2i, TileVisu] = {}
@onready var grid_model : Dictionary[Vector2i, Tile] = {}
@onready var legions : Array[Legion] = []

var tilesContainer : Node
var ui : GameUI
var mapGenerator : MapGenerator
var tile_info_panel
var tile_info_layer: CanvasLayer

func _ready():
	ui = GameUI.new(self)
	mapGenerator = MapGenerator.new(tile_size, tile_size_xy_ratio)
	# TODO: fix this when refactor mapgenerator
	tilesContainer = Node.new()
	tilesContainer.name = "Tiles" 
	get_tree().root.add_child.call_deferred(tilesContainer)
	mapGenerator.generate_hex_map(map_radius, tilesContainer, self.grid_visu, self.grid_model)

	_setup_tile_info_ui()

func _setup_tile_info_ui() -> void:
	tile_info_layer = CanvasLayer.new()
	tile_info_layer.name = "UI"
	add_child(tile_info_layer)

	tile_info_panel = preload("res://scenes/ui/tile_info_panel.tscn").instantiate()
	tile_info_layer.add_child(tile_info_panel)
	tile_info_panel.hide()

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

func inspect_tile(coords: Vector2i) -> void:
	if not tile_info_panel:
		return
	var tile: Tile = grid_model.get(coords)
	if not tile or not tile.has_legion():
		tile_info_panel.hide()
		return
	tile_info_panel.show_tile(tile)
	tile_info_panel.show()

func clear_inspect() -> void:
	if tile_info_panel:
		tile_info_panel.hide()

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
	var from_tile = grid_model.get(from_coords)
	var to_tile = grid_model.get(to_coords)
	var from_visu = grid_visu.get(from_coords)
	var to_visu = grid_visu.get(to_coords)
	if not from_tile or not to_tile or not from_visu or not to_visu:
		return
	if not from_visu.legion_visu or not to_visu.legion_visu:
		return

	var difference : Vector2 = to_visu.position - from_visu.position
	var dir = difference.normalized()
	from_visu.legion_visu.update_direction(dir)
	from_visu.legion_visu.juice_attack(dir)
	to_visu.legion_visu.juice_hitted(dir)

	# Logic-only combat: update healths and remove dead units/legions.
	var attacker: Legion = from_tile.legion
	var defender: Legion = to_tile.legion
	if not attacker or not defender:
		return

	CombatResolver.resolve_combat(attacker, defender, randi())

	_cleanup_dead_legion(from_coords)
	_cleanup_dead_legion(to_coords)

func _cleanup_dead_legion(coords: Vector2i) -> void:
	var tile: Tile = grid_model.get(coords)
	var visu: TileVisu = grid_visu.get(coords)
	if not tile or not visu:
		return
	if tile.legion and tile.legion.units.size() > 0:
		return
	if tile.legion:
		legions.erase(tile.legion)
	tile.legion = null
	if visu.legion_visu:
		visu.legion_visu.queue_free()
	visu.legion_visu = null
