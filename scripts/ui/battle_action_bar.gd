class_name BattleActionBar
extends Control

const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")

signal action_pressed(action: ActionDefinitionScript)

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_MUTED := Color(0.45, 0.40, 0.35)
const BORDER_THICK := 4
const RADIUS := 16

var _buttons: Dictionary = {}
var _selected_id: String = ""
var _tooltip: TooltipController = null
var _tooltip_legion: Legion = null
var _disabled_reasons: Dictionary = {}

@onready var _row: HBoxContainer = %ActionRow
@onready var _hint: Label = %HintLabel

func _ready() -> void:
	_apply_panel_style()
	if _hint:
		_hint.add_theme_color_override("font_color", COLOR_MUTED)
		_hint.hide()
	hide()

func set_tooltip_controller(controller: TooltipController) -> void:
	_tooltip = controller

func set_tooltip_context_legion(legion: Legion) -> void:
	_tooltip_legion = legion

func _apply_panel_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = BORDER_THICK
	sb.border_width_right = BORDER_THICK
	sb.border_width_top = BORDER_THICK
	sb.border_width_bottom = BORDER_THICK
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	%Panel.add_theme_stylebox_override("panel", sb)

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
		hide()
		return
	for action in actions:
		_add_action_button(action)
	if selected:
		set_hint(_hint_for_action(selected))
	else:
		set_hint("")
	show()

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
	_clear_buttons()
	_selected_id = ""
	_disabled_reasons.clear()
	set_hint("")
	hide()

func _clear_buttons() -> void:
	for child in _row.get_children():
		child.queue_free()
	_buttons.clear()

func _add_action_button(action: ActionDefinitionScript) -> void:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = action.id == _selected_id
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(96, 96)
	var reason := String(_disabled_reasons.get(action.id, ""))
	var disabled := not reason.is_empty()
	btn.disabled = disabled
	if disabled:
		btn.tooltip_text = "%s — %s" % [action.display_name, reason]
	else:
		btn.tooltip_text = "%s — right-click to inspect" % action.display_name

	var sb_normal := _button_stylebox(Color(0.93, 0.89, 0.82))
	var sb_hover := _button_stylebox(Color(0.95, 0.91, 0.84))
	var sb_pressed := _button_stylebox(Color(0.88, 0.83, 0.74))
	var sb_disabled := _button_stylebox(Color(0.82, 0.78, 0.72))
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	btn.modulate = Color(1, 1, 1, 0.55) if disabled else Color.WHITE

	if action.icon:
		btn.icon = action.icon
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.text = ""
	else:
		btn.text = action.display_name.substr(0, 1)

	var captured_action: ActionDefinitionScript = action
	var captured_reason := reason
	if not disabled:
		btn.pressed.connect(func(): action_pressed.emit(captured_action))
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if _tooltip:
				var content := TooltipContent.for_action(captured_action, _tooltip_legion)
				if not captured_reason.is_empty():
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

func _button_stylebox(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COLOR_BORDER
	sb.border_width_left = BORDER_THICK
	sb.border_width_right = BORDER_THICK
	sb.border_width_top = BORDER_THICK
	sb.border_width_bottom = BORDER_THICK
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb
