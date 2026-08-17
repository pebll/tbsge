class_name UiStatIcons
extends RefCounted

## Shared stat icon textures + icon+value rows (tile panel, legion strip, tooltips).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const ICON_ATTACK := preload("res://assets/icons/base_icons_sprites/sword.png")
const ICON_BOW := preload("res://assets/icons/base_icons_sprites/bow.png")
const ICON_HEALTH := preload("res://assets/icons/base_icons_sprites/heart.png")
const ICON_SHIELD := preload("res://assets/icons/base_icons_sprites/shield.png")
const ICON_AP := preload("res://assets/icons/base_icons_sprites/boot.png")
const ICON_PRICE := preload("res://assets/icons/base_icons_sprites/coin.png")

static func make_row(
	icon: Texture2D,
	text: String,
	icon_px: int = 22,
	font_size: int = 16,
	separation: int = 6
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(icon_px, icon_px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row

## Array of `{ "icon": Texture2D, "text": String }` for unit inspect tooltips.
static func unit_stat_rows(unit: Unit, legion: Legion = null) -> Array:
	var rows: Array = []
	if unit == null:
		return rows
	var def: UnitDefinition = unit.definition
	rows.append({
		"icon": ICON_HEALTH,
		"text": "%d / %d" % [int(round(unit.current_health)), int(round(unit.max_health))],
	})
	if unit.shield_max > 0:
		rows.append({
			"icon": ICON_SHIELD,
			"text": "%d / %d" % [unit.shield_remaining, unit.shield_max],
		})
	rows.append({
		"icon": ICON_ATTACK,
		"text": "%d" % int(round(unit.attack)),
	})
	if unit.has_ranged():
		rows.append({
			"icon": ICON_BOW,
			"text": "%d" % int(round(unit.ranged_attack)),
		})
	if def:
		rows.append({
			"icon": ICON_PRICE,
			"text": "%d" % def.price,
		})
	var ap_cur := legion.current_ap if legion else 0
	var ap_max := legion.max_ap if legion else (def.ap if def else 0)
	rows.append({
		"icon": ICON_AP,
		"text": "%d / %d" % [ap_cur, ap_max],
	})
	return rows

static func populate_stat_vbox(
	vbox: VBoxContainer,
	rows: Array,
	icon_px: int = 22,
	font_size: int = 16
) -> void:
	for child in vbox.get_children():
		child.queue_free()
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var icon: Texture2D = entry.get("icon")
		var text := String(entry.get("text", ""))
		if text.is_empty():
			continue
		vbox.add_child(make_row(icon, text, icon_px, font_size))
