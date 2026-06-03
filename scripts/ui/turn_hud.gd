class_name TurnHud
extends PanelContainer

signal next_turn_pressed

@onready var team_header: PanelContainer = %TurnTeamHeader
@onready var team_label: Label = %TurnTeamLabel
@onready var team_footer: PanelContainer = %TurnTeamFooter
@onready var next_turn_button: Button = %NextTurnButton

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

func _ready() -> void:
	_apply_panel_style()
	next_turn_button.focus_mode = Control.FOCUS_NONE
	next_turn_button.pressed.connect(func(): next_turn_pressed.emit())
	show_active_team("")

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
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sb)

	team_label.add_theme_color_override("font_color", COLOR_TEXT)

func show_active_team(team_id: String) -> void:
	var team_res: Resource = TeamDefs.get_def(team_id)
	var accent: Color = COLOR_BORDER
	var label_text: String = team_id if not team_id.is_empty() else "—"
	if team_res is TeamDefinition:
		var team: TeamDefinition = team_res
		accent = team.color
		label_text = team.display_name

	team_label.text = "%s's turn" % label_text
	team_label.add_theme_color_override("font_color", _contrasting_text_color(accent))

	var header_sb := _accent_stylebox(accent)
	header_sb.content_margin_left = 12
	header_sb.content_margin_right = 12
	header_sb.content_margin_top = 8
	header_sb.content_margin_bottom = 8
	team_header.add_theme_stylebox_override("panel", header_sb)

	var footer_sb := _accent_stylebox(accent)
	footer_sb.corner_radius_top_left = 8
	footer_sb.corner_radius_top_right = 8
	footer_sb.corner_radius_bottom_left = 8
	footer_sb.corner_radius_bottom_right = 8
	team_footer.add_theme_stylebox_override("panel", footer_sb)

func _accent_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	return sb

func _contrasting_text_color(bg: Color) -> Color:
	return Color.WHITE if bg.get_luminance() < 0.45 else COLOR_TEXT
