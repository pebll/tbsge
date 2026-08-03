extends Control

const DEV_TEST_SCENE := "res://scenes/runnables/dev_test_menu.tscn"
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

enum View { MAIN, SOUNDS, OPTIONS }

const COLOR_BG := UiTheme.COLOR_PANEL
const COLOR_BORDER := UiTheme.COLOR_BORDER
const COLOR_TEXT := UiTheme.COLOR_TEXT
const BORDER_THICK := UiTheme.BORDER_THICK
const RADIUS := UiTheme.RADIUS

@onready var dev_test_button: GameButton = %DevTestButton
@onready var sounds_button: GameButton = %SoundsButton
@onready var options_button: GameButton = %OptionsButton
@onready var back_button: GameButton = %BackButton
@onready var options_back_button: GameButton = %OptionsBackButton
@onready var main_buttons: VBoxContainer = %MainButtons
@onready var sounds_panel: VBoxContainer = %SoundsPanel
@onready var options_panel: VBoxContainer = %OptionsPanel
@onready var menu_sound_slider: HSlider = %MenuSoundSlider
@onready var game_sound_slider: HSlider = %GameSoundSlider
@onready var music_sound_slider: HSlider = %MusicSoundSlider
@onready var show_moves_check: CheckBox = %ShowMovesCheck
@onready var show_end_turns_check: CheckBox = %ShowEndTurnsCheck

var _view: View = View.MAIN

func _ready() -> void:
	AudioManager.ensure_music()
	_apply_styles()
	_sync_sliders_from_audio()
	_sync_options_from_settings()
	dev_test_button.pressed.connect(_on_dev_test_pressed)
	sounds_button.pressed.connect(_on_sounds_pressed)
	options_button.pressed.connect(_on_options_pressed)
	back_button.pressed.connect(_on_back_pressed)
	options_back_button.pressed.connect(_on_back_pressed)
	menu_sound_slider.value_changed.connect(_on_menu_volume_changed)
	game_sound_slider.value_changed.connect(_on_game_volume_changed)
	music_sound_slider.value_changed.connect(_on_music_volume_changed)
	show_moves_check.toggled.connect(_on_show_moves_toggled)
	show_end_turns_check.toggled.connect(_on_show_end_turns_toggled)
	_show_view(View.MAIN)

func _apply_styles() -> void:
	%MenuPanel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(COLOR_BG, COLOR_BORDER, RADIUS, BORDER_THICK, 28)
	)

	var title := %TitleLabel
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 42)

	for panel in [sounds_panel, options_panel]:
		for child in panel.get_children():
			if child is VBoxContainer:
				for row_child in child.get_children():
					if row_child is Label:
						row_child.add_theme_color_override("font_color", COLOR_TEXT)
						row_child.add_theme_font_size_override("font_size", 18)
			elif child is Label:
				child.add_theme_color_override("font_color", COLOR_TEXT)
				child.add_theme_font_size_override("font_size", 20)

	UiTheme.apply_checkbox_chrome(show_moves_check)
	UiTheme.apply_checkbox_chrome(show_end_turns_check)
	show_moves_check.add_theme_font_size_override("font_size", 20)
	show_end_turns_check.add_theme_font_size_override("font_size", 20)

func _sync_sliders_from_audio() -> void:
	menu_sound_slider.set_value_no_signal(AudioManager.menu_volume)
	game_sound_slider.set_value_no_signal(AudioManager.game_volume)
	music_sound_slider.set_value_no_signal(AudioManager.music_volume)

func _sync_options_from_settings() -> void:
	show_moves_check.set_pressed_no_signal(GameSettings.show_battle_log_moves)
	show_end_turns_check.set_pressed_no_signal(GameSettings.show_battle_log_end_turns)

func _show_view(view: View) -> void:
	_view = view
	main_buttons.visible = view == View.MAIN
	sounds_panel.visible = view == View.SOUNDS
	options_panel.visible = view == View.OPTIONS
	var active: Control = main_buttons
	match view:
		View.SOUNDS:
			active = sounds_panel
		View.OPTIONS:
			active = options_panel
		_:
			active = main_buttons
	UiTheme.juice_pop_in(active, 0.12)

func _on_dev_test_pressed() -> void:
	get_tree().change_scene_to_file(DEV_TEST_SCENE)

func _on_sounds_pressed() -> void:
	_sync_sliders_from_audio()
	_show_view(View.SOUNDS)

func _on_options_pressed() -> void:
	_sync_options_from_settings()
	_show_view(View.OPTIONS)

func _on_back_pressed() -> void:
	_show_view(View.MAIN)

func _on_menu_volume_changed(value: float) -> void:
	AudioManager.set_menu_volume(value)

func _on_game_volume_changed(value: float) -> void:
	AudioManager.set_game_volume(value)

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_show_moves_toggled(pressed: bool) -> void:
	GameSettings.set_show_battle_log_moves(pressed)

func _on_show_end_turns_toggled(pressed: bool) -> void:
	GameSettings.set_show_battle_log_end_turns(pressed)
