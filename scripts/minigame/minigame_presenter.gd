class_name MinigamePresenter
extends Node2D

const TILE_SIZE := 135.3
const TILE_SIZE_XY_RATIO := 0.75
const LEGION_SCENE := preload("res://scenes/legion.tscn")
const HEX_TILE_SCENE := preload("res://scenes/hextile.tscn")

const LIFT_DEPLOY := 2.0
const LIFT_SELECTED := 4.0

var grid_visu: Dictionary = {}
var legion_to_visu: Dictionary = {}
var draft_preview_legions: Array = []
var tiles_container: Node

func _ready() -> void:
	tiles_container = Node.new()
	tiles_container.name = "Tiles"
	add_child(tiles_container)

func build_map(session: MinigameSession) -> void:
	_clear_map()
	for coords in session.grid.keys():
		var tile: Tile = session.grid[coords]
		var hex_tile: TileVisu = HEX_TILE_SCENE.instantiate()
		var x := TILE_SIZE * (float(coords.x) + 0.5 * float(coords.y))
		var y := TILE_SIZE * TILE_SIZE_XY_RATIO * (0.75 * float(coords.y))
		hex_tile.position = Vector2(x, y)
		hex_tile.z_index = int(y / 10.0)
		tiles_container.add_child(hex_tile)
		hex_tile.init(tile)
		grid_visu[coords] = hex_tile

func paint_deploy_zones(
	deploy_slots: Array,
	occupied_coords: Array,
	selected_coords: Vector2i
) -> void:
	clear_deploy_overlays()
	for coords in deploy_slots:
		var visu: TileVisu = grid_visu.get(coords)
		if not visu:
			continue
		if coords == selected_coords:
			visu.set_gameplay_overlay("selected", LIFT_SELECTED)
		elif coords in occupied_coords:
			visu.set_gameplay_overlay("deployed", LIFT_DEPLOY)
		else:
			visu.set_gameplay_overlay("deployable", LIFT_DEPLOY)

func clear_deploy_overlays() -> void:
	for visu in grid_visu.values():
		if visu:
			visu.set_gameplay_overlay("", 0.0)

func sync_draft_previews(placements: Array, team_id: String) -> void:
	_clear_draft_previews()
	for p in placements:
		var coords: Vector2i = p.get("coords", Vector2i.ZERO)
		var unit_type: String = String(p.get("unit_type", ""))
		var unit_count: int = int(p.get("unit_count", 0))
		if unit_type.is_empty() or unit_count < 1:
			continue
		var legion := Legion.new(unit_type, unit_count, coords, team_id)
		draft_preview_legions.append(legion)
		_spawn_legion_visu(legion)

func sync_legions(session: MinigameSession) -> void:
	_clear_draft_previews()
	for legion in session.legions:
		if legion.units.is_empty():
			_remove_legion_visu(legion)
			continue
		if legion_to_visu.has(legion):
			continue
		_spawn_legion_visu(legion)

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

func cleanup_dead_legion_at(coords: Vector2i, session: MinigameSession) -> void:
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
	return visu.juice_move(target.position)

func tween_legion_swap(legion_a: Legion, legion_b: Legion, to_a: Vector2i, to_b: Vector2i) -> Array:
	var tweens: Array = []
	var visu_a: LegionVisu = legion_to_visu.get(legion_a)
	var visu_b: LegionVisu = legion_to_visu.get(legion_b)
	var tile_a: TileVisu = grid_visu.get(to_a)
	var tile_b: TileVisu = grid_visu.get(to_b)
	if visu_a and tile_a:
		tweens.append(visu_a.juice_move(tile_a.position))
	if visu_b and tile_b:
		tweens.append(visu_b.juice_move(tile_b.position))
	return tweens

func remove_dead_legions(session: MinigameSession) -> void:
	for legion in legion_to_visu.keys():
		if legion not in session.legions or legion.units.is_empty():
			_remove_legion_visu(legion)

func _spawn_legion_visu(legion: Legion) -> void:
	var tile_visu: TileVisu = grid_visu.get(legion.tile_coords)
	if not tile_visu:
		return
	var legion_visu: LegionVisu = LEGION_SCENE.instantiate()
	add_child(legion_visu)
	legion_to_visu[legion] = legion_visu
	tile_visu.legion_visu = legion_visu
	legion_visu.init(legion)
	legion_visu.position = tile_visu.position

func _remove_legion_visu(legion: Legion) -> void:
	var visu: LegionVisu = legion_to_visu.get(legion)
	if visu:
		visu.queue_free()
	legion_to_visu.erase(legion)
	var tile_visu: TileVisu = grid_visu.get(legion.tile_coords)
	if tile_visu and tile_visu.legion_visu == visu:
		tile_visu.legion_visu = null

func _clear_draft_previews() -> void:
	for legion in draft_preview_legions:
		_remove_legion_visu(legion)
	draft_preview_legions.clear()

func _clear_map() -> void:
	_clear_draft_previews()
	for child in tiles_container.get_children():
		child.queue_free()
	grid_visu.clear()
	for visu in legion_to_visu.values():
		if visu:
			visu.queue_free()
	legion_to_visu.clear()
