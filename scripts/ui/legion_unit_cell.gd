class_name LegionUnitCell
extends Control

## One unit tile pasted over the legion strip board.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UnitFootprintScript = preload("res://scripts/ui/interact/unit_footprint.gd")

const COLOR_HP := Color(0.82, 0.18, 0.14, 1.0)
const COLOR_SHIELD := Color(0.55, 0.72, 0.86, 1.0)
const COLOR_BAR_BG := Color(0.78, 0.70, 0.58, 0.55)
const UNIT_BORDER := 4

var unit: Unit = null
var legion: Legion = null
var cell_scale: float = 64.0

var _frame: Panel
var _icon: TextureRect
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _shield_fill: ColorRect
var _edge_bar_bg: ColorRect
var _edge_hp: ColorRect
var _edge_shield: ColorRect
var _interact: UiInteractable
var _vitals_tween: Tween
var _display_hp: float = 0.0
var _display_shield: float = 0.0
var _built := false

func setup(
	u: Unit,
	owner_legion: Legion,
	placement: Dictionary,
	px_per_unit: float,
	policy: UiTooltipPolicy,
	tooltip_provider: Callable
) -> void:
	unit = u
	legion = owner_legion
	cell_scale = px_per_unit
	var fp: Vector2 = placement.get(
		"footprint",
		UnitFootprintScript.footprint(u.definition.size if u and u.definition else 1.0)
	)
	var pos: Vector2 = placement.get("pos", Vector2.ZERO)
	_build_if_needed()
	var pixel_size := fp * cell_scale
	custom_minimum_size = pixel_size
	size = pixel_size
	position = pos * cell_scale
	# Keep layout from shrinking us; Force size after enter tree.
	call_deferred("_force_pixel_size", pixel_size)
	_apply_icon()
	_display_hp = u.current_health if u else 0.0
	_display_shield = float(u.shield_remaining) if u else 0.0
	_apply_hp_style()
	_refresh_vitals(false)
	if _interact == null:
		_interact = UiInteractable.new()
		_interact.enable_select = false
		_interact.selection_marker_enabled = false
		_interact.enable_entry = false
		add_child(_interact)
	_interact.bind(self, policy)
	_interact.set_tooltip_provider(tooltip_provider)

func _force_pixel_size(pixel_size: Vector2) -> void:
	size = pixel_size
	custom_minimum_size = pixel_size
	_layout_vitals()

func apply_vitals(hp: float, shield: float, animate: bool = true) -> void:
	_refresh_vitals(animate, hp, shield)

func set_hp_style(_style: int) -> void:
	_apply_hp_style()
	_refresh_vitals(false)

func _build_if_needed() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	_frame = Panel.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_CARD, UiTheme.COLOR_BORDER, 10, UNIT_BORDER, 0)
	)
	add_child(_frame)

	_hp_bg = ColorRect.new()
	_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bg.color = COLOR_BAR_BG
	add_child(_hp_bg)

	_shield_fill = ColorRect.new()
	_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_fill.color = COLOR_SHIELD
	add_child(_shield_fill)

	_hp_fill = ColorRect.new()
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.color = COLOR_HP
	add_child(_hp_fill)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = UNIT_BORDER + 2
	_icon.offset_top = UNIT_BORDER + 2
	_icon.offset_right = -(UNIT_BORDER + 2)
	_icon.offset_bottom = -(UNIT_BORDER + 2)
	add_child(_icon)

	_edge_bar_bg = ColorRect.new()
	_edge_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_bar_bg.color = COLOR_BAR_BG
	add_child(_edge_bar_bg)

	_edge_shield = ColorRect.new()
	_edge_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_shield.color = COLOR_SHIELD
	add_child(_edge_shield)

	_edge_hp = ColorRect.new()
	_edge_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_hp.color = COLOR_HP
	add_child(_edge_hp)

func _apply_icon() -> void:
	if _icon == null or unit == null:
		return
	if unit.definition and unit.definition.icon:
		_icon.texture = unit.definition.icon

func _apply_hp_style() -> void:
	if not _built:
		return
	var style_b := GameSettings.legion_strip_hp_style == 1
	_hp_bg.visible = not style_b
	_hp_fill.visible = not style_b
	_shield_fill.visible = not style_b
	_edge_bar_bg.visible = style_b
	_edge_hp.visible = style_b
	_edge_shield.visible = style_b
	if _icon:
		_icon.offset_right = -(UNIT_BORDER + 10) if style_b else -(UNIT_BORDER + 2)

func _refresh_vitals(animate: bool, hp: float = -1.0, shield: float = -1.0) -> void:
	if unit == null or not _built:
		return
	var target_hp := hp if hp >= 0.0 else unit.current_health
	var target_sh := shield if shield >= 0.0 else float(unit.shield_remaining)
	if _vitals_tween and _vitals_tween.is_running():
		_vitals_tween.kill()
	if animate:
		var from_hp := _display_hp
		var from_sh := _display_shield
		var update_hp := func(v: float) -> void:
			_display_hp = v
			_layout_vitals()
		var update_sh := func(v: float) -> void:
			_display_shield = v
			_layout_vitals()
		_vitals_tween = create_tween()
		_vitals_tween.set_parallel(true)
		_vitals_tween.tween_method(update_hp, from_hp, target_hp, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_vitals_tween.tween_method(update_sh, from_sh, target_sh, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_display_hp = target_hp
		_display_shield = target_sh
		_layout_vitals()

func _content_rect() -> Rect2:
	var m := float(UNIT_BORDER)
	return Rect2(Vector2(m, m), Vector2(maxf(1.0, size.x - m * 2.0), maxf(1.0, size.y - m * 2.0)))

func _layout_vitals() -> void:
	if not _built or unit == null or size.x <= 1.0 or size.y <= 1.0:
		return
	if _hp_bg == null or _hp_fill == null:
		return
	var hp_max := maxf(1.0, float(unit.max_health))
	var sh_max := maxf(0.0, float(unit.shield_max))
	var hp_ratio := clampf(_display_hp / hp_max, 0.0, 1.0)
	var sh_ratio := 0.0
	if sh_max > 0.0:
		sh_ratio = clampf(_display_shield / sh_max, 0.0, 1.0)
	var inner := _content_rect()

	if GameSettings.legion_strip_hp_style == 1:
		var bar_w := 8.0
		var x0 := inner.position.x + inner.size.x - bar_w
		_edge_bar_bg.position = Vector2(x0, inner.position.y)
		_edge_bar_bg.size = Vector2(bar_w, inner.size.y)
		var usable := inner.size.y
		var hp_h := usable * hp_ratio
		_edge_hp.position = Vector2(x0, inner.position.y + usable - hp_h)
		_edge_hp.size = Vector2(bar_w, hp_h)
		if sh_max > 0.0:
			var sh_h := usable * sh_ratio * 0.35
			_edge_shield.visible = true
			_edge_shield.position = Vector2(x0, inner.position.y)
			_edge_shield.size = Vector2(bar_w, sh_h)
		else:
			_edge_shield.visible = false
	else:
		_hp_bg.position = inner.position
		_hp_bg.size = inner.size
		var hp_h := inner.size.y * hp_ratio
		_hp_fill.position = Vector2(inner.position.x, inner.position.y + inner.size.y - hp_h)
		_hp_fill.size = Vector2(inner.size.x, hp_h)
		if sh_max > 0.0:
			_shield_fill.visible = true
			var sh_h := inner.size.y * sh_ratio * 0.28
			_shield_fill.position = inner.position
			_shield_fill.size = Vector2(inner.size.x, sh_h)
		else:
			_shield_fill.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_vitals()
