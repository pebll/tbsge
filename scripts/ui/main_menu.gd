extends Control

const DEV_TEST_SCENE := "res://scenes/runnables/dev_test_menu.tscn"

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

@onready var dev_test_button: GameButton = %DevTestButton

func _ready() -> void:
	_apply_styles()
	dev_test_button.pressed.connect(_on_dev_test_pressed)

func _apply_styles() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = COLOR_BG
	panel_sb.border_color = COLOR_BORDER
	panel_sb.border_width_left = BORDER_THICK
	panel_sb.border_width_right = BORDER_THICK
	panel_sb.border_width_top = BORDER_THICK
	panel_sb.border_width_bottom = BORDER_THICK
	panel_sb.corner_radius_top_left = RADIUS
	panel_sb.corner_radius_top_right = RADIUS
	panel_sb.corner_radius_bottom_left = RADIUS
	panel_sb.corner_radius_bottom_right = RADIUS
	panel_sb.content_margin_left = 28
	panel_sb.content_margin_right = 28
	panel_sb.content_margin_top = 28
	panel_sb.content_margin_bottom = 28
	%MenuPanel.add_theme_stylebox_override("panel", panel_sb)

	var title := %TitleLabel
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 42)

func _on_dev_test_pressed() -> void:
	get_tree().change_scene_to_file(DEV_TEST_SCENE)
