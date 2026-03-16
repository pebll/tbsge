class_name TbsGameController
extends Node


@export var ruleset: TbsRuleset
@export var board_config: TbsBoardConfig


var board_state: TbsBoardState
var current_team_id: int = 0


signal board_initialized
signal unit_moved(unit: TbsUnitState, from_coords: Vector2i, to_coords: Vector2i)
signal unit_attacked(attacker: TbsUnitState, target: TbsUnitState)


func _ready() -> void:
	print("[TBSGE] GameController _ready")
	_initialize_board()


func _initialize_board() -> void:
	print("[TBSGE] Initializing board")
	board_state = TbsBoardState.new()

	if board_config:
		print("[TBSGE] Using board_config: ", board_config)
		for tile_dict in board_config.tiles:
			var coords := tile_dict.get("coords", Vector2i.ZERO)
			var terrain_id := tile_dict.get("terrain_id", "")
			board_state.add_tile(coords, terrain_id)

		for spawn in board_config.unit_spawns:
			var coords := spawn.get("coords", Vector2i.ZERO)
			var unit_def_id := spawn.get("unit_def_id", "")
			var team_id := spawn.get("team_id", 0)
			board_state.add_unit(unit_def_id, coords, team_id)
	print("[TBSGE] Board initialized with tiles: ", board_state.tiles.size(), " units: ", board_state.units_by_id.size())
	emit_signal("board_initialized")


func get_movable_tiles_for_unit(unit: TbsUnitState) -> Array[Vector2i]:
	if not ruleset:
		return []
	return ruleset.get_movable_tiles(board_state, unit)


func get_attackable_tiles_for_unit(unit: TbsUnitState) -> Array[Vector2i]:
	if not ruleset:
		return []
	return ruleset.get_attackable_tiles(board_state, unit)


func move_unit(unit: TbsUnitState, to_coords: Vector2i) -> bool:
	var from_coords := unit.coords
	var ok := board_state.move_unit(unit.id, to_coords)
	if ok:
		emit_signal("unit_moved", unit, from_coords, to_coords)
	return ok


func attack(attacker: TbsUnitState, target: TbsUnitState) -> void:
	if not ruleset:
		return
	ruleset.resolve_attack(board_state, attacker, target)
	emit_signal("unit_attacked", attacker, target)


func can_end_turn() -> bool:
	if not ruleset:
		return true
	return ruleset.can_end_turn(board_state, current_team_id)


func end_turn() -> void:
	# Simple 2-team toggle for now.
	current_team_id = 1 - current_team_id

