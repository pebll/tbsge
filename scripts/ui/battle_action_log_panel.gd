class_name BattleActionLogPanel
extends PanelContainer

## Left-side Hearthstone-style action log. Newest entries at the bottom.

const COLOR_BG := Color(0.91, 0.86, 0.78, 0.94)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_MUTED := Color(0.40, 0.35, 0.30)
const BORDER_THICK := 4
const RADIUS := 16
const MAX_VISIBLE_HINT := 80

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
	offset_right = 340
	offset_bottom = 520
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
	if not visible:
		# Still keep rows if hidden so reopen stays in sync when using bind_log later.
		pass
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
	_list.add_theme_constant_override("separation", 6)
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
	var row := Label.new()
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_theme_font_size_override("font_size", 15)
	row.text = _format_line(entry)
	row.tooltip_text = "Right-click to inspect"
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var captured: Dictionary = entry.duplicate(true)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect_entry(captured, row)
			row.accept_event()
	)
	_list.add_child(row)

func _format_line(entry: Dictionary) -> String:
	var caster := String(entry.get("caster_summary", ""))
	var action_id := String(entry.get("action_id", ""))
	var action_label := _action_label(action_id)
	var target := String(entry.get("target_summary", ""))
	var result := String(entry.get("result_summary", ""))
	var turn := int(entry.get("turn", 0))
	var parts: PackedStringArray = []
	if turn > 0:
		parts.append("T%d" % turn)
	if not caster.is_empty():
		parts.append(caster)
	if not action_label.is_empty():
		parts.append(action_label)
	if not target.is_empty():
		parts.append("→ %s" % target)
	if not result.is_empty():
		parts.append("(%s)" % result)
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

func _inspect_entry(entry: Dictionary, control: Control) -> void:
	if _tooltip == null:
		return
	var content := TooltipContent.new()
	content.title = _action_label(String(entry.get("action_id", "Event")))
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
