class_name TbsBoardState
extends RefCounted


var tiles: Dictionary = {}        # Vector2i -> TbsTileState
var units_by_id: Dictionary = {}  # int -> TbsUnitState
var unit_at: Dictionary = {}      # Vector2i -> int (unit id)

var _next_unit_id: int = 1


func add_tile(coords: Vector2i, terrain_id: String) -> void:
	var tile := TbsTileState.new(coords, terrain_id)
	tiles[coords] = tile


func has_tile(coords: Vector2i) -> bool:
	return tiles.has(coords)


func get_tile(coords: Vector2i) -> TbsTileState:
	return tiles.get(coords, null)


func add_unit(unit_def_id: String, coords: Vector2i, team_id: int) -> TbsUnitState:
	var id := _next_unit_id
	_next_unit_id += 1
	var unit := TbsUnitState.new(id, unit_def_id, coords, team_id)
	units_by_id[id] = unit
	unit_at[coords] = id
	return unit


func get_unit(id: int) -> TbsUnitState:
	return units_by_id.get(id, null)


func get_unit_at(coords: Vector2i) -> TbsUnitState:
	if not unit_at.has(coords):
		return null
	var id: int = unit_at[coords]
	return get_unit(id)


func move_unit(id: int, to_coords: Vector2i) -> bool:
	var unit := get_unit(id)
	if unit == null:
		return false
	if not has_tile(to_coords):
		return false
	if unit_at.has(to_coords):
		return false

	unit_at.erase(unit.coords)
	unit.coords = to_coords
	unit_at[to_coords] = id
	return true


func remove_unit(id: int) -> void:
	var unit := get_unit(id)
	if unit == null:
		return
	if unit_at.has(unit.coords):
		unit_at.erase(unit.coords)
	units_by_id.erase(id)


