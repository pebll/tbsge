class_name BattleState
extends RefCounted

var grid: Dictionary = {}
var turn_manager: TurnManager
## Match RNG (shared with the session); null for ad-hoc states.
var rng: RandomNumberGenerator = null
## Fog of war: enemy targets must be visible to the acting team.
var fog_of_war: bool = false

func _init(p_grid: Dictionary, p_turn_manager: TurnManager, p_rng: RandomNumberGenerator = null) -> void:
	grid = p_grid
	turn_manager = p_turn_manager
	rng = p_rng

static func from_session(session) -> BattleState:
	var session_rng: RandomNumberGenerator = session.get("rng")
	var state := BattleState.new(session.grid, session.turn_manager, session_rng)
	state.fog_of_war = bool(session.get("fog_of_war"))
	return state

## Combat seed for commands that didn't bring one.
func next_rng_seed() -> int:
	return int(rng.randi()) if rng != null else randi()

func tile_at(coords: Vector2i) -> Tile:
	return grid.get(coords)

func can_act_legion(legion: Legion) -> bool:
	return (
		legion != null
		and turn_manager.is_legion_active(legion)
		and legion.has_ap()
		and not legion.waited
	)

func finish_legion_turn(legion: Legion) -> void:
	turn_manager.wait_legion(legion)
