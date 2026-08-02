class_name BattleUIAdapter
extends RefCounted

const BattleInteractionScript = preload("res://scripts/ui/battle_interaction.gd")
const BattleContextScript = preload("res://scripts/battle/battle_context.gd")

var context: BattleContextScript
var interaction: BattleInteractionScript

func _init(p_context: BattleContextScript) -> void:
	context = p_context
	interaction = BattleInteractionScript.new()
	_wire_interaction()
	interaction.bind_events()

func _wire_interaction() -> void:
	interaction.battle_state_fn = func(): return context.battle_state()
	interaction.tile_visu_fn = func(coords: Vector2i) -> TileVisu: return context.tile_visu_at(coords)
	interaction.is_locked_fn = func() -> bool: return context.is_input_locked()
	interaction.can_act_fn = func(legion: Legion) -> bool: return context.can_act_legion(legion)
	interaction.apply_action_fn = func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
		context.apply_action(action_id, from_coords, to_coords)
	interaction.battle_phase_fn = func() -> bool: return context.in_battle_phase()
	interaction.allows_spawn_fn = func(coords: Vector2i) -> bool: return context.allows_spawn(coords)
	interaction.spawn_fn = func(coords: Vector2i) -> void: context.spawn_at(coords)
	interaction.turn_manager_fn = func() -> TurnManager: return context.turn_manager()
	interaction.legions_fn = func() -> Array: return context.legions()
	interaction._inspect_fn = func(coords: Vector2i) -> void: context.inspect_tile(coords)
	interaction._clear_inspect_fn = func() -> void: context.clear_inspect()
	if context.overlay_ui_fn.is_valid():
		interaction.overlay_ui_fn = context.overlay_ui_fn

func attach_action_bar(bar: Control) -> void:
	interaction.action_bar = bar
	if bar.has_signal("action_pressed"):
		bar.action_pressed.connect(interaction._on_action_bar_pressed)

func unbind() -> void:
	interaction.unbind_events()
	context = null

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
