class_name GameOverPanel
extends Control

signal new_game_pressed
signal main_menu_pressed

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_BACKDROP := Color(0.05, 0.04, 0.03, 0.72)
const BORDER_THICK := 4
const RADIUS := 18

@onready var title_label: Label = %TitleLabel
@onready var winner_header: PanelContainer = %WinnerHeader
@onready var winner_label: Label = %WinnerLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_game_button: GameButton = %NewGameButton
@onready var main_menu_button: GameButton = %MainMenuButton

func _ready() -> void:
	_apply_style()
	new_game_button.text = "Draft again"
	main_menu_button.text = "Main menu"
	new_game_button.pressed.connect(func(): new_game_pressed.emit())
	main_menu_button.pressed.connect(func(): main_menu_pressed.emit())
	hide()

func _apply_style() -> void:
	%Backdrop.color = COLOR_BACKDROP

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
	panel_sb.content_margin_top = 24
	panel_sb.content_margin_bottom = 24
	%Panel.add_theme_stylebox_override("panel", panel_sb)

	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 44)
	subtitle_label.add_theme_color_override("font_color", COLOR_TEXT)
	subtitle_label.add_theme_font_size_override("font_size", 22)
	winner_label.add_theme_font_size_override("font_size", 34)

func show_for_winner(winner_team_id: String) -> void:
	var display_name := GameSettings.display_name_for_team(winner_team_id)
	var accent := COLOR_BORDER
	var team_res: Resource = TeamDefs.get_def(winner_team_id)
	if team_res is TeamDefinition:
		accent = (team_res as TeamDefinition).color

	var ai_vs_ai := GameSettings.is_match_launch_active() and GameSettings.is_ai_vs_ai_mode()
	var defeat := (
		GameSettings.is_match_launch_active()
		and not GameSettings.is_hotseat_mode()
		and not ai_vs_ai
		and winner_team_id == "BLUE"
	)
	if ai_vs_ai:
		title_label.text = "%s wins!" % display_name
	else:
		title_label.text = "Defeat" if defeat else "Victory!"
	subtitle_label.text = "Draft again, or return to the main menu."
	winner_label.text = "%s wins" % display_name
	winner_label.add_theme_color_override("font_color", _contrasting_text_color(accent))

	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = accent
	header_sb.corner_radius_top_left = RADIUS
	header_sb.corner_radius_top_right = RADIUS
	header_sb.corner_radius_bottom_left = RADIUS
	header_sb.corner_radius_bottom_right = RADIUS
	header_sb.content_margin_left = 18
	header_sb.content_margin_right = 18
	header_sb.content_margin_top = 12
	header_sb.content_margin_bottom = 12
	winner_header.add_theme_stylebox_override("panel", header_sb)

	show()

func _contrasting_text_color(bg: Color) -> Color:
	return Color.WHITE if bg.get_luminance() < 0.45 else COLOR_TEXT
