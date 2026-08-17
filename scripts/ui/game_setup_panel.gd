class_name GameSetupPanel
extends VBoxContainer

## Play setup: mode, names, map size + difficulty, then Start / Back.

signal back_pressed
signal start_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameButtonScene = preload("res://scenes/ui/game_button.tscn")
const SegmentOptionRowScript = preload("res://scripts/ui/segment_option_row.gd")

const MENU_BTN_WIDTH := 360

var _mode_row: SegmentOptionRow
var _map_row: SegmentOptionRow
var _diff_row: SegmentOptionRow
var _name_label: Label
var _name_edit: LineEdit
var _p2_label: Label
var _p2_edit: LineEdit
var _summary: Label
var _start_btn: GameButton
var _back_btn: GameButton

func _ready() -> void:
	if get_child_count() == 0:
		_build()
	_apply_styles()
	_connect_signals()
	sync_from_settings()

func sync_from_settings() -> void:
	if _map_row == null:
		return
	_mode_row.set_selected(GameSettings.match_mode, false)
	_map_row.set_selected(str(GameSettings.match_map_size), false)
	_diff_row.set_selected(GameSettings.match_difficulty, false)
	_name_edit.text = GameSettings.player_name
	_p2_edit.text = GameSettings.player2_name
	_refresh_mode_visibility()
	_refresh_summary()

func _build() -> void:
	add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.name = "Title"
	title.text = "New Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_mode_row = SegmentOptionRowScript.new()
	_mode_row.name = "ModeRow"
	_mode_row.configure_buttons(0, 18, 46)
	add_child(_mode_row)
	_mode_row.setup("Mode", _mode_options(), GameSettings.match_mode)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = "Your name"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_name_edit = _make_name_edit("NameEdit", GameSettings.player_name)
	add_child(_name_edit)

	_p2_label = Label.new()
	_p2_label.name = "P2Label"
	_p2_label.text = "Player 2 name"
	_p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_p2_label)

	_p2_edit = _make_name_edit("P2Edit", GameSettings.player2_name)
	add_child(_p2_edit)

	_map_row = SegmentOptionRowScript.new()
	_map_row.name = "MapSizeRow"
	_map_row.configure_buttons(88, 20, 46)
	add_child(_map_row)
	_map_row.setup("Map size", _map_options(), str(GameSettings.match_map_size))

	_diff_row = SegmentOptionRowScript.new()
	_diff_row.name = "DifficultyRow"
	_diff_row.configure_buttons(0, 18, 46)
	add_child(_diff_row)
	_diff_row.setup("Difficulty", _difficulty_options(), GameSettings.match_difficulty)

	_summary = Label.new()
	_summary.name = "Summary"
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(MENU_BTN_WIDTH, 0)
	add_child(_summary)

	_start_btn = _make_button("Start")
	_back_btn = _make_button("Back")

func _mode_options() -> Array:
	return [
		{
			"id": GameSettings.MATCH_MODE_AI,
			"text": "Vs AI",
			"tooltip": "You draft and fight against the computer.",
			"width": 120,
		},
		{
			"id": GameSettings.MATCH_MODE_HOTSEAT,
			"text": "Hotseat",
			"tooltip": "Two humans on one device. Pass the controls between turns.",
			"width": 120,
		},
		{
			"id": GameSettings.MATCH_MODE_AI_VS_AI,
			"text": "AI vs AI",
			"tooltip": "Watch two AIs battle it out. Sit back and enjoy!",
			"width": 120,
		},
	]

func _map_options() -> Array:
	return [
		{
			"id": "3",
			"text": "3",
			"tooltip": "Small hex map (radius 3).\nYour starting gold: 75.",
		},
		{
			"id": "4",
			"text": "4",
			"tooltip": "Medium hex map (radius 4).\nYour starting gold: 125.",
		},
		{
			"id": "5",
			"text": "5",
			"tooltip": "Large hex map (radius 5).\nYour starting gold: 200.",
		},
	]

func _difficulty_options() -> Array:
	return [
		{
			"id": "easy",
			"text": "Easy",
			"tooltip": "Enemy starting gold is 75% of yours.",
			"width": 96,
		},
		{
			"id": "normal",
			"text": "Normal",
			"tooltip": "Enemy starting gold matches yours.",
			"width": 110,
		},
		{
			"id": "hard",
			"text": "Hard",
			"tooltip": "Enemy starting gold is 150% of yours.",
			"width": 96,
		},
		{
			"id": "impossible",
			"text": "Impossible",
			"tooltip": "Enemy starting gold is 200% of yours.",
			"width": 140,
		},
	]

func _make_name_edit(node_name: String, text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = node_name
	edit.text = text
	edit.max_length = 24
	edit.custom_minimum_size = Vector2(MENU_BTN_WIDTH, 44)
	edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.placeholder_text = "Name"
	return edit

func _make_button(text: String) -> GameButton:
	var btn: GameButton = GameButtonScene.instantiate()
	btn.text = text
	btn.preferred_width = MENU_BTN_WIDTH
	add_child(btn)
	return btn

func _apply_styles() -> void:
	add_theme_constant_override("separation", 16)
	for child in get_children():
		if child is Label:
			child.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
			if child.name == "Title":
				child.add_theme_font_size_override("font_size", 22)
			elif child.name == "Summary":
				child.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_MUTED)
				child.add_theme_font_size_override("font_size", 16)
			else:
				child.add_theme_font_size_override("font_size", 18)
	for edit in [_name_edit, _p2_edit]:
		if edit == null:
			continue
		edit.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
		edit.add_theme_color_override("font_placeholder_color", UiTheme.COLOR_TEXT_MUTED)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.COLOR_CARD
		sb.border_color = UiTheme.COLOR_BORDER
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		edit.add_theme_stylebox_override("normal", sb)
		edit.add_theme_stylebox_override("focus", sb)
	for btn in [_start_btn, _back_btn]:
		if btn:
			btn.preferred_width = MENU_BTN_WIDTH

func _connect_signals() -> void:
	if _mode_row and not _mode_row.selection_changed.is_connected(_on_mode_changed):
		_mode_row.selection_changed.connect(_on_mode_changed)
	if _map_row and not _map_row.selection_changed.is_connected(_on_map_changed):
		_map_row.selection_changed.connect(_on_map_changed)
	if _diff_row and not _diff_row.selection_changed.is_connected(_on_diff_changed):
		_diff_row.selection_changed.connect(_on_diff_changed)
	if _name_edit and not _name_edit.text_changed.is_connected(_on_name_changed):
		_name_edit.text_changed.connect(_on_name_changed)
	if _p2_edit and not _p2_edit.text_changed.is_connected(_on_p2_changed):
		_p2_edit.text_changed.connect(_on_p2_changed)
	if _start_btn and not _start_btn.pressed.is_connected(_on_start):
		_start_btn.pressed.connect(_on_start)
	if _back_btn and not _back_btn.pressed.is_connected(_on_back):
		_back_btn.pressed.connect(_on_back)

func _on_mode_changed(id: String) -> void:
	GameSettings.set_match_mode(id)
	_refresh_mode_visibility()
	_refresh_summary()

func _on_map_changed(id: String) -> void:
	GameSettings.set_match_map_size(int(id))
	_refresh_summary()

func _on_diff_changed(id: String) -> void:
	GameSettings.set_match_difficulty(id)
	_refresh_summary()

func _on_name_changed(new_text: String) -> void:
	GameSettings.set_player_name(new_text)
	_refresh_summary()

func _on_p2_changed(new_text: String) -> void:
	GameSettings.set_player2_name(new_text)
	_refresh_summary()

func _refresh_mode_visibility() -> void:
	var hotseat := GameSettings.is_hotseat_mode()
	var ai_vs_ai := GameSettings.is_ai_vs_ai_mode()
	if _diff_row:
		_diff_row.visible = not hotseat and not ai_vs_ai
	if _name_label:
		_name_label.visible = not ai_vs_ai
	if _name_edit:
		_name_edit.visible = not ai_vs_ai
	if _p2_label:
		_p2_label.visible = hotseat
	if _p2_edit:
		_p2_edit.visible = hotseat

func _refresh_summary() -> void:
	if _summary == null:
		return
	var gold := GameSettings.player_budget_for_map_size()
	var p1 := GameSettings.player_name
	if GameSettings.is_ai_vs_ai_mode():
		_summary.text = "AI vs AI · %d gold each" % gold
		return
	if GameSettings.is_hotseat_mode():
		var p2 := GameSettings.player2_name
		_summary.text = "%s: %d gold · %s: %d gold (hotseat)" % [p1, gold, p2, gold]
		return
	var mult := GameSettings.ai_budget_mult_for_difficulty()
	var enemy_gold := int(round(float(gold) * mult))
	var diff_label := String(GameSettings.DIFFICULTY_LABELS.get(GameSettings.match_difficulty, "Normal"))
	_summary.text = "%s: %d gold · Enemy (%s): %d gold" % [p1, gold, diff_label, enemy_gold]

func _on_start() -> void:
	var p1 := _name_edit.text if _name_edit else GameSettings.player_name
	var p2 := _p2_edit.text if _p2_edit else GameSettings.player2_name
	GameSettings.commit_player_names(p1, p2)
	start_pressed.emit()

func _on_back() -> void:
	back_pressed.emit()
