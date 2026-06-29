class_name GridPresenter
extends Node2D

const HexLayoutScript = preload("res://scripts/core/hex_layout.gd")
const MatchSessionScript = preload("res://scripts/match/match_session.gd")
const LEGION_SCENE := preload("res://scenes/legion.tscn")
const HEX_TILE_SCENE := preload("res://scenes/hextile.tscn")

@export var tile_size: float = HexLayoutScript.DEFAULT_TILE_SIZE
@export var tile_size_xy_ratio: float = HexLayoutScript.DEFAULT_XY_RATIO

var grid_visu: Dictionary = {}
var legion_to_visu: Dictionary = {}
var tiles_container: Node

func _ready() -> void:
	tiles_container = Node.new()
	tiles_container.name = "Tiles"
	add_child(tiles_container)

func build_map_from_grid(grid: Dictionary) -> void:
	_clear_map()
	for coords in grid.keys():
		var tile: Tile = grid[coords]
		var hex_tile: TileVisu = HEX_TILE_SCENE.instantiate()
		var world_pos: Vector2 = HexLayoutScript.axial_to_worldv(
			coords, tile_size, tile_size_xy_ratio
		)
		hex_tile.position = world_pos
		hex_tile.z_index = HexLayoutScript.depth_sort_z(world_pos.y)
		tiles_container.add_child(hex_tile)
		hex_tile.init(tile)
		grid_visu[coords] = hex_tile

func tile_visu_at(coords: Vector2i) -> TileVisu:
	return grid_visu.get(coords)

func get_legion_visu(legion: Legion) -> LegionVisu:
	if legion_to_visu.has(legion):
		return legion_to_visu[legion]
	for tile_visu in grid_visu.values():
		if tile_visu and tile_visu.legion_visu and tile_visu.legion_visu.legion == legion:
			legion_to_visu[legion] = tile_visu.legion_visu
			return tile_visu.legion_visu
	return null

func sync_legions(session: MatchSessionScript) -> void:
	for legion in session.legions:
		if legion.units.is_empty():
			_remove_legion_visu(legion)
			continue
		if legion_to_visu.has(legion):
			continue
		spawn_legion_visu(legion)

func spawn_legion_visu(legion: Legion, formation_seed: int = -1) -> void:
	var tile_visu: TileVisu = grid_visu.get(legion.tile_coords)
	if not tile_visu:
		return
	var legion_visu: LegionVisu = LEGION_SCENE.instantiate()
	add_child(legion_visu)
	legion_to_visu[legion] = legion_visu
	tile_visu.legion_visu = legion_visu
	legion_visu.init(legion, formation_seed)
	legion_visu.position = tile_visu.position

func rewire_legion_tile(legion: Legion, from_coords: Vector2i, to_coords: Vector2i) -> void:
	var visu: LegionVisu = get_legion_visu(legion)
	if not visu:
		return
	var from_tile: TileVisu = grid_visu.get(from_coords)
	var to_tile: TileVisu = grid_visu.get(to_coords)
	if from_tile and from_tile.legion_visu == visu:
		from_tile.legion_visu = null
	if to_tile:
		to_tile.legion_visu = visu

func cleanup_dead_legion_at(coords: Vector2i, session: MatchSessionScript) -> void:
	var tile: Tile = session.grid.get(coords)
	var tile_visu: TileVisu = grid_visu.get(coords)
	if not tile or not tile_visu:
		return
	if tile.legion and tile.legion.units.size() > 0:
		return
	if tile.legion:
		_remove_legion_visu(tile.legion)
	tile.legion = null
	tile_visu.legion_visu = null

func tween_legion_move(legion: Legion, to_coords: Vector2i) -> Tween:
	var visu: LegionVisu = legion_to_visu.get(legion)
	var target: TileVisu = grid_visu.get(to_coords)
	if not visu or not target:
		return null
	_orient_legion_toward(visu, target.position)
	AudioManager.play_unit_move(legion.unit_type)
	return visu.juice_move(target.position)

func tween_legion_swap(legion_a: Legion, legion_b: Legion, to_a: Vector2i, to_b: Vector2i) -> Array:
	var tweens: Array = []
	var visu_a: LegionVisu = legion_to_visu.get(legion_a)
	var visu_b: LegionVisu = legion_to_visu.get(legion_b)
	var tile_a: TileVisu = grid_visu.get(to_a)
	var tile_b: TileVisu = grid_visu.get(to_b)
	if visu_a and tile_a:
		_orient_legion_toward(visu_a, tile_a.position)
		AudioManager.play_unit_move(legion_a.unit_type)
		tweens.append(visu_a.juice_move(tile_a.position))
	if visu_b and tile_b:
		_orient_legion_toward(visu_b, tile_b.position)
		AudioManager.play_unit_move(legion_b.unit_type)
		tweens.append(visu_b.juice_move(tile_b.position))
	return tweens

func _orient_legion_toward(legion_visu: LegionVisu, target_world_pos: Vector2) -> void:
	var dir := target_world_pos - legion_visu.position
	if dir.length_squared() > 0.0001:
		legion_visu.update_direction(dir.normalized())

func remove_dead_legions(session: MatchSessionScript) -> void:
	for legion in legion_to_visu.keys():
		if legion not in session.legions or legion.units.is_empty():
			_remove_legion_visu(legion)

func _remove_legion_visu(legion: Legion) -> void:
	var visu: LegionVisu = legion_to_visu.get(legion)
	legion_to_visu.erase(legion)
	if visu == null:
		return
	var tile_visu: TileVisu = grid_visu.get(legion.tile_coords)
	if tile_visu and tile_visu.legion_visu == visu:
		tile_visu.legion_visu = null
	visu.queue_free()

func _clear_map() -> void:
	for child in tiles_container.get_children():
		child.queue_free()
	grid_visu.clear()
	for visu in legion_to_visu.values():
		if visu:
			visu.queue_free()
	legion_to_visu.clear()
