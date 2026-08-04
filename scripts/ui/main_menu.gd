extends Control

const DEV_TEST_SCENE := "res://scenes/runnables/dev_test_menu.tscn"
const MINIGAME_SCENE := "res://scenes/runnables/minigame.tscn"
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

enum View { MAIN, SETUP, SOUNDS, OPTIONS }

const MENU_BTN_WIDTH := 360

@onready var play_button: GameButton = %PlayButton
@onready var dev_test_button: GameButton = %DevTestButton
@onready var sounds_button: GameButton = %SoundsButton
@onready var options_button: GameButton = %OptionsButton
@onready var quit_button: GameButton = %QuitButton
@onready var main_buttons: VBoxContainer = %MainButtons
@onready var setup_panel: GameSetupPanel = %SetupPanel
@onready var sounds_panel: SoundsSettingsPanel = %SoundsPanel
@onready var options_panel: OptionsSettingsPanel = %OptionsPanel

var _view: View = View.MAIN

func _ready() -> void:
	GameSettings.clear_match_launch()
	AudioManager.ensure_music()
	_apply_styles()
	play_button.pressed.connect(_on_play_pressed)
	dev_test_button.pressed.connect(_on_dev_test_pressed)
	sounds_button.pressed.connect(_on_sounds_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	setup_panel.back_pressed.connect(_on_back_pressed)
	setup_panel.start_pressed.connect(_on_setup_start_pressed)
	sounds_panel.back_pressed.connect(_on_back_pressed)
	options_panel.back_pressed.connect(_on_back_pressed)
	_show_view(View.MAIN)

func _apply_styles() -> void:
	%MenuPanel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, UiTheme.RADIUS, UiTheme.BORDER_THICK, 24)
	)

	var title := %TitleLabel
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 42)

	for btn in [play_button, dev_test_button, sounds_button, options_button, quit_button]:
		btn.preferred_width = MENU_BTN_WIDTH

	main_buttons.add_theme_constant_override("separation", 16)

func _show_view(view: View) -> void:
	_view = view
	main_buttons.visible = view == View.MAIN
	setup_panel.visible = view == View.SETUP
	sounds_panel.visible = view == View.SOUNDS
	options_panel.visible = view == View.OPTIONS
	var active: Control = main_buttons
	match view:
		View.SETUP:
			active = setup_panel
		View.SOUNDS:
			active = sounds_panel
		View.OPTIONS:
			active = options_panel
		_:
			active = main_buttons
	UiTheme.juice_pop_in(active, 0.12)

func _on_play_pressed() -> void:
	setup_panel.sync_from_settings()
	_show_view(View.SETUP)

func _on_setup_start_pressed() -> void:
	GameSettings.begin_match_launch()
	get_tree().change_scene_to_file(MINIGAME_SCENE)

func _on_dev_test_pressed() -> void:
	get_tree().change_scene_to_file(DEV_TEST_SCENE)

func _on_sounds_pressed() -> void:
	sounds_panel.sync_from_audio()
	_show_view(View.SOUNDS)

func _on_options_pressed() -> void:
	options_panel.sync_from_settings()
	_show_view(View.OPTIONS)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	_show_view(View.MAIN)
