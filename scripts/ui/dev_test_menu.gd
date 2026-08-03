extends Control

const SANDBOX_SCENE := "res://scenes/runnables/unit_preview.tscn"
const DUEL_R3_SCENE := "res://scenes/runnables/minigame.tscn"
const DUEL_R4_SCENE := "res://scenes/runnables/minigame_duel_r4.tscn"
const BIG_R4_SCENE := "res://scenes/runnables/minigame_big.tscn"

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const COLOR_BG := UiTheme.COLOR_PANEL
const COLOR_BORDER := UiTheme.COLOR_BORDER
const COLOR_TEXT := UiTheme.COLOR_TEXT
const BORDER_THICK := UiTheme.BORDER_THICK
const RADIUS := UiTheme.RADIUS

@onready var sandbox_button: GameButton = %SandboxButton
@onready var duel_button: GameButton = %DuelButton
@onready var duel_r4_button: GameButton = %DuelR4Button
@onready var big_button: GameButton = %BigButton
@onready var back_button: GameButton = %BackButton

func _ready() -> void:
	AudioManager.ensure_music()
	_apply_styles()
	sandbox_button.pressed.connect(func(): get_tree().change_scene_to_file(SANDBOX_SCENE))
	duel_button.pressed.connect(func(): get_tree().change_scene_to_file(DUEL_R3_SCENE))
	duel_r4_button.pressed.connect(func(): get_tree().change_scene_to_file(DUEL_R4_SCENE))
	big_button.pressed.connect(func(): get_tree().change_scene_to_file(BIG_R4_SCENE))
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/runnables/menu.tscn"))

func _apply_styles() -> void:
	%MenuPanel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(COLOR_BG, COLOR_BORDER, RADIUS, BORDER_THICK, 24)
	)
	%TitleLabel.add_theme_color_override("font_color", COLOR_TEXT)
	%TitleLabel.add_theme_font_size_override("font_size", 36)
