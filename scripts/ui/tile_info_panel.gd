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

func _ready() -> void:
	_apply_style()
	_set_empty_state()

func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sb)

	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	legion_name.add_theme_color_override("font_color", COLOR_TEXT)
	legion_stats.add_theme_color_override("font_color", COLOR_TEXT)

func _set_empty_state() -> void:
	title_label.text = "Tile Info"
	legion_block.hide()

func show_tile(tile: Tile) -> void:
	if tile == null or not tile.has_legion():
		_set_empty_state()
		hide()
		return

	title_label.text = "Tile Info"
	_render_legion(tile.legion)

func _render_legion(legion: Legion) -> void:
	legion_block.show()
	legion_name.text = legion.unit_type

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
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		var name := Label.new()
		name.text = "Unit %d" % (i + 1)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_color_override("font_color", COLOR_TEXT)

		var hp := Label.new()
		hp.text = "%d/%d" % [int(u.current_health), int(u.max_health)]
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp.add_theme_color_override("font_color", COLOR_TEXT)

		row.add_child(name)
		row.add_child(hp)
		units_list.add_child(row)

func _load_unit_icon(unit_type: String) -> Texture2D:
	# Keep consistent with `UnitVisu.update_sprite()` path pattern.
	var path := "res://assets/units_v2/done/base_uncut_sprites/%s_front.png" % unit_type.to_lower()
	var tex := load(path)
	return tex if tex is Texture2D else null

