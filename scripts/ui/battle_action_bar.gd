class_name BattleActionBar
extends Control

const ActionDefinitionScript = preload("res://scripts/actions/action_definition.gd")

signal action_pressed(action: ActionDefinitionScript)

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

var _buttons: Dictionary = {}
var _selected_id: String = ""

@onready var _row: HBoxContainer = %ActionRow

func _ready() -> void:
	_apply_panel_style()
	hide()

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

func set_actions(actions: Array[ActionDefinitionScript], selected: ActionDefinitionScript = null) -> void:
	_clear_buttons()
	_selected_id = selected.id if selected else ""
	if actions.is_empty():
		hide()
		return
	for action in actions:
		_add_action_button(action)
	show()

func set_selected(action: ActionDefinitionScript) -> void:
	_selected_id = action.id if action else ""
	for action_id in _buttons.keys():
		var btn: Button = _buttons[action_id]
		var is_pressed: bool = action_id == _selected_id
		btn.button_pressed = is_pressed

func clear_bar() -> void:
	_clear_buttons()
	_selected_id = ""
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
	btn.tooltip_text = "%s (%d AP)" % [action.display_name, action.ap_cost]

	var sb_normal := _button_stylebox(Color(0.93, 0.89, 0.82))
	var sb_hover := _button_stylebox(Color(0.95, 0.91, 0.84))
	var sb_pressed := _button_stylebox(Color(0.88, 0.83, 0.74))
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color", COLOR_TEXT)

	if action.icon:
		btn.icon = action.icon
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.text = ""
	else:
		btn.text = action.display_name.substr(0, 1)

	btn.pressed.connect(func(): action_pressed.emit(action))
	_row.add_child(btn)
	_buttons[action.id] = btn

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
