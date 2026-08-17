class_name BattleExpectationBar
extends Control

## Bottom battle HUD: solo legion strip, or expectation preview on target hover.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const BattleExpectationEstimator = preload("res://scripts/battle/battle_expectation_estimator.gd")
const LegionStripScene = preload("res://scenes/ui/legion_strip.tscn")

const ICON_DAMAGE = preload("res://assets/icons/base_icons_sprites/damage.png")
const ICON_DEATH = preload("res://assets/icons/base_icons_sprites/skull.png")
const ICON_SHIELD = preload("res://assets/icons/base_icons_sprites/shield.png")
const ICON_HEAL = preload("res://assets/icons/base_icons_sprites/heart.png")
const COLOR_HEAL := Color(0.18, 0.52, 0.28)

const BOTTOM_MARGIN := 48.0
const CENTER_GAP := 20.0
const CENTER_WIDTH_COMBAT := 300.0
const CENTER_WIDTH_SELF_HEAL := 108.0
const CENTER_WIDTH_HEAL_ALLY := 200.0
const ICON_STAT_PX := 36
const FONT_STAT_SIZE := 28

const MODE_NONE := ""
const MODE_COMBAT := "combat"
const MODE_SELF_HEAL := "self_heal"
const MODE_HEAL_ALLY := "heal_ally"

var _row: HBoxContainer
var _attacker_strip: LegionStrip
var _center_panel: PanelContainer
var _center_inner: CenterContainer
var _center_compare: HBoxContainer
var _center_solo_heal: Control
var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _center_glyph: Label
var _left_damage: Control
var _right_damage: Control
var _left_losses: Control
var _right_losses: Control
var _left_heal: Control
var _right_heal: Control
var _left_shield: Control
var _right_shield: Control
var _solo_heal_chip: Control
var _defender_strip: LegionStrip
var _compare_active := false
var _preview_mode := MODE_NONE
var _layout_tween: Tween

func _ready() -> void:
	name = "BattleExpectationBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_layout_root()
	hide()

func show_legion(legion: Legion, sticky: bool = false) -> void:
	if legion == null or legion.units.is_empty():
		hide_strip()
		return
	hide_attack_preview(false)
	_attacker_strip.show_legion(legion, sticky)
	show()
	_layout_solo()

func hide_strip() -> void:
	hide_attack_preview(false)
	_attacker_strip.hide_strip()
	_defender_strip.hide_strip()
	hide()

func is_showing_legion(legion: Legion) -> bool:
	return _attacker_strip.is_showing_legion(legion) or _defender_strip.is_showing_legion(legion)

func current_legion() -> Legion:
	return _attacker_strip.current_legion()

func is_sticky() -> bool:
	return _attacker_strip.is_sticky()

func apply_unit_vitals_fx(unit: Unit, hp: float, shield: float) -> void:
	_attacker_strip.apply_unit_vitals_fx(unit, hp, shield)
	if _compare_active and _preview_mode != MODE_SELF_HEAL:
		_defender_strip.apply_unit_vitals_fx(unit, hp, shield)

func refresh_if_legion(legion: Legion) -> void:
	_attacker_strip.refresh_if_legion(legion)
	if _compare_active and _preview_mode != MODE_SELF_HEAL:
		_defender_strip.refresh_if_legion(legion)

func show_attack_preview(
	attacker: Legion,
	defender: Legion,
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i
) -> void:
	if attacker == null:
		hide_attack_preview()
		return
	if action_id == "self_heal":
		defender = attacker
	elif defender == null:
		hide_attack_preview()
		return

	var estimate: Dictionary = BattleExpectationEstimator.estimate(
		attacker,
		defender,
		action_id,
		from_coords,
		to_coords
	)
	var mode := _mode_for_action(action_id)
	var mode_changed := _preview_mode != mode
	_preview_mode = mode
	_configure_preview_chrome(mode)

	_attacker_strip.show_legion(attacker, true)
	if mode == MODE_SELF_HEAL:
		_defender_strip.hide_strip()
	else:
		_defender_strip.show_legion(defender, false)

	_apply_estimate_labels(estimate, attacker, defender, mode)

	if not _compare_active:
		_compare_active = true
		_center_panel.show()
		if mode != MODE_SELF_HEAL:
			_defender_strip.show()
		_animate_compare_in(mode)
	elif mode_changed:
		_animate_compare_in(mode)
	else:
		_layout_compare(false)

	show()

func hide_attack_preview(animate: bool = true) -> void:
	if not _compare_active:
		return
	var prev_mode := _preview_mode
	_compare_active = false
	_preview_mode = MODE_NONE
	if animate:
		_animate_compare_out(prev_mode)
	else:
		_center_panel.hide()
		_center_compare.hide()
		_center_solo_heal.hide()
		_defender_strip.hide_strip()
		_layout_solo()

func _build() -> void:
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.add_theme_constant_override("separation", int(CENTER_GAP))
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)

	_attacker_strip = LegionStripScene.instantiate()
	_attacker_strip.configure_embedded_hud()
	_attacker_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_attacker_strip)

	_center_panel = PanelContainer.new()
	_center_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, 12, UiTheme.BORDER_THICK, 12)
	)
	_row.add_child(_center_panel)

	_center_inner = CenterContainer.new()
	_center_inner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center_panel.add_child(_center_inner)

	_center_compare = HBoxContainer.new()
	_center_compare.add_theme_constant_override("separation", 16)
	_center_compare.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_inner.add_child(_center_compare)

	_left_col = VBoxContainer.new()
	_left_col.add_theme_constant_override("separation", 8)
	_left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_compare.add_child(_left_col)

	_center_glyph = Label.new()
	_center_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_glyph.add_theme_font_size_override("font_size", 52)
	_center_glyph.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	_center_glyph.add_theme_color_override("font_outline_color", UiTheme.COLOR_BORDER)
	_center_glyph.add_theme_constant_override("outline_size", 3)
	_center_compare.add_child(_center_glyph)

	_right_col = VBoxContainer.new()
	_right_col.add_theme_constant_override("separation", 8)
	_right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_compare.add_child(_right_col)

	_left_damage = _make_icon_value_chip(ICON_DAMAGE, "")
	_left_col.add_child(_left_damage)
	_left_shield = _make_icon_value_chip(ICON_SHIELD, "")
	_left_col.add_child(_left_shield)
	_left_losses = _make_icon_value_chip(ICON_DEATH, "")
	_left_col.add_child(_left_losses)
	_left_heal = _make_icon_value_chip(ICON_HEAL, "", COLOR_HEAL)
	_left_col.add_child(_left_heal)

	_right_damage = _make_icon_value_chip(ICON_DAMAGE, "")
	_right_col.add_child(_right_damage)
	_right_shield = _make_icon_value_chip(ICON_SHIELD, "")
	_right_col.add_child(_right_shield)
	_right_losses = _make_icon_value_chip(ICON_DEATH, "")
	_right_col.add_child(_right_losses)
	_right_heal = _make_icon_value_chip(ICON_HEAL, "", COLOR_HEAL)
	_right_col.add_child(_right_heal)

	_center_solo_heal = CenterContainer.new()
	_center_inner.add_child(_center_solo_heal)
	_solo_heal_chip = _make_icon_value_chip(ICON_HEAL, "", COLOR_HEAL)
	_center_solo_heal.add_child(_solo_heal_chip)

	_defender_strip = LegionStripScene.instantiate()
	_defender_strip.configure_embedded_hud()
	_defender_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_defender_strip)

	_center_panel.hide()
	_center_compare.hide()
	_center_solo_heal.hide()
	_defender_strip.hide()
	_hide_all_stat_chips()

func _mode_for_action(action_id: String) -> String:
	match action_id:
		"self_heal":
			return MODE_SELF_HEAL
		"heal_ally":
			return MODE_HEAL_ALLY
		_:
			return MODE_COMBAT

func _configure_preview_chrome(mode: String) -> void:
	match mode:
		MODE_SELF_HEAL:
			_center_compare.hide()
			_center_solo_heal.show()
			_center_panel.custom_minimum_size = Vector2(CENTER_WIDTH_SELF_HEAL, 0.0)
		MODE_HEAL_ALLY:
			_center_solo_heal.hide()
			_center_compare.show()
			_center_glyph.text = "→"
			_center_glyph.rotation = 0.0
			_center_glyph.add_theme_font_size_override("font_size", 44)
			_center_panel.custom_minimum_size = Vector2(CENTER_WIDTH_HEAL_ALLY, 0.0)
		_:
			_center_solo_heal.hide()
			_center_compare.show()
			_center_glyph.text = "VS"
			_center_glyph.rotation = deg_to_rad(-12.0)
			_center_glyph.add_theme_font_size_override("font_size", 52)
			_center_panel.custom_minimum_size = Vector2(CENTER_WIDTH_COMBAT, 0.0)

func _center_panel_width() -> float:
	match _preview_mode:
		MODE_SELF_HEAL:
			return CENTER_WIDTH_SELF_HEAL
		MODE_HEAL_ALLY:
			return CENTER_WIDTH_HEAL_ALLY
		_:
			return CENTER_WIDTH_COMBAT

func _hide_all_stat_chips() -> void:
	for chip in [
		_left_damage, _right_damage, _left_losses, _right_losses,
		_left_heal, _right_heal, _left_shield, _right_shield, _solo_heal_chip
	]:
		if chip:
			chip.visible = false

func _make_icon_value_chip(icon: Texture2D, value_text: String, value_color: Color = UiTheme.COLOR_TEXT) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = Vector2(ICON_STAT_PX, ICON_STAT_PX)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)

	var label := Label.new()
	label.text = value_text
	label.add_theme_color_override("font_color", value_color)
	label.add_theme_font_size_override("font_size", FONT_STAT_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	return row

func _set_chip_value(chip: Control, value_text: String, value_color: Color = UiTheme.COLOR_TEXT) -> void:
	if chip == null or chip.get_child_count() < 2:
		return
	var lbl := chip.get_child(1)
	if lbl is Label:
		(lbl as Label).text = value_text
		(lbl as Label).add_theme_color_override("font_color", value_color)

func _set_range_chip(chip: Control, min_value: int, max_value: int, value_color: Color = UiTheme.COLOR_TEXT) -> void:
	if chip == null:
		return
	if max_value <= 0:
		chip.visible = false
		return
	chip.visible = true
	_set_chip_value(chip, _range_text(min_value, max_value), value_color)

func _apply_estimate_labels(
	estimate: Dictionary,
	attacker: Legion,
	defender: Legion,
	mode: String
) -> void:
	_hide_all_stat_chips()

	if mode == MODE_SELF_HEAL:
		var heal_txt := _range_text(
			int(estimate.get("heal_min", 0)),
			int(estimate.get("heal_max", 0))
		)
		_solo_heal_chip.visible = true
		_set_chip_value(_solo_heal_chip, heal_txt, COLOR_HEAL)
		return

	if mode == MODE_HEAL_ALLY:
		var heal_txt := _range_text(
			int(estimate.get("heal_min", 0)),
			int(estimate.get("heal_max", 0))
		)
		_right_heal.visible = true
		_set_chip_value(_right_heal, heal_txt, COLOR_HEAL)
		return

	# Combat: only show non-zero expectations; shield only when present.
	_set_range_chip(_left_damage, int(estimate.get("own_damage_min", 0)), int(estimate.get("own_damage_max", 0)))
	_set_range_chip(_right_damage, int(estimate.get("enemy_damage_min", 0)), int(estimate.get("enemy_damage_max", 0)))
	_set_range_chip(_left_losses, int(estimate.get("own_losses_min", 0)), int(estimate.get("own_losses_max", 0)))
	_set_range_chip(_right_losses, int(estimate.get("enemy_losses_min", 0)), int(estimate.get("enemy_losses_max", 0)))

	var us_shield := _total_shield(attacker)
	if us_shield > 0:
		_left_shield.visible = true
		_set_chip_value(_left_shield, str(us_shield))
	var them_shield := _total_shield(defender)
	if them_shield > 0:
		_right_shield.visible = true
		_set_chip_value(_right_shield, str(them_shield))

static func _total_shield(legion: Legion) -> int:
	if legion == null:
		return 0
	var total := 0
	for u in legion.units:
		if u:
			total += int(u.shield_remaining)
	return total

static func _range_text(min_value: int, max_value: int) -> String:
	if min_value == max_value:
		return str(min_value)
	return "%d–%d" % [min_value, max_value]

func _layout_root() -> void:
	var solo_w := _attacker_strip.custom_minimum_size.x
	var solo_h := _attacker_strip.custom_minimum_size.y
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -solo_w * 0.5
	offset_right = solo_w * 0.5
	offset_bottom = -BOTTOM_MARGIN
	offset_top = -BOTTOM_MARGIN - solo_h
	custom_minimum_size = Vector2(solo_w, solo_h)

func _layout_solo() -> void:
	_layout_compare(false)

func _layout_compare(_animate: bool) -> void:
	var attacker_w := _attacker_strip.custom_minimum_size.x
	var strip_h := _attacker_strip.custom_minimum_size.y

	if _compare_active:
		var center_w := _center_panel_width()
		var center_h := maxf(
			_center_compare.get_combined_minimum_size().y,
			_center_solo_heal.get_combined_minimum_size().y
		)
		var total_w := attacker_w
		var total_h := maxf(strip_h, center_h)
		if _preview_mode == MODE_SELF_HEAL:
			total_w += CENTER_GAP + center_w
		else:
			var defender_w := _defender_strip.custom_minimum_size.x
			strip_h = maxf(strip_h, _defender_strip.custom_minimum_size.y)
			total_w += CENTER_GAP + center_w + CENTER_GAP + defender_w
			total_h = maxf(strip_h, center_h)
		offset_left = -total_w * 0.5
		offset_right = total_w * 0.5
		offset_top = -BOTTOM_MARGIN - total_h
		custom_minimum_size = Vector2(total_w, total_h)
	else:
		offset_left = -attacker_w * 0.5
		offset_right = attacker_w * 0.5
		offset_top = -BOTTOM_MARGIN - strip_h
		custom_minimum_size = Vector2(attacker_w, strip_h)

func _animate_compare_in(mode: String) -> void:
	if _layout_tween and _layout_tween.is_running():
		_layout_tween.kill()
	_layout_compare(false)
	_center_panel.modulate.a = 0.0
	_center_panel.scale = Vector2(0.92, 0.92)

	match mode:
		MODE_SELF_HEAL:
			_layout_tween = create_tween().set_parallel(true)
			_layout_tween.tween_property(_center_panel, "modulate:a", 1.0, 0.1)
			_layout_tween.tween_property(_center_panel, "scale", Vector2.ONE, 0.1)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		MODE_HEAL_ALLY:
			_defender_strip.modulate.a = 0.0
			_defender_strip.scale = Vector2(0.92, 0.92)
			_layout_tween = create_tween().set_parallel(true)
			_layout_tween.tween_property(_center_panel, "modulate:a", 1.0, UiTheme.INTERACT_ENTRY_DURATION)
			_layout_tween.tween_property(_center_panel, "scale", Vector2.ONE, UiTheme.INTERACT_ENTRY_DURATION)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_layout_tween.tween_property(_defender_strip, "modulate:a", 1.0, UiTheme.INTERACT_ENTRY_DURATION)
			_layout_tween.tween_property(_defender_strip, "scale", Vector2.ONE, UiTheme.INTERACT_ENTRY_DURATION)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			UiTheme.juice_pop_in(_attacker_strip, UiTheme.INTERACT_ENTRY_DURATION * 0.85)
		_:
			_defender_strip.modulate.a = 0.0
			_defender_strip.scale = Vector2(0.9, 0.9)
			_layout_tween = create_tween().set_parallel(true)
			_layout_tween.tween_property(_center_panel, "modulate:a", 1.0, UiTheme.INTERACT_ENTRY_DURATION)
			_layout_tween.tween_property(_center_panel, "scale", Vector2.ONE, UiTheme.INTERACT_ENTRY_DURATION)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_layout_tween.tween_property(_defender_strip, "modulate:a", 1.0, UiTheme.INTERACT_ENTRY_DURATION)
			_layout_tween.tween_property(_defender_strip, "scale", Vector2.ONE, UiTheme.INTERACT_ENTRY_DURATION)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			UiTheme.juice_pop_in(_attacker_strip, UiTheme.INTERACT_ENTRY_DURATION * 0.85)

func _animate_compare_out(prev_mode: String = MODE_NONE) -> void:
	if _layout_tween and _layout_tween.is_running():
		_layout_tween.kill()
	_layout_tween = create_tween().set_parallel(true)
	_layout_tween.tween_property(_center_panel, "modulate:a", 0.0, 0.1)
	if prev_mode != MODE_SELF_HEAL:
		_layout_tween.tween_property(_defender_strip, "modulate:a", 0.0, 0.1)
	_layout_tween.finished.connect(func() -> void:
		_center_panel.hide()
		_center_compare.hide()
		_center_solo_heal.hide()
		_defender_strip.hide_strip()
		_layout_solo()
	, CONNECT_ONE_SHOT)
