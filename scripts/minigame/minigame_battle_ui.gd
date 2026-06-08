class_name MinigameBattleUI
extends RefCounted

var root: MinigameRoot
var interaction: BattleInteraction

func _init(p_root: MinigameRoot) -> void:
	root = p_root
	interaction = BattleInteraction.new()
	interaction.battle_state_fn = func(): return root.session.battle_state()
	interaction.tile_visu_fn = func(coords: Vector2i) -> TileVisu: return root.presenter.tile_visu_at(coords)
	interaction.is_locked_fn = func() -> bool: return root.input_locked or root._ai_running
	interaction.can_act_fn = func(legion: Legion) -> bool: return root.session.can_act_legion(legion)
	interaction.apply_action_fn = func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
		root.request_use_action(action_id, from_coords, to_coords)
	interaction.turn_manager_fn = func() -> TurnManager: return root.session.turn_manager
	interaction.legions_fn = func() -> Array: return root.session._typed_legions()
	interaction._inspect_fn = func(coords: Vector2i) -> void: root.inspect_tile(coords)
	interaction._clear_inspect_fn = func() -> void: root.clear_inspect()
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
