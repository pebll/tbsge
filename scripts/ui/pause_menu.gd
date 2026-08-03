class_name PauseMenu
extends Control

## Fullscreen pause: Resume / Abandon / Sounds / Options. Sounds+Options reuse shared panels.

signal resume_pressed
signal abandon_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameButtonScene = preload("res://scenes/ui/game_button.tscn")
const SoundsPanelScene = preload("res://scenes/ui/sounds_settings_panel.tscn")
const OptionsPanelScene = preload("res://scenes/ui/options_settings_panel.tscn")

const MENU_BTN_WIDTH := 360

enum View { MAIN, SOUNDS, OPTIONS }

var _panel: PanelContainer
var _content: VBoxContainer
var _main_buttons: VBoxContainer
var _sounds_panel: SoundsSettingsPanel
var _options_panel: OptionsSettingsPanel
var _view: View = View.MAIN

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()

func open_menu() -> void:
	_show_view(View.MAIN)
	show()
	UiTheme.juice_pop_in(_content, 0.14)

func close_menu() -> void:
	hide()

func is_open() -> bool:
	return visible

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, UiTheme.RADIUS, UiTheme.BORDER_THICK, 24)
	)
	add_child(_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(center)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 20)
	center.add_child(_content)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 42)
	_content.add_child(title)

	_main_buttons = VBoxContainer.new()
	_main_buttons.add_theme_constant_override("separation", 16)
	_content.add_child(_main_buttons)

	var resume_btn := _make_menu_button("Resume")
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	_main_buttons.add_child(resume_btn)

	var abandon_btn := _make_menu_button("Abandon game")
	abandon_btn.pressed.connect(func() -> void: abandon_pressed.emit())
	_main_buttons.add_child(abandon_btn)

	var sounds_btn := _make_menu_button("Sounds")
	sounds_btn.pressed.connect(_on_sounds_pressed)
	_main_buttons.add_child(sounds_btn)

	var options_btn := _make_menu_button("Options")
	options_btn.pressed.connect(_on_options_pressed)
	_main_buttons.add_child(options_btn)

	_sounds_panel = SoundsPanelScene.instantiate()
	_sounds_panel.visible = false
	_sounds_panel.back_pressed.connect(_on_back_pressed)
	_content.add_child(_sounds_panel)

	_options_panel = OptionsPanelScene.instantiate()
	_options_panel.visible = false
	_options_panel.back_pressed.connect(_on_back_pressed)
	_content.add_child(_options_panel)

func _make_menu_button(text: String) -> GameButton:
	var btn: GameButton = GameButtonScene.instantiate()
	btn.text = text
	btn.preferred_width = MENU_BTN_WIDTH
	return btn

func _show_view(view: View) -> void:
	_view = view
	_main_buttons.visible = view == View.MAIN
	_sounds_panel.visible = view == View.SOUNDS
	_options_panel.visible = view == View.OPTIONS
	var active: Control = _main_buttons
	match view:
		View.SOUNDS:
			active = _sounds_panel
		View.OPTIONS:
			active = _options_panel
		_:
			active = _main_buttons
	UiTheme.juice_pop_in(active, 0.12)

func _on_sounds_pressed() -> void:
	_sounds_panel.sync_from_audio()
	_show_view(View.SOUNDS)

func _on_options_pressed() -> void:
	_options_panel.sync_from_settings()
	_show_view(View.OPTIONS)

func _on_back_pressed() -> void:
	_show_view(View.MAIN)
