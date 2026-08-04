class_name GameSetupPanel
extends VBoxContainer

## Play setup: map size + difficulty, then Start / Back.

signal back_pressed
signal start_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameButtonScene = preload("res://scenes/ui/game_button.tscn")
const SegmentOptionRowScript = preload("res://scripts/ui/segment_option_row.gd")

const MENU_BTN_WIDTH := 360

var _map_row: SegmentOptionRow
var _diff_row: SegmentOptionRow
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
	_map_row.set_selected(str(GameSettings.match_map_size), false)
	_diff_row.set_selected(GameSettings.match_difficulty, false)
	_refresh_summary()

func _build() -> void:
	add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.name = "Title"
	title.text = "New Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

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
	for btn in [_start_btn, _back_btn]:
		if btn:
			btn.preferred_width = MENU_BTN_WIDTH

func _connect_signals() -> void:
	if _map_row and not _map_row.selection_changed.is_connected(_on_map_changed):
		_map_row.selection_changed.connect(_on_map_changed)
	if _diff_row and not _diff_row.selection_changed.is_connected(_on_diff_changed):
		_diff_row.selection_changed.connect(_on_diff_changed)
	if _start_btn and not _start_btn.pressed.is_connected(_on_start):
		_start_btn.pressed.connect(_on_start)
	if _back_btn and not _back_btn.pressed.is_connected(_on_back):
		_back_btn.pressed.connect(_on_back)

func _on_map_changed(id: String) -> void:
	GameSettings.set_match_map_size(int(id))
	_refresh_summary()

func _on_diff_changed(id: String) -> void:
	GameSettings.set_match_difficulty(id)
	_refresh_summary()

func _refresh_summary() -> void:
	if _summary == null:
		return
	var gold := GameSettings.player_budget_for_map_size()
	var mult := GameSettings.ai_budget_mult_for_difficulty()
	var enemy_gold := int(round(float(gold) * mult))
	var diff_label := String(GameSettings.DIFFICULTY_LABELS.get(GameSettings.match_difficulty, "Normal"))
	_summary.text = "You: %d gold · Enemy (%s): %d gold" % [gold, diff_label, enemy_gold]

func _on_start() -> void:
	start_pressed.emit()

func _on_back() -> void:
	back_pressed.emit()
