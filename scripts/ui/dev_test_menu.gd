extends Control

const SANDBOX_SCENE := "res://scenes/runnables/unit_preview.tscn"
const DUEL_R3_SCENE := "res://scenes/runnables/minigame.tscn"

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

@onready var sandbox_button: Button = %SandboxButton
@onready var duel_button: Button = %DuelButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	_apply_styles()
	sandbox_button.pressed.connect(func(): get_tree().change_scene_to_file(SANDBOX_SCENE))
	duel_button.pressed.connect(func(): get_tree().change_scene_to_file(DUEL_R3_SCENE))
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/runnables/menu.tscn"))

func _apply_styles() -> void:
	var panel_sb := _make_stylebox()
	%MenuPanel.add_theme_stylebox_override("panel", panel_sb)
	%TitleLabel.add_theme_color_override("font_color", COLOR_TEXT)
	%TitleLabel.add_theme_font_size_override("font_size", 36)
	for btn in [sandbox_button, duel_button, back_button]:
		_style_button(btn)

func _style_button(btn: Button) -> void:
	var sb := _make_stylebox(Color(0.93, 0.89, 0.82))
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", 24)

func _make_stylebox(bg: Color = COLOR_BG) -> StyleBoxFlat:
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
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb
