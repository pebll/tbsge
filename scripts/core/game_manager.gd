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

	# Logic-only combat: update healths and remove dead units/legions.
	var attacker: Legion = from_tile.legion
	var defender: Legion = to_tile.legion
	if not attacker or not defender:
		return

	var result: Dictionary = CombatResolver.resolve_combat(attacker, defender, randi())
	var hits: Array = result.get("hits", [])
	var deaths: Array = result.get("deaths", [])

	# Build death lookup by hit index for immediate visual updates.
	var deaths_by_hit: Dictionary = {}
	for d in deaths:
		deaths_by_hit[d["hit_index"]] = d

	# Map model legions to their visu nodes (stable even when combat alternates).
	var legion_to_visu: Dictionary = {
		attacker: from_visu.legion_visu,
		defender: to_visu.legion_visu,
	}

	# Before the fight begins, make both legions face each other.
	var a_visu: LegionVisu = legion_to_visu.get(attacker)
	var d_visu: LegionVisu = legion_to_visu.get(defender)
	if a_visu and d_visu:
		var face_dir: Vector2 = (d_visu.global_position - a_visu.global_position).normalized()
		a_visu.update_direction(face_dir)
		d_visu.update_direction(-face_dir)

	# Play sequential animations: only attacker + target animate per hit.
	var gap_s := 0.3
	for h in hits:
		var atk_legion: Legion = h["attacker_legion"]
		var def_legion: Legion = h["defender_legion"]
		var atk_unit: Unit = h["attacker"]
		var def_unit: Unit = h["target"]

		var atk_visu: LegionVisu = legion_to_visu.get(atk_legion)
		var def_visu: LegionVisu = legion_to_visu.get(def_legion)
		if not atk_visu or not def_visu:
			continue

		var difference: Vector2 = def_visu.global_position - atk_visu.global_position
		var dir := difference.normalized()

		atk_visu.animate_unit_attack(atk_unit, dir)
		def_visu.animate_unit_hitted(def_unit, dir)

		# If a unit dies on this hit, remove it from the defending legion visu immediately.
		var hit_idx: int = h["hit_index"]
		if deaths_by_hit.has(hit_idx):
			var d = deaths_by_hit[hit_idx]
			if d["legion"] == def_legion:
				def_visu.remove_unit(d["unit"])

		# Wait for animation to read sequentially.
		await get_tree().create_timer(gap_s).timeout

	# Re-pack surviving units after the fight sequence.
	for lv in legion_to_visu.values():
		if lv:
			lv.update_local_positions()
			lv.tween_units_to_local_positions()

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
