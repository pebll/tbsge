class_name BattleActionLogPanel
extends PanelContainer

## Left-side Hearthstone-style action log. Newest entries at the bottom.
## Each action is a boxed card with unit sprite + action icon.

const COLOR_BG := Color(0.91, 0.86, 0.78, 0.94)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_CARD_BG := Color(0.93, 0.89, 0.82)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_MUTED := Color(0.40, 0.35, 0.30)
const BORDER_THICK := 4
const RADIUS := 16
const CARD_RADIUS := 12
const ICON_UNIT := Vector2(44, 44)
const ICON_ACTION := Vector2(28, 28)

const ICON_WAIT := preload("res://assets/icons/base_icons_sprites/boot.png")
const ICON_END_TURN := preload("res://assets/icons/base_icons_sprites/strong.png")

var _scroll: ScrollContainer
var _list: VBoxContainer
var _title: Label
var _tooltip: TooltipController = null

func _ready() -> void:
	_build()
	_apply_style()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 16
	offset_top = 120
	offset_right = 360
	offset_bottom = 560
	hide()

func set_tooltip_controller(controller: TooltipController) -> void:
	_tooltip = controller

func bind_log(action_log: BattleActionLog) -> void:
	clear_entries()
	if action_log == null:
		return
	for entry in action_log.entries:
		_add_entry_row(entry)
	_scroll_to_bottom()

func clear_entries() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()

func append_entry(entry: Dictionary) -> void:
	_add_entry_row(entry)
	_scroll_to_bottom()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_title = Label.new()
	_title.text = "Battle log"
	_title.add_theme_color_override("font_color", COLOR_TEXT)
	_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

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
	add_theme_stylebox_override("panel", sb)

func _add_entry_row(entry: Dictionary) -> void:
	if _list == null or entry.is_empty():
		return

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "Right-click to inspect"
	card.add_theme_stylebox_override("panel", _card_stylebox())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var caster_icon := _make_texture_rect(_unit_icon(String(entry.get("caster_unit_type", ""))), ICON_UNIT)
	row.add_child(caster_icon)

	var action_icon := _make_texture_rect(_action_icon(String(entry.get("action_id", ""))), ICON_ACTION)
	row.add_child(action_icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var headline := Label.new()
	headline.text = _headline(entry)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_theme_color_override("font_color", COLOR_TEXT)
	headline.add_theme_font_size_override("font_size", 15)
	text_col.add_child(headline)

	var result := String(entry.get("result_summary", ""))
	if not result.is_empty():
		var result_label := Label.new()
		result_label.text = result
		result_label.add_theme_color_override("font_color", COLOR_MUTED)
		result_label.add_theme_font_size_override("font_size", 13)
		text_col.add_child(result_label)

	var target_type := String(entry.get("target_unit_type", ""))
	if not target_type.is_empty():
		row.add_child(_make_texture_rect(_unit_icon(target_type), ICON_UNIT))

	var captured: Dictionary = entry.duplicate(true)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect_entry(captured, card)
			card.accept_event()
	)
	_list.add_child(card)

func _headline(entry: Dictionary) -> String:
	var turn := int(entry.get("turn", 0))
	var caster := String(entry.get("caster_summary", ""))
	var action_label := _action_label(String(entry.get("action_id", "")))
	var target := String(entry.get("target_summary", ""))
	var parts: PackedStringArray = []
	if turn > 0:
		parts.append("T%d" % turn)
	if not caster.is_empty():
		parts.append(caster)
	if not action_label.is_empty():
		parts.append(action_label)
	if not target.is_empty():
		parts.append("→ %s" % target)
	return " ".join(parts)

func _action_label(action_id: String) -> String:
	if action_id.is_empty():
		return ""
	if action_id == "pass":
		return "Wait"
	if action_id == "end_turn":
		return "End turn"
	var def: ActionDefinition = ActionDefs.get_def(action_id)
	if def:
		return def.display_name
	return action_id

func _action_icon(action_id: String) -> Texture2D:
	if action_id == "pass":
		return ICON_WAIT
	if action_id == "end_turn":
		return ICON_END_TURN
	var def: ActionDefinition = ActionDefs.get_def(action_id)
	if def and def.icon:
		return def.icon
	return null

func _unit_icon(unit_type: String) -> Texture2D:
	if unit_type.is_empty():
		return null
	var def: UnitDefinition = UnitDefs.get_def(unit_type)
	return def.icon if def else null

func _make_texture_rect(tex: Texture2D, min_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = min_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = tex
	rect.modulate = Color(1, 1, 1, 1 if tex else 0.25)
	return rect

func _card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = CARD_RADIUS
	sb.corner_radius_top_right = CARD_RADIUS
	sb.corner_radius_bottom_left = CARD_RADIUS
	sb.corner_radius_bottom_right = CARD_RADIUS
	return sb

func _inspect_entry(entry: Dictionary, control: Control) -> void:
	if _tooltip == null:
		return
	var content := TooltipContent.new()
	content.title = _action_label(String(entry.get("action_id", "Event")))
	content.icon = _action_icon(String(entry.get("action_id", "")))
	var body_lines: PackedStringArray = []
	var caster := String(entry.get("caster_summary", ""))
	var target := String(entry.get("target_summary", ""))
	var result := String(entry.get("result_summary", ""))
	if not caster.is_empty():
		body_lines.append("Caster: %s" % caster)
	if not target.is_empty():
		body_lines.append("Target: %s" % target)
	if not result.is_empty():
		body_lines.append("Result: %s" % result)
	content.body = "\n".join(body_lines) if not body_lines.is_empty() else "Battle event."
	content.footer = "Turn %d · %s" % [int(entry.get("turn", 0)), String(entry.get("team", ""))]
	_tooltip.show_for_control(control, content)

func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
