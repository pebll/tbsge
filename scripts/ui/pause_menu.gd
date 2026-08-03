class_name PauseMenu
extends Control

## ESC overlay: resume, abandon, options toggles, and sound sliders.

signal resume_pressed
signal abandon_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameButtonScene = preload("res://scenes/ui/game_button.tscn")

const COLOR_BACKDROP := Color(0.05, 0.04, 0.03, 0.72)
const PANEL_WIDTH := 420.0

var _panel: PanelContainer
var _title: Label
var _resume_btn: GameButton
var _abandon_btn: GameButton
var _moves_btn: GameButton
var _end_turns_btn: GameButton
var _ai_debug_btn: GameButton
var _menu_slider: HSlider
var _game_slider: HSlider
var _music_slider: HSlider

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()

func open_menu() -> void:
	_sync_from_settings()
	show()
	UiTheme.juice_pop_in(_panel, 0.14)

func close_menu() -> void:
	hide()

func is_open() -> bool:
	return visible

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, UiTheme.RADIUS, UiTheme.BORDER_THICK, 24)
	)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.text = "Paused"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	_title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(_title)

	_resume_btn = _make_menu_button("Resume", vbox)
	_resume_btn.pressed.connect(func() -> void: resume_pressed.emit())

	_abandon_btn = _make_menu_button("Abandon game", vbox)
	_abandon_btn.pressed.connect(func() -> void: abandon_pressed.emit())

	vbox.add_child(_section_label("Options"))
	_moves_btn = _make_menu_button("Show moves: OFF", vbox)
	_moves_btn.pressed.connect(_on_moves_pressed)
	_end_turns_btn = _make_menu_button("Show end turns: OFF", vbox)
	_end_turns_btn.pressed.connect(_on_end_turns_pressed)
	_ai_debug_btn = _make_menu_button("AI debug: OFF", vbox)
	_ai_debug_btn.pressed.connect(_on_ai_debug_pressed)

	vbox.add_child(_section_label("Sounds"))
	_menu_slider = _add_slider_row(vbox, "Menu sounds")
	_game_slider = _add_slider_row(vbox, "In-game sounds")
	_music_slider = _add_slider_row(vbox, "Music")
	_menu_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_menu_volume(v))
	_game_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_game_volume(v))
	_music_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_music_volume(v))

func _make_menu_button(text: String, parent: Control) -> GameButton:
	var btn: GameButton = GameButtonScene.instantiate()
	btn.text = text
	btn.preferred_width = 360
	parent.add_child(btn)
	return btn

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	label.add_theme_font_size_override("font_size", 22)
	return label

func _add_slider_row(parent: Control, label_text: String) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(360, 0)
	slider.max_value = 1.0
	slider.step = 0.01
	row.add_child(slider)
	return slider

func _sync_from_settings() -> void:
	_refresh_toggle_labels()
	_menu_slider.set_value_no_signal(AudioManager.menu_volume)
	_game_slider.set_value_no_signal(AudioManager.game_volume)
	_music_slider.set_value_no_signal(AudioManager.music_volume)

func _refresh_toggle_labels() -> void:
	_moves_btn.text = _on_off_label("Show moves", GameSettings.show_battle_log_moves)
	_end_turns_btn.text = _on_off_label("Show end turns", GameSettings.show_battle_log_end_turns)
	_ai_debug_btn.text = _on_off_label("AI debug", GameSettings.is_ai_debug_enabled())

func _on_off_label(prefix: String, on: bool) -> String:
	return "%s: %s" % [prefix, "ON" if on else "OFF"]

func _on_moves_pressed() -> void:
	GameSettings.set_show_battle_log_moves(not GameSettings.show_battle_log_moves)
	_refresh_toggle_labels()

func _on_end_turns_pressed() -> void:
	GameSettings.set_show_battle_log_end_turns(not GameSettings.show_battle_log_end_turns)
	_refresh_toggle_labels()

func _on_ai_debug_pressed() -> void:
	GameSettings.toggle_ai_debug()
	_refresh_toggle_labels()
