class_name BattleInteraction
extends RefCounted

const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")

const LIFT_NONE := 0.0
const LIFT_OPTION := 2.0
const LIFT_SELECTED := 4.0

## Shown automatically when a legion is selected (no action button picked).
const DEFAULT_HIGHLIGHT_ACTION_IDS: Array[String] = ["move", "melee_attack"]

var battle_state_fn: Callable
var tile_visu_fn: Callable
var is_locked_fn: Callable
var can_act_fn: Callable
var apply_action_fn: Callable
var allows_spawn_fn: Callable = func(_coords: Vector2i) -> bool: return false
var spawn_fn: Callable = func(_coords: Vector2i) -> void: pass
var battle_phase_fn: Callable = func() -> bool: return true
var action_bar: Control

var selected_coords: Vector2i
var has_selected: bool = false
var selected_action: ActionDefinitionScript = null
var target_coords: Array[Vector2i] = []
var default_target_actions: Dictionary = {}
var _overlay_coords: Array[Vector2i] = []
var _info_tile_coords: Vector2i
var _info_visible_for_tile: bool = false
var _inspect_fn: Callable = func(_coords: Vector2i) -> void: pass
var _clear_inspect_fn: Callable = func() -> void: pass
var turn_manager_fn: Callable
var legions_fn: Callable
var _events_bound: bool = false

func bind_events() -> void:
	if _events_bound:
		return
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.tile_right_clicked.connect(_on_tile_right_clicked)
	EventBus.tile_hover_entered.connect(_on_tile_hover_entered)
	EventBus.tile_hover_exited.connect(_on_tile_hover_exited)
	_events_bound = true

func unbind_events() -> void:
	if not _events_bound:
		return
	if EventBus.tile_clicked.is_connected(_on_tile_clicked):
		EventBus.tile_clicked.disconnect(_on_tile_clicked)
	if EventBus.tile_right_clicked.is_connected(_on_tile_right_clicked):
		EventBus.tile_right_clicked.disconnect(_on_tile_right_clicked)
	if EventBus.tile_hover_entered.is_connected(_on_tile_hover_entered):
		EventBus.tile_hover_entered.disconnect(_on_tile_hover_entered)
	if EventBus.tile_hover_exited.is_connected(_on_tile_hover_exited):
		EventBus.tile_hover_exited.disconnect(_on_tile_hover_exited)
	_events_bound = false
	deselect()

func can_accept_command() -> bool:
	if not is_locked_fn.is_valid():
		return false
	return not bool(is_locked_fn.call())

func deselect() -> void:
	_clear_overlay_visuals()
	has_selected = false
	selected_action = null
	target_coords.clear()
	default_target_actions.clear()
	if action_bar:
		action_bar.clear_bar()

func select_tile(coords: Vector2i) -> void:
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		return
	var legion: Legion = _legion_at(state, coords)
	if legion == null or not bool(can_act_fn.call(legion)):
		return
	_clear_overlay_visuals()
	has_selected = true
	selected_coords = coords
	selected_action = null
	target_coords.clear()
	default_target_actions.clear()
	_paint_tile(coords, "selected", LIFT_SELECTED)
	_paint_default_targets(state, legion)
	if action_bar:
		action_bar.set_actions(ActionTargetingScript.available_actions(state, legion))

func select_action(action: ActionDefinitionScript) -> void:
	if not has_selected:
		return
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		return
	var legion: Legion = _legion_at(state, selected_coords)
	if legion == null:
		return
	if selected_action and selected_action.id == action.id:
		selected_action = null
		target_coords.clear()
		if action_bar:
			action_bar.set_selected(null)
		_clear_overlay_visuals()
		_paint_tile(selected_coords, "selected", LIFT_SELECTED)
		_paint_default_targets(state, legion)
		return

	_clear_overlay_visuals()
	selected_action = action
	target_coords = ActionTargetingScript.get_targets(state, legion, action)
	default_target_actions.clear()
	if action_bar:
		action_bar.set_selected(action)
	if action.targeting == ActionDefinitionScript.TargetingKind.SELF:
		_paint_tile(selected_coords, action.overlay_state, LIFT_OPTION)
	else:
		_paint_tile(selected_coords, "selected", LIFT_SELECTED)
		_paint_action_targets(action)

func refresh_after_action(legion_coords: Vector2i) -> void:
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		deselect()
		return
	var legion: Legion = _legion_at(state, legion_coords)
	if legion and bool(can_act_fn.call(legion)):
		select_tile(legion_coords)
	else:
		deselect()

func clear_overlays() -> void:
	_clear_overlay_visuals()

func _clear_overlay_visuals() -> void:
	for c in _overlay_coords:
		var t: TileVisu = tile_visu_fn.call(c)
		if t:
			t.set_hover_boost(false)
			t.set_gameplay_overlay("", LIFT_NONE)
	_overlay_coords.clear()

func cycle_legion_tab() -> void:
	if not can_accept_command():
		return
	var tm: TurnManager = turn_manager_fn.call()
	var legions: Array = legions_fn.call()
	var coords: Vector2i = tm.tab_next(legions)
	if coords == TurnManager.INVALID_COORDS:
		return
	deselect()
	select_tile(coords)

func pass_current_legion() -> void:
	if not can_accept_command():
		return
	if has_selected:
		var tm: TurnManager = turn_manager_fn.call()
		tm.wait_legion(selected_coords)
		deselect()
	cycle_legion_tab()

func _on_action_bar_pressed(action: ActionDefinitionScript) -> void:
	if not can_accept_command() or not has_selected:
		return
	AudioManager.play_sfx("tile_click")
	select_action(action)

func _on_tile_clicked(coords: Vector2i) -> void:
	if not battle_phase_fn.is_valid() or not bool(battle_phase_fn.call()):
		return
	if not can_accept_command():
		return
	AudioManager.play_sfx("tile_click")
	_dispatch_click(coords)

func _on_tile_right_clicked(coords: Vector2i) -> void:
	if not battle_phase_fn.is_valid() or not bool(battle_phase_fn.call()):
		return
	_info_tile_coords = coords
	_info_visible_for_tile = true
	_inspect_fn.call(coords)

func _on_tile_hover_entered(coords: Vector2i) -> void:
	if not coords in _overlay_coords:
		return
	AudioManager.play_sfx("tile_hover")
	var tile_visu: TileVisu = tile_visu_fn.call(coords)
	if tile_visu:
		tile_visu.set_hover_boost(true)
	if has_selected:
		var selected_visu: TileVisu = tile_visu_fn.call(selected_coords)
		if selected_visu and selected_visu.legion_visu and tile_visu:
			var dir := (tile_visu.position - selected_visu.position).normalized()
			selected_visu.legion_visu.update_direction(dir)

func _on_tile_hover_exited(coords: Vector2i) -> void:
	if _info_visible_for_tile and coords == _info_tile_coords:
		_info_visible_for_tile = false
		_clear_inspect_fn.call()
	if coords in _overlay_coords:
		var tile_visu: TileVisu = tile_visu_fn.call(coords)
		if tile_visu:
			tile_visu.set_hover_boost(false)
	if has_selected:
		var selected_visu: TileVisu = tile_visu_fn.call(selected_coords)
		if selected_visu and selected_visu.legion_visu:
			selected_visu.legion_visu.juice_direct_reset()

func _dispatch_click(coords: Vector2i) -> void:
	if has_selected and selected_action:
		var is_self_target := (
			selected_action.targeting == ActionDefinitionScript.TargetingKind.SELF
			and coords == selected_coords
		)
		if coords in target_coords or is_self_target:
			apply_action_fn.call(selected_action.id, selected_coords, coords)
			return
		return
	if has_selected and default_target_actions.has(coords):
		apply_action_fn.call(String(default_target_actions[coords]), selected_coords, coords)
		return
	if has_selected and coords == selected_coords:
		deselect()
		return

	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		return
	var tile: Tile = state.tile_at(coords)
	if tile and tile.has_legion():
		deselect()
		var legion: Legion = tile.legion
		if bool(can_act_fn.call(legion)):
			select_tile(coords)
		return

	deselect()
	if bool(allows_spawn_fn.call(coords)):
		spawn_fn.call(coords)

func _paint_default_targets(state: BattleStateScript, legion: Legion) -> void:
	default_target_actions.clear()
	for action_id in DEFAULT_HIGHLIGHT_ACTION_IDS:
		var action: ActionDefinitionScript = ActionDefs.get_def(action_id)
		if action == null or not ActionTargetingScript.can_use(state, legion, action):
			continue
		for c in ActionTargetingScript.get_targets(state, legion, action):
			if c == selected_coords:
				continue
			default_target_actions[c] = action_id
			_paint_tile(c, action.overlay_state, LIFT_OPTION)

func _paint_action_targets(action: ActionDefinitionScript) -> void:
	for c in target_coords:
		if c == selected_coords and action.targeting != ActionDefinitionScript.TargetingKind.SELF:
			continue
		_paint_tile(c, action.overlay_state, LIFT_OPTION)

func _paint_tile(coords: Vector2i, state: String, lift: float) -> void:
	if coords not in _overlay_coords:
		_overlay_coords.append(coords)
	var t: TileVisu = tile_visu_fn.call(coords)
	if t:
		t.set_gameplay_overlay(state, lift)

func _legion_at(state: BattleStateScript, coords: Vector2i) -> Legion:
	var tile: Tile = state.tile_at(coords)
	return tile.legion if tile and tile.has_legion() else null
