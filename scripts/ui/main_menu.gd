extends Control

const DEV_TEST_SCENE := "res://scenes/runnables/dev_test_menu.tscn"

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

@onready var dev_test_button: GameButton = %DevTestButton
@onready var sounds_button: GameButton = %SoundsButton
@onready var back_button: GameButton = %BackButton
@onready var main_buttons: VBoxContainer = %MainButtons
@onready var sounds_panel: VBoxContainer = %SoundsPanel
@onready var menu_sound_slider: HSlider = %MenuSoundSlider
@onready var game_sound_slider: HSlider = %GameSoundSlider
@onready var music_sound_slider: HSlider = %MusicSoundSlider

func _ready() -> void:
	AudioManager.ensure_music()
	_apply_styles()
	_sync_sliders_from_audio()
	dev_test_button.pressed.connect(_on_dev_test_pressed)
	sounds_button.pressed.connect(_on_sounds_pressed)
	back_button.pressed.connect(_on_back_pressed)
	menu_sound_slider.value_changed.connect(_on_menu_volume_changed)
	game_sound_slider.value_changed.connect(_on_game_volume_changed)
	music_sound_slider.value_changed.connect(_on_music_volume_changed)

func _apply_styles() -> void:
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
	panel_sb.content_margin_top = 28
	panel_sb.content_margin_bottom = 28
	%MenuPanel.add_theme_stylebox_override("panel", panel_sb)

	var title := %TitleLabel
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 42)

	for child in sounds_panel.get_children():
		if child is VBoxContainer:
			for row_child in child.get_children():
				if row_child is Label:
					row_child.add_theme_color_override("font_color", COLOR_TEXT)
					row_child.add_theme_font_size_override("font_size", 18)

func _sync_sliders_from_audio() -> void:
	menu_sound_slider.set_value_no_signal(AudioManager.menu_volume)
	game_sound_slider.set_value_no_signal(AudioManager.game_volume)
	music_sound_slider.set_value_no_signal(AudioManager.music_volume)

func _show_sounds(show_sounds: bool) -> void:
	main_buttons.visible = not show_sounds
	sounds_panel.visible = show_sounds

func _on_dev_test_pressed() -> void:
	get_tree().change_scene_to_file(DEV_TEST_SCENE)

func _on_sounds_pressed() -> void:
	_sync_sliders_from_audio()
	_show_sounds(true)

func _on_back_pressed() -> void:
	_show_sounds(false)

func _on_menu_volume_changed(value: float) -> void:
	AudioManager.set_menu_volume(value)

func _on_game_volume_changed(value: float) -> void:
	AudioManager.set_game_volume(value)

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
