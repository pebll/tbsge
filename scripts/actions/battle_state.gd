class_name BattleState
extends RefCounted

var grid: Dictionary = {}
var turn_manager: TurnManager

func _init(p_grid: Dictionary, p_turn_manager: TurnManager) -> void:
	grid = p_grid
	turn_manager = p_turn_manager

static func from_minigame(session: MinigameSession) -> BattleState:
	return BattleState.new(session.grid, session.turn_manager)

static func from_game_manager(gm: GameManager) -> BattleState:
	return BattleState.new(gm.grid_model, gm.turn_manager)

func tile_at(coords: Vector2i) -> Tile:
	return grid.get(coords)

func can_act_legion(legion: Legion) -> bool:
	return legion != null and turn_manager.is_legion_active(legion) and legion.has_ap()

func finish_legion_turn(coords: Vector2i) -> void:
	turn_manager.wait_legion(coords)
