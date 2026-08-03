class_name SoundsSettingsPanel
extends VBoxContainer

## Reusable Sounds view: three volume sliders + Back. Used by main menu and pause.

signal back_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameButtonScene = preload("res://scenes/ui/game_button.tscn")

const MENU_BTN_WIDTH := 360

var _menu_slider: HSlider
var _game_slider: HSlider
var _music_slider: HSlider
var _back_btn: GameButton

func _ready() -> void:
	if get_child_count() == 0:
		_build()
	_apply_styles()
	_connect_signals()
	sync_from_audio()

func sync_from_audio() -> void:
	if _menu_slider == null:
		return
	_menu_slider.set_value_no_signal(AudioManager.menu_volume)
	_game_slider.set_value_no_signal(AudioManager.game_volume)
	_music_slider.set_value_no_signal(AudioManager.music_volume)

func _build() -> void:
	add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "Sounds"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_menu_slider = _add_slider_row("Menu sounds")
	_game_slider = _add_slider_row("In-game sounds")
	_music_slider = _add_slider_row("Music")

	_back_btn = GameButtonScene.instantiate()
	_back_btn.name = "BackButton"
	_back_btn.text = "Back"
	_back_btn.preferred_width = MENU_BTN_WIDTH
	add_child(_back_btn)

func _add_slider_row(label_text: String) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(MENU_BTN_WIDTH, 0)
	slider.max_value = 1.0
	slider.step = 0.01
	row.add_child(slider)
	return slider

func _apply_styles() -> void:
	add_theme_constant_override("separation", 16)
	for child in get_children():
		if child is VBoxContainer:
			for row_child in child.get_children():
				if row_child is Label:
					row_child.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
					row_child.add_theme_font_size_override("font_size", 18)
		elif child is Label:
			child.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
			child.add_theme_font_size_override("font_size", 22)
	if _back_btn:
		_back_btn.preferred_width = MENU_BTN_WIDTH

func _connect_signals() -> void:
	if not _menu_slider.value_changed.is_connected(_on_menu_volume):
		_menu_slider.value_changed.connect(_on_menu_volume)
	if not _game_slider.value_changed.is_connected(_on_game_volume):
		_game_slider.value_changed.connect(_on_game_volume)
	if not _music_slider.value_changed.is_connected(_on_music_volume):
		_music_slider.value_changed.connect(_on_music_volume)
	if not _back_btn.pressed.is_connected(_on_back):
		_back_btn.pressed.connect(_on_back)

func _on_menu_volume(value: float) -> void:
	AudioManager.set_menu_volume(value)

func _on_game_volume(value: float) -> void:
	AudioManager.set_game_volume(value)

func _on_music_volume(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_back() -> void:
	back_pressed.emit()
