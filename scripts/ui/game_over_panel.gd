class_name GameOverPanel
extends Control

signal new_game_pressed
signal main_menu_pressed

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_MUTED := Color(0.35, 0.30, 0.24)
const COLOR_BACKDROP := Color(0.05, 0.04, 0.03, 0.72)
const BORDER_THICK := 4
const RADIUS := 18
const ICON_COIN := preload("res://assets/icons/base_icons_sprites/coin.png")

@onready var title_label: Label = %TitleLabel
@onready var winner_header: PanelContainer = %WinnerHeader
@onready var winner_label: Label = %WinnerLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var report_box: VBoxContainer = %ReportBox
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
	%Panel.custom_minimum_size = Vector2(640, 0)

	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 44)
	subtitle_label.add_theme_color_override("font_color", COLOR_TEXT)
	subtitle_label.add_theme_font_size_override("font_size", 22)
	winner_label.add_theme_font_size_override("font_size", 34)

func show_for_winner(winner_team_id: String, report: Dictionary = {}) -> void:
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

	_populate_report(report)
	show()

func _populate_report(report: Dictionary) -> void:
	for child in report_box.get_children():
		child.queue_free()

	if report.is_empty() or not report.has("by_type"):
		subtitle_label.text = "Draft again, or return to the main menu."
		subtitle_label.show()
		report_box.hide()
		return

	subtitle_label.hide()
	report_box.show()

	var green_name := GameSettings.display_name_for_team("GREEN")
	var blue_name := GameSettings.display_name_for_team("BLUE")

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.add_child(_side_header(green_name, "GREEN", true))
	header.add_child(_center_spacer())
	header.add_child(_side_header(blue_name, "BLUE", false))
	report_box.add_child(header)

	for row in report.get("by_type", []):
		if not (row is Dictionary):
			continue
		report_box.add_child(_loss_row(row))

	report_box.add_child(_make_divider())

	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	gold_row.add_child(_gold_cell(int(report.get("green_gold_lost", 0)), true))
	gold_row.add_child(_center_label("Lost value"))
	gold_row.add_child(_gold_cell(int(report.get("blue_gold_lost", 0)), false))
	report_box.add_child(gold_row)

	var wiped_g := int(report.get("wiped_green", 0))
	var wiped_b := int(report.get("wiped_blue", 0))
	if wiped_g > 0 or wiped_b > 0:
		var wiped := Label.new()
		wiped.text = "Wiped stacks  %d · %d" % [wiped_g, wiped_b]
		wiped.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wiped.add_theme_color_override("font_color", COLOR_MUTED)
		wiped.add_theme_font_size_override("font_size", 18)
		report_box.add_child(wiped)

	var mvp: Dictionary = report.get("mvp", {})
	if not mvp.is_empty():
		report_box.add_child(_make_divider())
		report_box.add_child(_mvp_block(mvp))

func _side_header(text: String, team_id: String, align_left: bool) -> Control:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_RIGHT
	)
	label.add_theme_font_size_override("font_size", 20)
	var accent := COLOR_TEXT
	var team_res: Resource = TeamDefs.get_def(team_id)
	if team_res is TeamDefinition:
		accent = (team_res as TeamDefinition).color
	label.add_theme_color_override("font_color", accent)
	return label

func _center_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	return spacer

func _center_label(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(120, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 18)
	return label

func _loss_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)

	var g_start := int(row.get("green_start", 0))
	var b_start := int(row.get("blue_start", 0))
	line.add_child(_loss_cell(
		g_start,
		int(row.get("green_lost", 0)),
		true
	))

	var mid := HBoxContainer.new()
	mid.custom_minimum_size = Vector2(120, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var def: UnitDefinition = UnitDefs.get_def(String(row.get("unit_type", "")))
	if def != null:
		icon.texture = def.icon
	mid.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = String(row.get("display_name", row.get("unit_type", "")))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 18)
	mid.add_child(name_lbl)
	line.add_child(mid)

	line.add_child(_loss_cell(
		b_start,
		int(row.get("blue_lost", 0)),
		false
	))
	return line

func _loss_cell(started: int, lost: int, align_left: bool) -> Control:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_RIGHT
	)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	if started <= 0:
		label.text = "—"
		label.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		label.text = "%d/%d" % [lost, started]
	return label

func _gold_cell(amount: int, align_left: bool) -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = (
		BoxContainer.ALIGNMENT_BEGIN if align_left else BoxContainer.ALIGNMENT_END
	)
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_font_size_override("font_size", 22)
	var icon := TextureRect.new()
	icon.texture = ICON_COIN
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if align_left:
		box.add_child(label)
		box.add_child(icon)
	else:
		box.add_child(icon)
		box.add_child(label)
	return box

func _mvp_block(mvp: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "MVP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_MUTED)
	title.add_theme_font_size_override("font_size", 16)
	block.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var def: UnitDefinition = UnitDefs.get_def(String(mvp.get("unit_type", "")))
	if def != null:
		icon.texture = def.icon
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 2)
	var name_lbl := Label.new()
	var team := String(mvp.get("team", ""))
	name_lbl.text = "%s · %s" % [
		String(mvp.get("display_name", "")),
		GameSettings.display_name_for_team(team),
	]
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 22)
	text_col.add_child(name_lbl)

	var stats := Label.new()
	stats.text = "Dealt %d   Taken %d" % [
		int(round(float(mvp.get("damage_dealt", 0.0)))),
		int(round(float(mvp.get("damage_received", 0.0)))),
	]
	stats.add_theme_color_override("font_color", COLOR_MUTED)
	stats.add_theme_font_size_override("font_size", 18)
	text_col.add_child(stats)
	row.add_child(text_col)
	block.add_child(row)
	return block

func _make_divider() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = COLOR_BORDER
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line

func _contrasting_text_color(bg: Color) -> Color:
	return Color.WHITE if bg.get_luminance() < 0.45 else COLOR_TEXT
