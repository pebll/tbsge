class_name BattleActionBar
extends Control

const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

signal action_pressed(action: ActionDefinitionScript)

const COLOR_TEXT := UiTheme.COLOR_TEXT
const COLOR_MUTED := UiTheme.COLOR_TEXT_MUTED
const BORDER_THICK := UiTheme.BORDER_THICK
const RADIUS := UiTheme.RADIUS

var _buttons: Dictionary = {}
var _selected_id: String = ""
var _tooltip: TooltipController = null
var _tooltip_legion: Legion = null
var _disabled_reasons: Dictionary = {}
var _panel: PanelContainer
var _visibility_tween: Tween
var _showing: bool = false
## When true: show actions for inspect only (no press, always "enabled" look, tooltips work).
var _display_only: bool = false

@onready var _row: HBoxContainer = %ActionRow
@onready var _hint: Label = %HintLabel

func _ready() -> void:
	_panel = %Panel
	_apply_panel_style()
	if _hint:
		_hint.add_theme_color_override("font_color", COLOR_MUTED)
		_hint.hide()
	pivot_offset = size * 0.5
	hide()
	modulate.a = 0.0
	scale = Vector2(0.92, 0.82)

func set_tooltip_controller(controller: TooltipController) -> void:
	_tooltip = controller

func set_tooltip_context_legion(legion: Legion) -> void:
	_tooltip_legion = legion

func set_display_only(enabled: bool) -> void:
	_display_only = enabled
	if _hint:
		_hint.visible = false

## Re-anchor for embedding inside another panel (inspect UI), not screen-bottom HUD.
func configure_embedded() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _hint:
		_hint.hide()

func _apply_panel_style() -> void:
	%Panel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, RADIUS, BORDER_THICK, 10)
	)

func set_actions(
	actions: Array[ActionDefinitionScript],
	selected: ActionDefinitionScript = null,
	disabled_reasons: Dictionary = {}
) -> void:
	_clear_buttons()
	_disabled_reasons = disabled_reasons.duplicate()
	_selected_id = selected.id if selected else ""
	if actions.is_empty():
		set_hint("")
		_animate_hide()
		return
	for action in actions:
		_add_action_button(action)
	if _display_only:
		set_hint("")
	elif selected:
		set_hint(_hint_for_action(selected))
	else:
		set_hint("")
	_animate_show()
	_juice_buttons_in()

func set_selected(action: ActionDefinitionScript) -> void:
	_selected_id = action.id if action else ""
	for action_id in _buttons.keys():
		var btn: Button = _buttons[action_id]
		var is_pressed: bool = action_id == _selected_id
		btn.button_pressed = is_pressed
	set_hint(_hint_for_action(action) if action else "")

func set_hint(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_hint.visible = not text.is_empty()

func clear_bar() -> void:
	_selected_id = ""
	_disabled_reasons.clear()
	set_hint("")
	_animate_hide()
	_clear_buttons()

func _clear_buttons() -> void:
	for child in _row.get_children():
		child.queue_free()
	_buttons.clear()

func _add_action_button(action: ActionDefinitionScript) -> void:
	var btn := Button.new()
	btn.toggle_mode = not _display_only
	btn.button_pressed = (not _display_only) and action.id == _selected_id
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(96, 96)
	var reason := String(_disabled_reasons.get(action.id, ""))
	var disabled := (not _display_only) and not reason.is_empty()
	btn.disabled = disabled
	# Display-only: look enabled, ignore activation, keep right-click tooltips.
	if _display_only:
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1)
		btn.mouse_default_cursor_shape = Control.CURSOR_HELP
		btn.tooltip_text = "%s — right-click to inspect" % action.display_name
	elif disabled:
		btn.tooltip_text = "%s — %s" % [action.display_name, reason]
	else:
		btn.tooltip_text = "%s — right-click to inspect" % action.display_name

	UiTheme.apply_button_chrome(btn, RADIUS, BORDER_THICK, 10, 10)
	if not _display_only:
		btn.modulate = Color(1, 1, 1, 0.55) if disabled else Color(1, 1, 1, 1)

	if action.icon:
		btn.icon = action.icon
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.text = ""
	else:
		btn.text = action.display_name.substr(0, 1)
		btn.add_theme_color_override("font_color", COLOR_TEXT)

	var captured_action: ActionDefinitionScript = action
	var captured_reason := reason
	if not _display_only and not disabled:
		btn.pressed.connect(func():
			UiTheme.juice_press(btn)
			action_pressed.emit(captured_action)
		)
	elif _display_only:
		btn.pressed.connect(func() -> void:
			btn.button_pressed = false
		)
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if _tooltip:
				var content := TooltipContent.for_action(captured_action, _tooltip_legion)
				if not _display_only and not captured_reason.is_empty():
					content.body = "%s\n\nUnavailable: %s" % [content.body, captured_reason]
				_tooltip.show_for_control(btn, content)
			btn.accept_event()
	)
	_row.add_child(btn)
	_maybe_add_cooldown_badge(btn, action)
	_buttons[action.id] = btn

func _maybe_add_cooldown_badge(btn: Button, action: ActionDefinitionScript) -> void:
	if _tooltip_legion == null or action == null:
		return
	var rem := _tooltip_legion.get_cooldown_remaining(action.id)
	if rem <= 0:
		return
	var badge := Label.new()
	badge.text = str(rem)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	badge.add_theme_font_size_override("font_size", 18)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.offset_left = -36
	holder.offset_top = -32
	holder.offset_right = -4
	holder.offset_bottom = -4
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.28, 0.18, 0.12, 0.95)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	holder.add_theme_stylebox_override("panel", sb)
	holder.add_child(badge)
	btn.add_child(holder)

func _animate_show() -> void:
	_showing = true
	show()
	pivot_offset = Vector2(size.x * 0.5, size.y)
	if _visibility_tween and _visibility_tween.is_running():
		_visibility_tween.kill()
	_visibility_tween = UiTheme.juice_pop_in(self, 0.15)

func _animate_hide() -> void:
	if not visible and not _showing:
		hide()
		return
	_showing = false
	pivot_offset = Vector2(size.x * 0.5, size.y)
	if _visibility_tween and _visibility_tween.is_running():
		_visibility_tween.kill()
	_visibility_tween = UiTheme.juice_pop_out(self, 0.1)
	if _visibility_tween:
		_visibility_tween.finished.connect(func() -> void:
			if not _showing:
				hide()
				scale = Vector2(0.92, 0.82)
				modulate.a = 0.0
		, CONNECT_ONE_SHOT)

func _juice_buttons_in() -> void:
	# Defer one frame so button sizes are valid for pivot.
	await get_tree().process_frame
	var delay := 0.0
	for action_id in _buttons.keys():
		var btn: Button = _buttons[action_id]
		if btn == null or not is_instance_valid(btn):
			continue
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2(0.82, 0.72)
		btn.modulate.a = 0.0
		var tween := btn.create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(delay)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.12)
		tween.parallel().tween_property(btn, "modulate:a", 1.0 if not btn.disabled else 0.55, 0.1)
		delay += 0.03

func _hint_for_action(action: ActionDefinitionScript) -> String:
	if action == null:
		return ""
	if not action.select_hint.is_empty():
		return action.select_hint
	match action.targeting:
		ActionDefinitionScript.TargetingKind.SELF:
			return "Confirm to heal this legion"
		ActionDefinitionScript.TargetingKind.ADJACENT_MOVE:
			return "Choose an adjacent hex"
		ActionDefinitionScript.TargetingKind.ADJACENT_ENEMY:
			return "Choose an adjacent enemy"
		ActionDefinitionScript.TargetingKind.ENEMY_IN_RANGE:
			return "Choose an enemy in range"
		ActionDefinitionScript.TargetingKind.ALLY_IN_RANGE:
			return "Choose a wounded ally"
		ActionDefinitionScript.TargetingKind.EMPTY_IN_RANGE:
			return "Choose an empty tile in range"
		_:
			return "Choose a target"
