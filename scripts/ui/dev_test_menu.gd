extends Control

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")

const SANDBOX_SCENE := "res://scenes/runnables/unit_preview.tscn"
const DUEL_R3_SCENE := "res://scenes/runnables/minigame.tscn"
const DUEL_R4_SCENE := "res://scenes/runnables/minigame_duel_r4.tscn"
const BIG_R4_SCENE := "res://scenes/runnables/minigame_big.tscn"

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

@onready var sandbox_button: GameButton = %SandboxButton
@onready var duel_button: GameButton = %DuelButton
@onready var duel_r4_button: GameButton = %DuelR4Button
@onready var big_button: GameButton = %BigButton
@onready var back_button: GameButton = %BackButton
@onready var ai_debug_button: GameButton = %AiDebugButton

func _ready() -> void:
	AudioManager.ensure_music()
	_apply_styles()
	_refresh_ai_debug_label()
	sandbox_button.pressed.connect(func(): get_tree().change_scene_to_file(SANDBOX_SCENE))
	duel_button.pressed.connect(func(): get_tree().change_scene_to_file(DUEL_R3_SCENE))
	duel_r4_button.pressed.connect(func(): get_tree().change_scene_to_file(DUEL_R4_SCENE))
	big_button.pressed.connect(func(): get_tree().change_scene_to_file(BIG_R4_SCENE))
	ai_debug_button.pressed.connect(_toggle_ai_debug)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/runnables/menu.tscn"))

func _toggle_ai_debug() -> void:
	AttackNearestEnemyBehavior.debug_enabled = not AttackNearestEnemyBehavior.debug_enabled
	_refresh_ai_debug_label()

func _refresh_ai_debug_label() -> void:
	var on := AttackNearestEnemyBehavior.debug_enabled
	ai_debug_button.text = "AI debug: ON" if on else "AI debug: OFF"

func _apply_styles() -> void:
	var panel_sb := _make_stylebox()
	%MenuPanel.add_theme_stylebox_override("panel", panel_sb)
	%TitleLabel.add_theme_color_override("font_color", COLOR_TEXT)
	%TitleLabel.add_theme_font_size_override("font_size", 36)

func _make_stylebox(bg: Color = COLOR_BG) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COLOR_BORDER
	sb.border_width_left = BORDER_THICK
	sb.border_width_right = BORDER_THICK
	sb.border_width_top = BORDER_THICK
	sb.border_width_bottom = BORDER_THICK
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb
