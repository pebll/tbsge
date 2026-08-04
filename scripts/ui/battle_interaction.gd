class_name BattleInteraction
extends RefCounted

const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const ActionTargetingScript = preload("res://scripts/actions/action_targeting.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const MoveReachabilityScript = preload("res://scripts/battle/move_reachability.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const LIFT_NONE := 0.0
const LIFT_OPTION := 2.0
const LIFT_SELECTED := 4.0

## Shown automatically when a legion is selected (no action button picked).
const DEFAULT_HIGHLIGHT_ACTION_IDS: Array[String] = ["move", "melee_attack", "ranged_attack"]

const COLOR_POPUP_BG := Color(0.91, 0.86, 0.78)
const COLOR_POPUP_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_POPUP_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_ICON_BTN_BG := Color(0.93, 0.89, 0.82)
const ICON_BTN_SIZE := Vector2(96, 96)

var battle_state_fn: Callable
var tile_visu_fn: Callable
var is_locked_fn: Callable
var can_act_fn: Callable
var apply_action_fn: Callable
var apply_move_path_fn: Callable = Callable()
var allows_spawn_fn: Callable = func(_coords: Vector2i) -> bool: return false
var spawn_fn: Callable = func(_coords: Vector2i) -> void: pass
var battle_phase_fn: Callable = func() -> bool: return true
var overlay_ui_fn: Callable = Callable()
var action_bar: Control

var selected_coords: Vector2i
var has_selected: bool = false
var selected_action: ActionDefinitionScript = null
var target_coords: Array[Vector2i] = []
## coords -> Array[String] of action ids that can target this tile in default highlight mode.
var default_target_actions: Dictionary = {}
var _overlay_coords: Array[Vector2i] = []
var _info_tile_coords: Vector2i
var _info_visible_for_tile: bool = false
var _inspect_fn: Callable = func(_coords: Vector2i) -> void: pass
var _clear_inspect_fn: Callable = func() -> void: pass
var turn_manager_fn: Callable
var legions_fn: Callable
var _events_bound: bool = false
var _attack_choice_popup: Control = null
var _pending_move_dest: Vector2i
var _pending_move_active: bool = false
var _pending_first_steps: Array[Vector2i] = []
var _pending_parents: Dictionary = {}
var _context = null

func bind_from_context(context) -> void:
	## Single wiring entry so hosts don't re-declare the same Callables.
	_context = context
	battle_state_fn = func(): return context.battle_state()
	tile_visu_fn = func(coords: Vector2i) -> TileVisu: return context.tile_visu_at(coords)
	is_locked_fn = func() -> bool: return context.is_input_locked()
	can_act_fn = func(legion: Legion) -> bool: return context.can_act_legion(legion)
	apply_action_fn = func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
		context.apply_action(action_id, from_coords, to_coords)
	apply_move_path_fn = func(path: Array) -> void: context.apply_move_path(path)
	battle_phase_fn = func() -> bool: return context.in_battle_phase()
	allows_spawn_fn = func(coords: Vector2i) -> bool: return context.allows_spawn(coords)
	spawn_fn = func(coords: Vector2i) -> void: context.spawn_at(coords)
	turn_manager_fn = func() -> TurnManager: return context.turn_manager()
	legions_fn = func() -> Array: return context.legions()
	_inspect_fn = func(coords: Vector2i) -> void: context.inspect_tile(coords)
	_clear_inspect_fn = func() -> void: context.clear_inspect()
	if context.overlay_ui_fn.is_valid():
		overlay_ui_fn = context.overlay_ui_fn

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
	_hide_attack_choice_popup()
	_clear_overlay_visuals()
	has_selected = false
	selected_action = null
	target_coords.clear()
	default_target_actions.clear()
	_pending_move_active = false
	_pending_first_steps.clear()
	_pending_parents.clear()
	_info_visible_for_tile = false
	_clear_inspect_fn.call()
	if action_bar:
		action_bar.clear_bar()

func select_tile(coords: Vector2i) -> void:
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		return
	var legion: Legion = _legion_at(state, coords)
	if legion == null or not bool(can_act_fn.call(legion)):
		return
	_hide_attack_choice_popup()
	_clear_overlay_visuals()
	has_selected = true
	selected_coords = coords
	selected_action = null
	target_coords.clear()
	default_target_actions.clear()
	_paint_tile(coords, "selected", LIFT_SELECTED)
	_paint_default_targets(state, legion)
	_info_tile_coords = coords
	_info_visible_for_tile = true
	_inspect_fn.call(coords)
	if action_bar:
		if action_bar.has_method("set_tooltip_context_legion"):
			action_bar.set_tooltip_context_legion(legion)
		_refresh_action_bar(state, legion, null)

func select_action(action: ActionDefinitionScript) -> void:
	if not has_selected:
		return
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		return
	var legion: Legion = _legion_at(state, selected_coords)
	if legion == null:
		return
	_hide_attack_choice_popup()
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
	if action.id == "move":
		var reach := MoveReachabilityScript.compute(state, legion)
		target_coords = reach["reachable"]
	else:
		target_coords = ActionTargetingScript.get_targets(state, legion, action)
	default_target_actions.clear()
	if action_bar:
		action_bar.set_selected(action)
	if action.targeting == ActionDefinitionScript.TargetingKind.SELF:
		_paint_tile(selected_coords, action.overlay_state, LIFT_OPTION)
	else:
		_paint_tile(selected_coords, "selected", LIFT_SELECTED)
		_paint_action_targets(action)

func _refresh_action_bar(
	state: BattleStateScript,
	legion: Legion,
	selected: ActionDefinitionScript
) -> void:
	if action_bar == null:
		return
	var listed := ActionTargetingScript.listed_actions(legion)
	var reasons: Dictionary = {}
	for action in listed:
		var reason := ActionTargetingScript.disable_reason(state, legion, action)
		if not reason.is_empty():
			reasons[action.id] = reason
	action_bar.set_actions(listed, selected, reasons)

func refresh_after_action(legion_coords: Vector2i) -> void:
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		deselect()
		_sync_spent_visuals()
		return
	var legion: Legion = _legion_at(state, legion_coords)
	if legion and bool(can_act_fn.call(legion)):
		select_tile(legion_coords)
	else:
		deselect()
	_sync_spent_visuals()

func clear_overlays() -> void:
	_clear_overlay_visuals()
	_sync_spent_visuals()

func _sync_spent_visuals() -> void:
	if _context == null or _context.presenter == null or _context.session == null:
		return
	_context.presenter.sync_spent_visuals(_context.session)

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
	var state: BattleStateScript = battle_state_fn.call()
	if state:
		var legion: Legion = _legion_at(state, coords)
		if legion:
			AudioManager.play_unit_click(legion.unit_type)

func pass_current_legion() -> void:
	if not can_accept_command():
		return
	if has_selected:
		var tm: TurnManager = turn_manager_fn.call()
		tm.wait_legion(selected_coords)
		deselect()
		_sync_spent_visuals()
	cycle_legion_tab()

func _on_action_bar_pressed(action: ActionDefinitionScript) -> void:
	if not can_accept_command() or not has_selected:
		return
	var state: BattleStateScript = battle_state_fn.call()
	var legion: Legion = _legion_at(state, selected_coords) if state else null
	if legion:
		AudioManager.play_unit_click(legion.unit_type)
	else:
		AudioManager.play_sfx("tile_click")
	select_action(action)

func _on_tile_clicked(coords: Vector2i) -> void:
	if not battle_phase_fn.is_valid() or not bool(battle_phase_fn.call()):
		return
	if not can_accept_command():
		return
	_play_click_sound_for_tile(coords)
	_dispatch_click(coords)

func _play_click_sound_for_tile(coords: Vector2i) -> void:
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		AudioManager.play_sfx("tile_click")
		return
	var legion: Legion = _legion_at(state, coords)
	if legion:
		AudioManager.play_unit_click(legion.unit_type)
	else:
		AudioManager.play_sfx("tile_click")

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
	if coords in _overlay_coords:
		var tile_visu: TileVisu = tile_visu_fn.call(coords)
		if tile_visu:
			tile_visu.set_hover_boost(false)
	if has_selected:
		var selected_visu: TileVisu = tile_visu_fn.call(selected_coords)
		if selected_visu and selected_visu.legion_visu:
			selected_visu.legion_visu.juice_direct_reset()

func _dispatch_click(coords: Vector2i) -> void:
	if _attack_choice_popup != null and is_instance_valid(_attack_choice_popup):
		_hide_attack_choice_popup()
		return

	if _pending_move_active:
		if coords in _pending_first_steps:
			var path: Array[Vector2i] = MoveReachabilityScript.path_after_first_step(
				selected_coords, _pending_move_dest, coords, _pending_parents
			)
			_pending_move_active = false
			_execute_move_path(path)
		return

	if has_selected and selected_action:
		var is_self_target := (
			selected_action.targeting == ActionDefinitionScript.TargetingKind.SELF
			and coords == selected_coords
		)
		if coords in target_coords or is_self_target:
			if selected_action.id == "move":
				_try_move_to(coords)
			else:
				apply_action_fn.call(selected_action.id, selected_coords, coords)
			return
		return
	if has_selected and default_target_actions.has(coords):
		var actions: Array = default_target_actions[coords]
		var attack_ids: Array[String] = attack_ids_from_actions(actions)
		if attack_ids.size() >= 2:
			_show_attack_choice_popup(coords, attack_ids)
			return
		if not actions.is_empty():
			var aid := String(actions[0])
			if aid == "move":
				_try_move_to(coords)
			else:
				apply_action_fn.call(aid, selected_coords, coords)
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

func _try_move_to(dest: Vector2i) -> void:
	var state: BattleStateScript = battle_state_fn.call()
	if state == null:
		return
	var legion: Legion = _legion_at(state, selected_coords)
	if legion == null:
		return
	var analysis := MoveReachabilityScript.analyze_destination(state, legion, dest)
	if not analysis.get("ok", false):
		apply_action_fn.call("move", selected_coords, dest)
		return
	if bool(analysis.get("ambiguous", false)):
		_pending_move_active = true
		_pending_move_dest = dest
		_pending_first_steps = analysis["first_steps"]
		_pending_parents = MoveReachabilityScript.compute(state, legion)["parents"]
		_clear_overlay_visuals()
		_paint_tile(selected_coords, "selected", LIFT_SELECTED)
		for step in _pending_first_steps:
			_paint_tile(step, "movable", LIFT_OPTION)
		return
	_execute_move_path(analysis["path"])

func _execute_move_path(path: Array) -> void:
	if path.size() < 2:
		return
	if apply_move_path_fn.is_valid():
		apply_move_path_fn.call(path)
		return
	# Fallback: only first step if no path runner (should not happen in minigame).
	apply_action_fn.call("move", path[0], path[1])

func _paint_default_targets(state: BattleStateScript, legion: Legion) -> void:
	default_target_actions.clear()
	for action_id in DEFAULT_HIGHLIGHT_ACTION_IDS:
		var action: ActionDefinitionScript = ActionDefs.get_def(action_id)
		if action == null or not ActionTargetingScript.can_use(state, legion, action):
			continue
		var targets: Array[Vector2i] = ActionTargetingScript.get_targets(state, legion, action)
		if action_id == "move":
			var reach := MoveReachabilityScript.compute(state, legion)
			targets = reach["reachable"]
		for c in targets:
			if c == selected_coords:
				continue
			if not default_target_actions.has(c):
				default_target_actions[c] = []
			var list: Array = default_target_actions[c]
			if action_id not in list:
				list.append(action_id)
			default_target_actions[c] = list

	for c in default_target_actions.keys():
		_paint_tile(c, _overlay_for_default_actions(default_target_actions[c]), LIFT_OPTION)

func _overlay_for_default_actions(action_ids: Array) -> String:
	return overlay_state_for_default_actions(action_ids)

## Pure helper — which overlay to paint for default multi-action highlights.
static func overlay_state_for_default_actions(action_ids: Array) -> String:
	var has_melee := "melee_attack" in action_ids
	var has_ranged := "ranged_attack" in action_ids
	if has_melee and has_ranged:
		return "attack_choice"
	if has_ranged:
		return "ranged_attackable"
	if has_melee:
		return "attackable"
	var first := String(action_ids[0]) if not action_ids.is_empty() else "movable"
	var def: ActionDefinitionScript = ActionDefs.get_def(first)
	return def.overlay_state if def else "movable"

## Pure helper — attack action ids among default target actions for a tile.
static func attack_ids_from_actions(actions: Array) -> Array[String]:
	var attack_ids: Array[String] = []
	for action_id in actions:
		var id := String(action_id)
		if id == "melee_attack" or id == "ranged_attack":
			attack_ids.append(id)
	return attack_ids

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

func _show_attack_choice_popup(to_coords: Vector2i, attack_ids: Array[String]) -> void:
	_hide_attack_choice_popup()
	if not overlay_ui_fn.is_valid():
		apply_action_fn.call(attack_ids[0], selected_coords, to_coords)
		return

	var parent: Node = overlay_ui_fn.call()
	if parent == null:
		apply_action_fn.call(attack_ids[0], selected_coords, to_coords)
		return

	var root := Control.new()
	root.name = "AttackChoicePopup"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hide_attack_choice_popup()
			root.accept_event()
	)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_POPUP_BG
	sb.border_color = COLOR_POPUP_BORDER
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Choose attack"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_POPUP_TEXT)
	title.add_theme_font_size_override("font_size", 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	for action_id in attack_ids:
		var def: ActionDefinitionScript = ActionDefs.get_def(action_id)
		var btn := _make_attack_icon_button(def.icon if def else null)
		var chosen := action_id
		btn.pressed.connect(func() -> void:
			_hide_attack_choice_popup()
			apply_action_fn.call(chosen, selected_coords, to_coords)
		)
		row.add_child(btn)

	parent.add_child(root)
	_attack_choice_popup = root

func _make_attack_icon_button(icon: Texture2D) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = ICON_BTN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if icon:
		btn.icon = icon
	UiTheme.apply_button_chrome(btn, 12, 3, 14, 14)
	return btn

func _hide_attack_choice_popup() -> void:
	if _attack_choice_popup != null and is_instance_valid(_attack_choice_popup):
		_attack_choice_popup.queue_free()
	_attack_choice_popup = null

func _legion_at(state: BattleStateScript, coords: Vector2i) -> Legion:
	var tile: Tile = state.tile_at(coords)
	return tile.legion if tile and tile.has_legion() else null
