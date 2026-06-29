class_name GameButton
extends Control

## Reusable styled button with hover lift, scale, and tile SFX.

signal pressed

enum SizePreset { NORMAL, COMPACT, LARGE }

@export var text: String = "":
	set(value):
		text = value
		if _button:
			_button.text = value
		_apply_width()

@export var font_size: int = 24:
	set(value):
		font_size = value
		_apply_font_size()
		_apply_width()

@export var size_preset: SizePreset = SizePreset.NORMAL:
	set(value):
		size_preset = value
		_apply_size_preset()

@export var button_height: int = 0
## When true, stretch to the parent width (use inside fixed anchor boxes).
@export var expand_horizontal: bool = false
## Fixed width in pixels. When 0, width is derived from text (capped by max_width).
@export var preferred_width: int = 0
## Upper cap for auto-sized text buttons. Ignored when preferred_width or expand_horizontal is set.
@export var max_width: int = 300
var _button_disabled: bool = false

@export var button_disabled: bool = false:
	set(value):
		if _button_disabled == value:
			return
		_button_disabled = value
		if _button:
			_button.disabled = value
			if value:
				_reset_visual(true)
	get:
		return _button_disabled
@export var hover_lift: float = 4.0
@export var hover_scale: float = 1.035
@export var play_sounds: bool = true

const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_TEXT_DISABLED := Color(0.42, 0.38, 0.34)
const COLOR_BLOCK_BG := Color(0.93, 0.89, 0.82)
const COLOR_BLOCK_BG_DISABLED := Color(0.84, 0.79, 0.72)
const BORDER_THICK := 4
const RADIUS := 16

const HEIGHT_NORMAL := 54
const HEIGHT_COMPACT := 64
const HEIGHT_LARGE := 72

const CONTENT_MARGIN_H := 40
const WIDTH_PAD := CONTENT_MARGIN_H + BORDER_THICK * 2

@onready var _button: Button = $Button

var _rest_y: float = 0.0
var _hover_tween: Tween
var _is_hovered: bool = false
var _resolved_height: int = HEIGHT_NORMAL
var _resolved_width: int = 0
var _pad_v: int = 0
var _pad_h: int = 0

func _ready() -> void:
	_apply_size_preset()
	_apply_theme()
	_button.text = text
	_apply_font_size()
	_apply_width()
	_button.focus_mode = Control.FOCUS_NONE
	_button.disabled = _button_disabled
	_button.pressed.connect(_on_pressed)
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	call_deferred("_capture_rest_position")

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_reset_visual(true)
	elif what == NOTIFICATION_RESIZED:
		_relayout_inner()
		call_deferred("_capture_rest_position")

func set_disabled(value: bool) -> void:
	button_disabled = value

func is_disabled() -> bool:
	return _button_disabled

func _apply_size_preset() -> void:
	var height := button_height
	if height <= 0:
		match size_preset:
			SizePreset.COMPACT:
				height = HEIGHT_COMPACT
				if font_size == 24:
					font_size = 36
			SizePreset.LARGE:
				height = HEIGHT_LARGE
				if font_size == 24:
					font_size = 30
			_:
				height = HEIGHT_NORMAL

	_resolved_height = height
	_update_layout_metrics()

func _apply_width() -> void:
	if expand_horizontal:
		size_flags_horizontal = SIZE_EXPAND_FILL
		_resolved_width = 0
	elif preferred_width > 0:
		size_flags_horizontal = SIZE_SHRINK_CENTER
		_resolved_width = preferred_width
	else:
		size_flags_horizontal = SIZE_SHRINK_CENTER
		var content_w := _measure_text_width() + WIDTH_PAD
		if max_width > 0:
			content_w = mini(content_w, max_width)
		_resolved_width = int(ceil(content_w))

	_update_layout_metrics()

func _hover_pad_vertical() -> int:
	var scale_overflow := float(_resolved_height) * (hover_scale - 1.0) * 0.5
	return int(ceil(hover_lift + scale_overflow + 2.0))

func _hover_pad_horizontal() -> int:
	var basis := _resolved_width if _resolved_width > 0 else 120
	var scale_overflow := float(basis) * (hover_scale - 1.0) * 0.5
	return int(ceil(scale_overflow + 2.0))

func _update_layout_metrics() -> void:
	_pad_v = _hover_pad_vertical()
	_pad_h = _hover_pad_horizontal()

	custom_minimum_size.y = _resolved_height + _pad_v * 2
	if expand_horizontal:
		custom_minimum_size.x = 0
	else:
		custom_minimum_size.x = _resolved_width + _pad_h * 2

	_relayout_inner()

func _relayout_inner() -> void:
	if not _button:
		return

	var btn_w := _resolved_width
	if expand_horizontal:
		btn_w = maxi(int(size.x) - _pad_h * 2, 0)
	elif btn_w <= 0:
		btn_w = maxi(int(custom_minimum_size.x) - _pad_h * 2, 0)

	_button.custom_minimum_size = Vector2(btn_w, _resolved_height)
	_button.size = Vector2(btn_w, _resolved_height)
	_button.position = Vector2(_pad_h, _pad_v)

	if not _is_hovered:
		_button.scale = Vector2.ONE
		_rest_y = _pad_v

func _measure_text_width() -> float:
	if text.is_empty():
		return 48.0
	var font: Font = _button.get_theme_font("font") if _button else null
	var fs := font_size
	if font:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return float(text.length()) * fs * 0.55

func _apply_font_size() -> void:
	if _button:
		_button.add_theme_font_size_override("font_size", font_size)

func _apply_theme() -> void:
	for color_name in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_focus_color", "font_hover_pressed_color", "font_disabled_color",
	]:
		var color := COLOR_TEXT_DISABLED if color_name == "font_disabled_color" else COLOR_TEXT
		_button.add_theme_color_override(color_name, color)

	_button.clip_text = true
	_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var normal_sb := _make_stylebox(COLOR_BLOCK_BG)
	var hover_sb := _make_stylebox(COLOR_BLOCK_BG.lightened(0.05))
	var pressed_sb := _make_stylebox(Color(0.88, 0.83, 0.74))
	_button.add_theme_stylebox_override("normal", normal_sb)
	_button.add_theme_stylebox_override("hover", hover_sb)
	_button.add_theme_stylebox_override("pressed", pressed_sb)
	_button.add_theme_stylebox_override("focus", normal_sb)
	_button.add_theme_stylebox_override("disabled", _make_stylebox(COLOR_BLOCK_BG_DISABLED))

func _make_stylebox(bg: Color) -> StyleBoxFlat:
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
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

func _capture_rest_position() -> void:
	_relayout_inner()
	_rest_y = _button.position.y
	if _is_hovered:
		return
	_reset_visual(true)

func _on_pressed() -> void:
	if play_sounds:
		AudioManager.play_sfx("tile_click")
	pressed.emit()

func _on_mouse_entered() -> void:
	if _button.disabled:
		return
	_is_hovered = true
	if play_sounds:
		AudioManager.play_sfx("tile_hover")
	_animate_hover(true)

func _on_mouse_exited() -> void:
	_is_hovered = false
	_animate_hover(false)

func _animate_hover(hovered: bool) -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()

	_button.pivot_offset = _button.size * 0.5
	_hover_tween = _button.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hovered:
		_hover_tween.parallel().tween_property(_button, "scale", Vector2(hover_scale, hover_scale), 0.13)
		_hover_tween.parallel().tween_property(_button, "position:y", _rest_y - hover_lift, 0.13)
	else:
		_hover_tween.parallel().tween_property(_button, "scale", Vector2.ONE, 0.11)
		_hover_tween.parallel().tween_property(_button, "position:y", _rest_y, 0.11)

func _reset_visual(instant: bool) -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_is_hovered = false
	if not _button:
		return
	if instant:
		_button.scale = Vector2.ONE
		_button.position.y = _rest_y
	else:
		_animate_hover(false)
