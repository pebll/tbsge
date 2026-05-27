class_name TileInfoPanel
extends PanelContainer

@onready var title_label: Label = %Title
@onready var legion_block: VBoxContainer = %LegionBlock
@onready var unit_icon: TextureRect = %UnitIcon
@onready var legion_name: Label = %LegionName
@onready var legion_stats: Label = %LegionStats
@onready var units_list: VBoxContainer = %UnitsList

const COLOR_BG := Color(0.91, 0.86, 0.78) # beige
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_BAR_BG := Color(0.82, 0.77, 0.68)
const COLOR_BAR_FILL := Color(0.60, 0.16, 0.12)
const COLOR_BLOCK_BG := Color(0.93, 0.89, 0.82)

const BORDER_THICK := 4
const RADIUS := 16

func _ready() -> void:
	_apply_style()
	_set_empty_state()

func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = BORDER_THICK
	sb.border_width_right = BORDER_THICK
	sb.border_width_top = BORDER_THICK
	sb.border_width_bottom = BORDER_THICK
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	add_theme_stylebox_override("panel", sb)

	legion_name.add_theme_color_override("font_color", COLOR_TEXT)
	legion_stats.add_theme_color_override("font_color", COLOR_TEXT)

func _set_empty_state() -> void:
	legion_block.hide()

func show_tile(tile: Tile) -> void:
	if tile == null or not tile.has_legion():
		_set_empty_state()
		hide()
		return

	_render_legion(tile.legion)

func _render_legion(legion: Legion) -> void:
	legion_block.show()
	legion_name.text = "%s LEGION" % legion.unit_type

	var unit0: Unit = legion.units[0] if legion.units.size() > 0 else null
	if unit0:
		legion_stats.text = "ATK %d   HP %d" % [int(unit0.attack), int(unit0.max_health)]
	else:
		legion_stats.text = ""

	unit_icon.texture = _load_unit_icon(legion.unit_type)

	for c in units_list.get_children():
		c.queue_free()

	for i in range(legion.units.size()):
		var u: Unit = legion.units[i]
		units_list.add_child(_build_unit_row(legion.unit_type, u))

func _build_unit_row(unit_type: String, u: Unit) -> Control:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_FILL
	row.add_theme_constant_override("separation", 14)

	var row_bg := StyleBoxFlat.new()
	row_bg.bg_color = COLOR_BLOCK_BG
	row_bg.border_color = COLOR_BORDER
	row_bg.border_width_left = BORDER_THICK
	row_bg.border_width_right = BORDER_THICK
	row_bg.border_width_top = BORDER_THICK
	row_bg.border_width_bottom = BORDER_THICK
	row_bg.corner_radius_top_left = RADIUS
	row_bg.corner_radius_top_right = RADIUS
	row_bg.corner_radius_bottom_left = RADIUS
	row_bg.corner_radius_bottom_right = RADIUS
	row_bg.content_margin_left = 12
	row_bg.content_margin_right = 12
	row_bg.content_margin_top = 12
	row_bg.content_margin_bottom = 12
	wrapper.add_theme_stylebox_override("panel", row_bg)

	wrapper.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(78, 78)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_unit_icon(unit_type)
	row.add_child(icon)

	# Vertically center the bar without affecting its horizontal expand.
	var bar_vbox := VBoxContainer.new()
	bar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_vbox.add_theme_constant_override("separation", 0)
	row.add_child(bar_vbox)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_vbox.add_child(spacer_top)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max(1.0, float(u.max_health))
	bar.value = clamp(float(u.current_health), 0.0, bar.max_value)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 32)

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = COLOR_BAR_BG
	sb_bg.border_color = COLOR_BORDER
	sb_bg.border_width_left = BORDER_THICK
	sb_bg.border_width_right = BORDER_THICK
	sb_bg.border_width_top = BORDER_THICK
	sb_bg.border_width_bottom = BORDER_THICK
	sb_bg.corner_radius_top_left = 10
	sb_bg.corner_radius_top_right = 10
	sb_bg.corner_radius_bottom_left = 10
	sb_bg.corner_radius_bottom_right = 10
	bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = COLOR_BAR_FILL
	sb_fill.corner_radius_top_left = 10
	sb_fill.corner_radius_top_right = 10
	sb_fill.corner_radius_bottom_left = 10
	sb_fill.corner_radius_bottom_right = 10
	bar.add_theme_stylebox_override("fill", sb_fill)

	bar_vbox.add_child(bar)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_vbox.add_child(spacer_bottom)

	var hp := Label.new()
	hp.text = "%d/%d" % [int(u.current_health), int(u.max_health)]
	hp.add_theme_color_override("font_color", COLOR_TEXT)
	hp.add_theme_font_size_override("font_size", 22)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hp)

	return wrapper

func _load_unit_icon(unit_type: String) -> Texture2D:
	# Keep consistent with `UnitVisu.update_sprite()` path pattern.
	var path := "res://assets/units_v2/done/base_uncut_sprites/%s_front.png" % unit_type.to_lower()
	var tex := load(path)
	return tex if tex is Texture2D else null

