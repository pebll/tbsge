class_name TurnHud
extends PanelContainer

signal next_turn_pressed

@onready var team_header: PanelContainer = %TurnTeamHeader
@onready var team_label: Label = %TurnTeamLabel
@onready var team_footer: PanelContainer = %TurnTeamFooter
@onready var next_turn_button: GameButton = %NextTurnButton
@onready var status_label: Label = %TurnStatusLabel

var _done_pulse: Tween

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

func _ready() -> void:
	_apply_panel_style()
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
	status_label.add_theme_color_override("font_color", Color(0.36, 0.30, 0.24))

func show_active_team(team_id: String) -> void:
	var team_res: Resource = TeamDefs.get_def(team_id)
	var accent: Color = COLOR_BORDER
	var label_text: String = GameSettings.display_name_for_team(team_id) if not team_id.is_empty() else "—"
	if team_res is TeamDefinition:
		accent = (team_res as TeamDefinition).color

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

## "Turn 3 · 2 of 4 legions ready". When nothing can act, the End turn button pulses.
func set_turn_status(turn_no: int, ready: int, total: int, is_human: bool) -> void:
	var parts := PackedStringArray(["Turn %d" % turn_no])
	if is_human and total > 0:
		parts.append("%d of %d legions ready" % [ready, total] if ready > 0 else "All legions done")
	elif not is_human:
		parts.append("thinking…")
	status_label.text = " · ".join(parts)
	_set_done_pulse(is_human and total > 0 and ready == 0)

func _set_done_pulse(on: bool) -> void:
	if _done_pulse and _done_pulse.is_valid():
		_done_pulse.kill()
		_done_pulse = null
	next_turn_button.modulate = Color.WHITE
	if not on:
		return
	_done_pulse = next_turn_button.create_tween().set_loops()
	_done_pulse.tween_property(next_turn_button, "modulate", Color(1.15, 1.1, 0.75), 0.55)\
		.set_trans(Tween.TRANS_SINE)
	_done_pulse.tween_property(next_turn_button, "modulate", Color.WHITE, 0.55)\
		.set_trans(Tween.TRANS_SINE)
