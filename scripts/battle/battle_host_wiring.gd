class_name BattleHostWiring
extends RefCounted

## Shared wiring helpers so sandbox and minigame stay on one battle-host contract.
##
## ActionPlayback / BattleActionRunner hook contract (Dictionary keys):
## - session: MatchSession (cleanup after combat)
## - clear_overlays / deselect / refresh_after_action: UI Callables
## - deselect_before_combat / deselect_after_combat / deselect_after_heal: bools
## - on_ap_changed(legion) / on_finished(): optional callbacks

const BattleContextScript = preload("res://scripts/battle/battle_context.gd")

## Build ActionPlayback / BattleActionRunner hooks from a battle UI adapter.
static func action_hooks(
	session,
	battle_ui,
	opts: Dictionary = {}
) -> Dictionary:
	return {
		"session": session,
		"clear_overlays": battle_ui.clear_overlays,
		"deselect": battle_ui.deselect,
		"deselect_before_combat": bool(opts.get("deselect_before_combat", false)),
		"deselect_after_combat": bool(opts.get("deselect_after_combat", false)),
		"deselect_after_heal": bool(opts.get("deselect_after_heal", true)),
		"on_ap_changed": opts.get(
			"on_ap_changed",
			func(legion: Legion) -> void: EventBus.legion_ap_changed.emit(legion)
		),
		"refresh_after_action": battle_ui.refresh_after_action,
		"on_finished": opts.get("on_finished", func() -> void: pass),
	}

## TAB cycle / SPACE pass. Returns true if the event was handled.
static func handle_hotkeys(event: InputEvent, battle_ui) -> bool:
	if battle_ui == null:
		return false
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
		battle_ui.cycle_legion_tab()
		return true
	if key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE:
		battle_ui.pass_current_legion()
		return true
	return false

static func wire_core_context(
	context: BattleContextScript,
	session,
	presenter,
	is_locked_fn: Callable,
	apply_action_fn: Callable,
	inspect_fn: Callable,
	clear_inspect_fn: Callable,
	overlay_ui_fn: Callable = Callable()
) -> void:
	context.session = session
	context.presenter = presenter
	context.is_locked_fn = is_locked_fn
	context.apply_action_fn = apply_action_fn
	context.inspect_fn = inspect_fn
	context.clear_inspect_fn = clear_inspect_fn
	if overlay_ui_fn.is_valid():
		context.overlay_ui_fn = overlay_ui_fn

static func rng_seed_for_action(action_id: String) -> Dictionary:
	if action_id == "melee_attack" or action_id == "ranged_attack":
		return {"rng_seed": randi()}
	return {}
