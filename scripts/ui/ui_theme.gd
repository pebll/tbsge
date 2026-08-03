class_name UiTheme
extends RefCounted

## Shared parchment chrome for beige UI. Prefer these over Color.lightened()
## so hover/press never flash toward stark white.

const COLOR_PANEL := Color(0.91, 0.86, 0.78)
const COLOR_CARD := Color(0.94, 0.90, 0.83)
const COLOR_BLOCK := Color(0.93, 0.89, 0.82)
const COLOR_HOVER := Color(0.89, 0.82, 0.70) ## warmer / slightly darker, not whitened
const COLOR_PRESSED := Color(0.84, 0.76, 0.64)
const COLOR_DISABLED := Color(0.84, 0.79, 0.72)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_TEXT_MUTED := Color(0.45, 0.40, 0.35)
const COLOR_TEXT_DISABLED := Color(0.42, 0.38, 0.34)

const BORDER_THICK := 4
const RADIUS := 16

static func panel_stylebox(
	bg: Color = COLOR_PANEL,
	border: Color = COLOR_BORDER,
	radius: int = RADIUS,
	border_thick: int = BORDER_THICK,
	margin: int = 14
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_thick
	sb.border_width_right = border_thick
	sb.border_width_top = border_thick
	sb.border_width_bottom = border_thick
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb

static func button_stylebox(
	bg: Color,
	radius: int = RADIUS,
	border_thick: int = BORDER_THICK,
	margin_h: int = 20,
	margin_v: int = 14
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COLOR_BORDER
	sb.border_width_left = border_thick
	sb.border_width_right = border_thick
	sb.border_width_top = border_thick
	sb.border_width_bottom = border_thick
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb

## Apply parchment Button states (hover = warm, never white).
static func apply_button_chrome(
	btn: Button,
	radius: int = RADIUS,
	border_thick: int = BORDER_THICK,
	margin_h: int = 10,
	margin_v: int = 10
) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override(
		"normal", button_stylebox(COLOR_BLOCK, radius, border_thick, margin_h, margin_v)
	)
	btn.add_theme_stylebox_override(
		"hover", button_stylebox(COLOR_HOVER, radius, border_thick, margin_h, margin_v)
	)
	btn.add_theme_stylebox_override(
		"pressed", button_stylebox(COLOR_PRESSED, radius, border_thick, margin_h, margin_v)
	)
	btn.add_theme_stylebox_override(
		"hover_pressed", button_stylebox(COLOR_PRESSED, radius, border_thick, margin_h, margin_v)
	)
	btn.add_theme_stylebox_override(
		"focus", button_stylebox(COLOR_BLOCK, radius, border_thick, margin_h, margin_v)
	)
	btn.add_theme_stylebox_override(
		"disabled", button_stylebox(COLOR_DISABLED, radius, border_thick, margin_h, margin_v)
	)
	for color_name in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_focus_color", "font_hover_pressed_color",
	]:
		btn.add_theme_color_override(color_name, COLOR_TEXT)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DISABLED)

static func apply_checkbox_chrome(box: CheckBox) -> void:
	if box == null:
		return
	for color_name in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_focus_color", "font_hover_pressed_color",
	]:
		box.add_theme_color_override(color_name, COLOR_TEXT)
	box.add_theme_color_override("font_disabled_color", COLOR_TEXT_DISABLED)
	# Empty styleboxes kill the default white hover flash on the label area.
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		box.add_theme_stylebox_override(style_name, empty)

## Soft squish pop-in (scale from slightly flat).
static func juice_pop_in(control: Control, duration: float = 0.14) -> Tween:
	if control == null or not is_instance_valid(control):
		return null
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.88, 0.78)
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(control, "modulate:a", 1.0, duration * 0.75)
	return tween

## Soft squish pop-out; caller should hide/free after finished if needed.
static func juice_pop_out(control: Control, duration: float = 0.11) -> Tween:
	if control == null or not is_instance_valid(control):
		return null
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(control, "scale", Vector2(0.92, 0.78), duration)
	tween.parallel().tween_property(control, "modulate:a", 0.0, duration)
	return tween

## Tiny press squish feedback.
static func juice_press(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(0.94, 0.90), 0.05)
	tween.tween_property(control, "scale", Vector2.ONE, 0.09)
