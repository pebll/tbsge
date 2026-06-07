class_name MinigameSetupPanel
extends PanelContainer

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

signal count_increase_pressed
signal count_decrease_pressed
signal clear_slot_pressed
signal change_type_pressed
signal ready_pressed

@onready var team_header: PanelContainer = %TeamHeader
@onready var team_label: Label = %TeamLabel
@onready var gold_value: Label = %GoldValue
@onready var gold_total: Label = %GoldTotal
@onready var hint_label: Label = %HintLabel
@onready var slot_label: Label = %SlotLabel
@onready var preview_block: VBoxContainer = %PreviewBlock
@onready var unit_icon: TextureRect = %UnitIcon
@onready var unit_name_label: Label = %UnitName
@onready var attack_value: Label = %AttackValue
@onready var health_value: Label = %HealthValue
@onready var price_value: Label = %PriceValue
@onready var size_value: Label = %SizeValue
@onready var count_value: Label = %CountValue
@onready var cost_value: Label = %CostValue
@onready var minus_button: Button = %MinusButton
@onready var plus_button: Button = %PlusButton
@onready var units_preview: VBoxContainer = %UnitsPreview
@onready var change_type_button: Button = %ChangeTypeButton
@onready var clear_button: Button = %ClearButton
@onready var ready_button: Button = %ReadyButton
@onready var team_footer: PanelContainer = %TeamFooter

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_BLOCK_BG := Color(0.93, 0.89, 0.82)
const BORDER_THICK := 4
const RADIUS := 16

var _unit_type: String = ""
var _unit_count: int = 0
var _remaining_budget: int = 0

func _ready() -> void:
	_apply_style()
	minus_button.pressed.connect(func(): count_decrease_pressed.emit())
	plus_button.pressed.connect(func(): count_increase_pressed.emit())
	clear_button.pressed.connect(func(): clear_slot_pressed.emit())
	change_type_button.pressed.connect(func(): change_type_pressed.emit())
	ready_button.pressed.connect(func(): ready_pressed.emit())
	show_idle_state()

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

	for label in [
		team_label, gold_value, gold_total, hint_label, slot_label,
		unit_name_label, attack_value, health_value, price_value, size_value,
		count_value, cost_value,
	]:
		label.add_theme_color_override("font_color", COLOR_TEXT)

	_style_big_button(minus_button, "−")
	_style_big_button(plus_button, "+")
	_style_action_button(ready_button, "Ready for battle")
	_style_action_button(change_type_button, "Change unit type")
	_style_action_button(clear_button, "Remove legion")

	unit_icon.custom_minimum_size = Vector2(110, 150)
	unit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _style_big_button(btn: Button, text: String) -> void:
	btn.text = text
	btn.custom_minimum_size = Vector2(72, 72)
	btn.add_theme_font_size_override("font_size", 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BLOCK_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = BORDER_THICK
	sb.border_width_right = BORDER_THICK
	sb.border_width_top = BORDER_THICK
	sb.border_width_bottom = BORDER_THICK
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", COLOR_TEXT)

func _style_action_button(btn: Button, text: String) -> void:
	btn.text = text
	btn.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BLOCK_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = BORDER_THICK
	sb.border_width_right = BORDER_THICK
	sb.border_width_top = BORDER_THICK
	sb.border_width_bottom = BORDER_THICK
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", COLOR_TEXT)

func show_for_team(team_id: String, draft_data: Dictionary) -> void:
	_apply_team_accent(team_id)
	_remaining_budget = int(draft_data.get("remaining_budget", 0))
	var budget_total := int(draft_data.get("budget_total", 0))
	gold_value.text = "%d" % _remaining_budget
	gold_total.text = "/ %d gold left" % budget_total
	show()

func show_idle_state() -> void:
	preview_block.hide()
	hint_label.show()
	hint_label.text = "Click an empty highlighted tile to place a legion."
	slot_label.text = "No slot selected"
	minus_button.disabled = true
	plus_button.disabled = true
	change_type_button.hide()
	clear_button.hide()

func show_message(text: String) -> void:
	if preview_block.visible:
		cost_value.text = text
	else:
		hint_label.show()
		hint_label.text = text

func show_slot_preview(
	coords: Vector2i,
	unit_type: String,
	unit_count: int,
	remaining_budget: int
) -> void:
	_unit_type = unit_type
	_unit_count = unit_count
	_remaining_budget = remaining_budget
	preview_block.show()
	hint_label.hide()
	change_type_button.show()
	clear_button.show()

	var def: UnitDefinition = UnitDefs.get_def(unit_type)
	var display_name := unit_type
	if def:
		display_name = def.display_name

	slot_label.text = "Deploy slot (%d, %d)" % [coords.x, coords.y]
	unit_name_label.text = display_name
	unit_icon.texture = def.icon if def and def.icon else null
	attack_value.text = "%d ATK" % (def.attack if def else 0)
	health_value.text = "%d HP" % (def.max_health if def else 0)
	price_value.text = "%dg each" % MinigameRulesScript.unit_price(unit_type)
	size_value.text = "%.1f size" % MinigameRulesScript.unit_size(unit_type)

	_refresh_count_display()
	_rebuild_unit_preview(unit_type, unit_count, def)
	minus_button.disabled = unit_count <= 1
	plus_button.disabled = not _can_add_unit(unit_count)

func _refresh_count_display() -> void:
	var max_count := MinigameRulesScript.max_units_in_legion(_unit_type)
	var cost := MinigameRulesScript.legion_cost(_unit_type, _unit_count)
	var fill := MinigameRulesScript.legion_fill(_unit_type, _unit_count)
	count_value.text = "%d / %d" % [_unit_count, max_count]
	cost_value.text = "Legion cost: %d gold  •  Size %.1f / 12" % [cost, fill]

func _can_add_unit(current_count: int) -> bool:
	var max_count := MinigameRulesScript.max_units_in_legion(_unit_type)
	if current_count >= max_count:
		return false
	var next_cost := MinigameRulesScript.unit_price(_unit_type)
	return next_cost <= _remaining_budget

func get_unit_type() -> String:
	return _unit_type

func get_unit_count() -> int:
	return _unit_count

func _rebuild_unit_preview(unit_type: String, unit_count: int, def: UnitDefinition) -> void:
	for child in units_preview.get_children():
		child.queue_free()
	for i in range(unit_count):
		units_preview.add_child(_build_preview_chip(unit_type, def))

func _build_preview_chip(unit_type: String, def: UnitDefinition) -> Control:
	var wrapper := PanelContainer.new()
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
	row_bg.content_margin_left = 10
	row_bg.content_margin_right = 10
	row_bg.content_margin_top = 8
	row_bg.content_margin_bottom = 8
	wrapper.add_theme_stylebox_override("panel", row_bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	wrapper.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = def.icon if def and def.icon else null
	row.add_child(icon)

	var hp := int(def.max_health if def else 10)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = hp
	bar.value = hp
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 28)
	row.add_child(bar)

	return wrapper

func _apply_team_accent(team_id: String) -> void:
	var team_res: Resource = TeamDefs.get_def(team_id)
	var accent: Color = COLOR_BORDER
	var label_text: String = team_id
	if team_res is TeamDefinition:
		var team: TeamDefinition = team_res
		accent = team.color
		label_text = team.display_name
	team_label.text = "%s — Army Setup" % label_text
	team_label.add_theme_color_override("font_color", _contrasting_text_color(accent))

	var header_sb := _accent_stylebox(accent)
	header_sb.content_margin_left = 14
	header_sb.content_margin_right = 14
	header_sb.content_margin_top = 10
	header_sb.content_margin_bottom = 10
	team_header.add_theme_stylebox_override("panel", header_sb)
	team_footer.add_theme_stylebox_override("panel", _accent_stylebox(accent))

func _accent_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_left = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	return sb

func _contrasting_text_color(bg: Color) -> Color:
	return Color.WHITE if bg.get_luminance() < 0.45 else COLOR_TEXT
