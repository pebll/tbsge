class_name OptionsSettingsPanel
extends VBoxContainer

## Reusable Options view: battle-log / AI toggles + Back. Used by main menu and pause.

signal back_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameButtonScene = preload("res://scenes/ui/game_button.tscn")

const MENU_BTN_WIDTH := 360

var _moves_btn: GameButton
var _end_turns_btn: GameButton
var _ai_debug_btn: GameButton
var _hp_style_btn: GameButton
var _back_btn: GameButton

func _ready() -> void:
	if get_child_count() == 0:
		_build()
	_apply_styles()
	_connect_signals()
	sync_from_settings()

func sync_from_settings() -> void:
	if _moves_btn == null:
		return
	_moves_btn.text = _on_off_label("Show moves", GameSettings.show_battle_log_moves)
	_end_turns_btn.text = _on_off_label("Show turn starts", GameSettings.show_battle_log_end_turns)
	_ai_debug_btn.text = _on_off_label("AI debug", GameSettings.is_ai_debug_enabled())
	_hp_style_btn.text = _hp_style_label()

func _build() -> void:
	add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_moves_btn = _make_button("Show moves: OFF")
	_end_turns_btn = _make_button("Show turn starts: OFF")
	_ai_debug_btn = _make_button("AI debug: OFF")
	_hp_style_btn = _make_button("Strip HP: A")
	_back_btn = _make_button("Back")

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
			child.add_theme_font_size_override("font_size", 22)
	for btn in [_moves_btn, _end_turns_btn, _ai_debug_btn, _hp_style_btn, _back_btn]:
		if btn:
			btn.preferred_width = MENU_BTN_WIDTH

func _connect_signals() -> void:
	if not _moves_btn.pressed.is_connected(_on_moves):
		_moves_btn.pressed.connect(_on_moves)
	if not _end_turns_btn.pressed.is_connected(_on_end_turns):
		_end_turns_btn.pressed.connect(_on_end_turns)
	if not _ai_debug_btn.pressed.is_connected(_on_ai_debug):
		_ai_debug_btn.pressed.connect(_on_ai_debug)
	if not _hp_style_btn.pressed.is_connected(_on_hp_style):
		_hp_style_btn.pressed.connect(_on_hp_style)
	if not _back_btn.pressed.is_connected(_on_back):
		_back_btn.pressed.connect(_on_back)

func _on_off_label(prefix: String, on: bool) -> String:
	return "%s: %s" % [prefix, "ON" if on else "OFF"]

func _hp_style_label() -> String:
	return "Strip HP: %s" % ("B (edge)" if GameSettings.legion_strip_hp_style == 1 else "A (fill)")

func _on_moves() -> void:
	GameSettings.set_show_battle_log_moves(not GameSettings.show_battle_log_moves)
	sync_from_settings()

func _on_end_turns() -> void:
	GameSettings.set_show_battle_log_end_turns(not GameSettings.show_battle_log_end_turns)
	sync_from_settings()

func _on_ai_debug() -> void:
	GameSettings.toggle_ai_debug()
	sync_from_settings()

func _on_hp_style() -> void:
	GameSettings.toggle_legion_strip_hp_style()
	sync_from_settings()

func _on_back() -> void:
	back_pressed.emit()
