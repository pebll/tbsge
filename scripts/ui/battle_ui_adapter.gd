class_name BattleUIAdapter
extends RefCounted

## Thin façade over BattleInteraction for hosts (minigame / sandbox).
## Hosts own a BattleContext; this adapter binds Interaction once.

const BattleInteractionScript = preload("res://scripts/ui/battle_interaction.gd")
const BattleContextScript = preload("res://scripts/battle/battle_context.gd")

var context: BattleContextScript
var interaction: BattleInteractionScript

func _init(p_context: BattleContextScript) -> void:
	context = p_context
	interaction = BattleInteractionScript.new()
	interaction.bind_from_context(context)
	interaction.bind_events()

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
