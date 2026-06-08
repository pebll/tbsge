class_name TileInfoPanel
extends PanelContainer

signal draft_count_increase_pressed
signal draft_count_decrease_pressed
signal draft_change_type_pressed
signal draft_clear_slot_pressed

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

@onready var title_label: Label = %Title
@onready var legion_block: VBoxContainer = %LegionBlock
@onready var team_header: PanelContainer = %TeamHeader
@onready var team_name_label: Label = %TeamName
@onready var team_footer: PanelContainer = %TeamFooter
@onready var unit_icon: TextureRect = %UnitIcon
@onready var legion_name: Label = %LegionName
@onready var attack_icon: TextureRect = %AttackIcon
@onready var attack_value: Label = %AttackValue
@onready var health_icon: TextureRect = %HealthIcon
@onready var health_value: Label = %HealthValue
@onready var unit_count_icon: TextureRect = %UnitCountIcon
@onready var unit_count_value: Label = %UnitCountValue
@onready var ap_stat: HBoxContainer = %ApStat
@onready var ap_icon: TextureRect = %ApIcon
@onready var ap_value: Label = %ApValue
@onready var units_list: VBoxContainer = %UnitsList
@onready var draft_controls: VBoxContainer = %DraftControls
@onready var minus_button: GameButton = %MinusButton
@onready var plus_button: GameButton = %PlusButton
@onready var count_value: Label = %CountValue
@onready var cost_value: Label = %CostValue
@onready var change_type_button: GameButton = %ChangeTypeButton
@onready var clear_button: GameButton = %ClearButton

var _draft_mode: bool = false
var _draft_unit_type: String = ""
var _draft_unit_count: int = 0
var _remaining_budget: int = 0

const COLOR_BG := Color(0.91, 0.86, 0.78) # beige
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_BAR_BG := Color(0.82, 0.77, 0.68)
const COLOR_BAR_FILL := Color(0.60, 0.16, 0.12)
const COLOR_BLOCK_BG := Color(0.93, 0.89, 0.82)

const BORDER_THICK := 4
const RADIUS := 16

const ICON_ATTACK := preload("res://assets/icons/base_icons_sprites/sword.png")
const ICON_HEALTH := preload("res://assets/icons/base_icons_sprites/heart.png")
const ICON_UNIT_COUNT := preload("res://assets/icons/base_icons_sprites/torso.png")
const ICON_AP := preload("res://assets/icons/base_icons_sprites/boot.png")

func _ready() -> void:
	_apply_style()
	minus_button.pressed.connect(func(): draft_count_decrease_pressed.emit())
	plus_button.pressed.connect(func(): draft_count_increase_pressed.emit())
	change_type_button.pressed.connect(func(): draft_change_type_pressed.emit())
	clear_button.pressed.connect(func(): draft_clear_slot_pressed.emit())
	_set_empty_state()
	set_draft_mode(false)

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
	attack_value.add_theme_color_override("font_color", COLOR_TEXT)
	health_value.add_theme_color_override("font_color", COLOR_TEXT)
	unit_count_value.add_theme_color_override("font_color", COLOR_TEXT)
	ap_value.add_theme_color_override("font_color", COLOR_TEXT)

	attack_icon.texture = ICON_ATTACK
	health_icon.texture = ICON_HEALTH
	unit_count_icon.texture = ICON_UNIT_COUNT
	ap_icon.texture = ICON_AP

	_configure_stat_icon(unit_icon, Vector2(110, 150))
	_configure_stat_icon(attack_icon)
	_configure_stat_icon(health_icon)
	_configure_stat_icon(unit_count_icon)
	_configure_stat_icon(ap_icon, Vector2(56, 56))

func _configure_stat_icon(icon: TextureRect, min_size: Vector2 = Vector2(72, 72)) -> void:
	icon.custom_minimum_size = min_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _set_empty_state() -> void:
	legion_block.hide()

func show_tile(tile: Tile) -> void:
	if tile == null or not tile.has_legion():
		_set_empty_state()
		hide()
		return
	show_legion(tile.legion)

func show_legion(legion: Legion) -> void:
	if legion == null or legion.units.is_empty():
		_set_empty_state()
		hide()
		return
	set_draft_mode(false)
	_render_legion(legion)
	show()

func set_draft_mode(enabled: bool) -> void:
	_draft_mode = enabled
	draft_controls.visible = enabled
	ap_stat.visible = not enabled

func show_draft_legion(
	legion: Legion,
	remaining_budget: int,
	_coords: Vector2i,
	placement_count: int = -1
) -> void:
	if legion == null or legion.units.is_empty():
		_set_empty_state()
		hide()
		return
	_draft_unit_type = legion.unit_type
	_draft_unit_count = placement_count if placement_count >= 0 else legion.unit_count
	_remaining_budget = remaining_budget
	set_draft_mode(true)
	_render_legion(legion)
	_refresh_draft_controls()
	show()

func show_draft_message(text: String) -> void:
	if _draft_mode:
		cost_value.text = text

func _refresh_draft_controls() -> void:
	var max_count := MinigameRulesScript.max_units_in_legion(_draft_unit_type)
	var cost := MinigameRulesScript.legion_cost(_draft_unit_type, _draft_unit_count)
	var fill := MinigameRulesScript.legion_fill(_draft_unit_type, _draft_unit_count)
	count_value.text = "%d / %d" % [_draft_unit_count, max_count]
	cost_value.text = "Legion cost: %d gold  •  Size %.1f / 12" % [cost, fill]
	minus_button.button_disabled = _draft_unit_count <= 1
	plus_button.button_disabled = not _can_add_draft_unit()

func _can_add_draft_unit() -> bool:
	var max_count := MinigameRulesScript.max_units_in_legion(_draft_unit_type)
	if _draft_unit_count >= max_count:
		return false
	return MinigameRulesScript.unit_price(_draft_unit_type) <= _remaining_budget

func _render_legion(legion: Legion) -> void:
	_apply_team_accent(legion.team_id)
	legion_block.show()
	legion_name.text = "%s LEGION" % legion.unit_type

	var unit0: Unit = legion.units[0] if legion.units.size() > 0 else null
	if unit0:
		attack_value.text = "%d" % int(unit0.attack)
		health_value.text = "%d" % int(unit0.max_health)
	else:
		attack_value.text = ""
		health_value.text = ""

	unit_count_value.text = "%d" % legion.units.size()
	ap_value.text = "%d/%d" % [legion.current_ap, legion.max_ap]

	unit_icon.texture = unit0.definition.icon if unit0 and unit0.definition and unit0.definition.icon else _load_unit_icon(legion.unit_type)

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
	icon.texture = u.definition.icon if u.definition and u.definition.icon else _load_unit_icon(unit_type)
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
	hp.text = "%d/%d HP" % [int(u.current_health), int(u.max_health)]
	hp.add_theme_color_override("font_color", COLOR_TEXT)
	hp.add_theme_font_size_override("font_size", 22)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hp)

	return wrapper

func _team_accent_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	return sb

func _contrasting_text_color(bg: Color) -> Color:
	return Color.WHITE if bg.get_luminance() < 0.45 else COLOR_TEXT

func _apply_team_accent(team_id: String) -> void:
	var team_res: Resource = TeamDefs.get_def(team_id)
	var accent: Color = COLOR_BORDER
	var label_text: String = team_id
	if team_res is TeamDefinition:
		var team: TeamDefinition = team_res
		accent = team.color
		label_text = team.display_name

	team_name_label.text = label_text
	team_name_label.add_theme_color_override("font_color", _contrasting_text_color(accent))

	var header_sb := _team_accent_stylebox(accent)
	header_sb.content_margin_left = 14
	header_sb.content_margin_right = 14
	header_sb.content_margin_top = 10
	header_sb.content_margin_bottom = 10
	team_header.add_theme_stylebox_override("panel", header_sb)

	var footer_sb := _team_accent_stylebox(accent)
	footer_sb.corner_radius_top_left = 8
	footer_sb.corner_radius_top_right = 8
	footer_sb.corner_radius_bottom_left = 8
	footer_sb.corner_radius_bottom_right = 8
	team_footer.add_theme_stylebox_override("panel", footer_sb)

func _load_unit_icon(unit_type: String) -> Texture2D:
	# Keep consistent with `UnitVisu.update_sprite()` path pattern.
	var path := "res://assets/units_v2/done/base_uncut_sprites/%s_front.png" % unit_type.to_lower()
	var tex := load(path)
	return tex if tex is Texture2D else null
