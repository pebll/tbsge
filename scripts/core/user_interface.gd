class_name GameUI

const BattleStateScript = preload("res://scripts/actions/battle_state.gd")

var gamemanager: GameManager
var interaction: BattleInteraction

func _init(gamemanager_: GameManager) -> void:
	gamemanager = gamemanager_
	interaction = BattleInteraction.new()
	interaction.battle_state_fn = func():
		if not is_instance_valid(gamemanager):
			return null
		return BattleStateScript.from_game_manager(gamemanager)
	interaction.tile_visu_fn = func(coords: Vector2i) -> TileVisu:
		if not is_instance_valid(gamemanager):
			return null
		return gamemanager.grid_visu.get(coords)
	interaction.is_locked_fn = func() -> bool:
		if not is_instance_valid(gamemanager):
			return true
		return gamemanager.input.is_locked()
	interaction.can_act_fn = func(legion: Legion) -> bool:
		if not is_instance_valid(gamemanager):
			return false
		return gamemanager.can_act_legion(legion)
	interaction.apply_action_fn = func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
		if not is_instance_valid(gamemanager):
			return
		gamemanager.use_battle_action(action_id, from_coords, to_coords)
	interaction.allows_spawn_fn = func(_coords: Vector2i) -> bool: return true
	interaction.spawn_fn = func(coords: Vector2i) -> void: gamemanager.spawn_unit(coords)
	interaction.turn_manager_fn = func() -> TurnManager: return gamemanager.turn_manager
	interaction.legions_fn = func() -> Array:
		var out: Array[Legion] = []
		for tile in gamemanager.grid_model.values():
			if tile and tile.has_legion():
				out.append(tile.legion)
		return out
	interaction._inspect_fn = func(coords: Vector2i) -> void: gamemanager.inspect_tile(coords)
	interaction._clear_inspect_fn = func() -> void: gamemanager.clear_inspect()
	interaction.bind_events()

func attach_action_bar(bar: Control) -> void:
	interaction.action_bar = bar
	bar.action_pressed.connect(interaction._on_action_bar_pressed)

func can_accept_command() -> bool:
	return interaction.can_accept_command()

func deselect() -> void:
	interaction.deselect()

func select_tile(coords: Vector2i) -> void:
	interaction.select_tile(coords)

func refresh_after_action(legion_coords: Vector2i) -> void:
	interaction.refresh_after_action(legion_coords)

func clear_overlays() -> void:
	interaction.clear_overlays()

func cycle_legion_tab() -> void:
	interaction.cycle_legion_tab()

func pass_current_legion() -> void:
	interaction.pass_current_legion()

func unbind() -> void:
	interaction.unbind_events()
