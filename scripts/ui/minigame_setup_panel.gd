class_name MinigameSetupPanel
extends Control

signal ready_pressed

@onready var gold_panel: PanelContainer = %GoldPanel
@onready var team_label: Label = %TeamLabel
@onready var gold_value: Label = %GoldValue
@onready var gold_total: Label = %GoldTotal
@onready var ready_button: Button = %ReadyButton

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_BLOCK_BG := Color(0.93, 0.89, 0.82)
const BORDER_THICK := 4
const RADIUS := 16

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()
	ready_button.pressed.connect(func(): ready_pressed.emit())

func _apply_style() -> void:
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
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	gold_panel.add_theme_stylebox_override("panel", sb)

	for label in [team_label, gold_value, gold_total]:
		label.add_theme_color_override("font_color", COLOR_TEXT)

	ready_button.text = "Ready for battle"
	ready_button.custom_minimum_size = Vector2(360, 72)
	ready_button.add_theme_font_size_override("font_size", 30)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = COLOR_BLOCK_BG
	btn_sb.border_color = COLOR_BORDER
	btn_sb.border_width_left = BORDER_THICK
	btn_sb.border_width_right = BORDER_THICK
	btn_sb.border_width_top = BORDER_THICK
	btn_sb.border_width_bottom = BORDER_THICK
	btn_sb.corner_radius_top_left = RADIUS
	btn_sb.corner_radius_top_right = RADIUS
	btn_sb.corner_radius_bottom_left = RADIUS
	btn_sb.corner_radius_bottom_right = RADIUS
	btn_sb.content_margin_top = 14
	btn_sb.content_margin_bottom = 14
	ready_button.add_theme_stylebox_override("normal", btn_sb)
	ready_button.add_theme_stylebox_override("hover", btn_sb)
	ready_button.add_theme_stylebox_override("pressed", btn_sb)
	ready_button.add_theme_color_override("font_color", COLOR_TEXT)

func show_for_team(team_id: String, draft_data: Dictionary) -> void:
	_apply_team_accent(team_id)
	var remaining := int(draft_data.get("remaining_budget", 0))
	var budget_total := int(draft_data.get("budget_total", 0))
	gold_value.text = "%d" % remaining
	gold_total.text = "/ %d gold left" % budget_total
	show()

func _apply_team_accent(team_id: String) -> void:
	var team_res: Resource = TeamDefs.get_def(team_id)
	var label_text: String = team_id
	if team_res is TeamDefinition:
		label_text = (team_res as TeamDefinition).display_name
	team_label.text = "%s" % label_text
