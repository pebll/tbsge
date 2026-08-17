class_name BattleContext
extends RefCounted

const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const MatchSessionScript = preload("res://scripts/match/match_session.gd")
const GridPresenterScript = preload("res://scripts/visu/grid_presenter.gd")

var session: MatchSessionScript
var presenter: GridPresenterScript
var is_locked_fn: Callable = func() -> bool: return false
var apply_action_fn: Callable = func(_id: String, _from: Vector2i, _to: Vector2i) -> void: pass
var apply_move_path_fn: Callable = Callable()
var battle_phase_fn: Callable = func() -> bool: return true
var allows_spawn_fn: Callable = func(_coords: Vector2i) -> bool: return false
var spawn_fn: Callable = func(_coords: Vector2i) -> void: pass
var inspect_fn: Callable = func(_coords: Vector2i) -> void: pass
var clear_inspect_fn: Callable = func() -> void: pass
var preview_inspect_fn: Callable = Callable()
var clear_preview_inspect_fn: Callable = Callable()
var expectation_preview_fn: Callable = Callable()
var clear_expectation_preview_fn: Callable = Callable()
var overlay_ui_fn: Callable = Callable()

func battle_state() -> BattleStateScript:
	if session == null:
		return null
	return session.battle_state()

func tile_visu_at(coords: Vector2i) -> TileVisu:
	if presenter == null:
		return null
	return presenter.tile_visu_at(coords)

func can_act_legion(legion: Legion) -> bool:
	if session == null:
		return false
	return session.can_act_legion(legion)

func is_input_locked() -> bool:
	if is_locked_fn.is_valid():
		return bool(is_locked_fn.call())
	return false

func turn_manager() -> TurnManager:
	if session == null:
		return null
	return session.turn_manager

func legions() -> Array:
	if session == null:
		return []
	return session.typed_legions()

func apply_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if apply_action_fn.is_valid():
		apply_action_fn.call(action_id, from_coords, to_coords)

func apply_move_path(path: Array) -> void:
	if apply_move_path_fn.is_valid():
		apply_move_path_fn.call(path)

func in_battle_phase() -> bool:
	if battle_phase_fn.is_valid():
		return bool(battle_phase_fn.call())
	return true

func allows_spawn(coords: Vector2i) -> bool:
	if allows_spawn_fn.is_valid():
		return bool(allows_spawn_fn.call(coords))
	return false

func spawn_at(coords: Vector2i) -> void:
	if spawn_fn.is_valid():
		spawn_fn.call(coords)

func inspect_tile(coords: Vector2i) -> void:
	if inspect_fn.is_valid():
		inspect_fn.call(coords)

func preview_inspect(coords: Vector2i) -> void:
	if preview_inspect_fn.is_valid():
		preview_inspect_fn.call(coords)
	elif inspect_fn.is_valid():
		inspect_fn.call(coords)

func clear_preview_inspect() -> void:
	if clear_preview_inspect_fn.is_valid():
		clear_preview_inspect_fn.call()
	elif clear_inspect_fn.is_valid():
		clear_inspect_fn.call()

func clear_inspect() -> void:
	if clear_inspect_fn.is_valid():
		clear_inspect_fn.call()

func show_expectation_preview(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i
) -> void:
	if expectation_preview_fn.is_valid():
		expectation_preview_fn.call(attacker, defender, action_id, from_coords, to_coords)

func clear_expectation_preview() -> void:
	if clear_expectation_preview_fn.is_valid():
		clear_expectation_preview_fn.call()
