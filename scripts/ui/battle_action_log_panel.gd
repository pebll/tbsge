class_name BattleActionLogPanel
extends Control

## Full-height left dock. Icon/number-first cards; coords text only for moves.
## Toggle button stays on the left edge to pop the dock in/out.

const COLOR_BG := Color(0.91, 0.86, 0.78, 0.96)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_CARD_BG := Color(0.93, 0.89, 0.82)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_MUTED := Color(0.40, 0.35, 0.30)
const BORDER_THICK := 4
const RADIUS := 12
const CARD_RADIUS := 10
const DOCK_WIDTH := 460.0
const TOGGLE_WIDTH := 36.0
const ICON_UNIT := Vector2(48, 48)
const ICON_ACTION := Vector2(32, 32)
const ICON_STAT := Vector2(22, 22)

const ICON_WAIT := preload("res://assets/icons/base_icons_sprites/boot.png")
const ICON_END_TURN := preload("res://assets/icons/base_icons_sprites/strong.png")
const ICON_DAMAGE := preload("res://assets/icons/base_icons_sprites/damage.png")
const ICON_DEATH := preload("res://assets/icons/base_icons_sprites/skull.png")
const ICON_HEAL := preload("res://assets/icons/base_icons_sprites/heart.png")

var _dock: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _toggle_btn: Button
var _tooltip: TooltipController = null
var _expanded: bool = true
var _battle_mode: bool = false

func _ready() -> void:
	name = "BattleActionLogPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 0
	offset_top = 0
	offset_right = DOCK_WIDTH + TOGGLE_WIDTH
	offset_bottom = 0
	_build()
	_apply_dock_style()
	_set_expanded(false)
	hide()

func set_tooltip_controller(controller: TooltipController) -> void:
	_tooltip = controller

func enter_battle(action_log: BattleActionLog = null) -> void:
	_battle_mode = true
	show()
	clear_entries()
	if action_log:
		bind_log(action_log)
	_set_expanded(true)

func exit_battle() -> void:
	_battle_mode = false
	clear_entries()
	_set_expanded(false)
	hide()

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
	if not _battle_mode:
		return
	_add_entry_row(entry)
	_scroll_to_bottom()

func is_expanded() -> bool:
	return _expanded

func _build() -> void:
	_dock = PanelContainer.new()
	_dock.name = "Dock"
	_dock.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_dock.offset_left = 0
	_dock.offset_top = 0
	_dock.offset_right = DOCK_WIDTH
	_dock.offset_bottom = 0
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dock)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_dock.add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	_toggle_btn = Button.new()
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.custom_minimum_size = Vector2(TOGGLE_WIDTH, 72)
	_toggle_btn.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_toggle_btn.offset_left = DOCK_WIDTH
	_toggle_btn.offset_right = DOCK_WIDTH + TOGGLE_WIDTH
	_toggle_btn.offset_top = -36
	_toggle_btn.offset_bottom = 36
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	_style_toggle_button()
	add_child(_toggle_btn)

func _apply_dock_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_right = BORDER_THICK
	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sb.border_width_left = 0
	sb.corner_radius_top_right = RADIUS
	sb.corner_radius_bottom_right = RADIUS
	_dock.add_theme_stylebox_override("panel", sb)

func _style_toggle_button() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = 0
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	_toggle_btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.95, 0.91, 0.84)
	_toggle_btn.add_theme_stylebox_override("hover", hover)
	_toggle_btn.add_theme_stylebox_override("pressed", hover)
	_toggle_btn.add_theme_color_override("font_color", COLOR_TEXT)
	_toggle_btn.add_theme_font_size_override("font_size", 22)

func _on_toggle_pressed() -> void:
	_set_expanded(not _expanded)

func _set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_dock.visible = expanded
	_toggle_btn.text = "‹" if expanded else "›"
	_toggle_btn.tooltip_text = "Hide battle log" if expanded else "Show battle log"
	if expanded:
		_toggle_btn.offset_left = DOCK_WIDTH
		_toggle_btn.offset_right = DOCK_WIDTH + TOGGLE_WIDTH
		offset_right = DOCK_WIDTH + TOGGLE_WIDTH
	else:
		_toggle_btn.offset_left = 0
		_toggle_btn.offset_right = TOGGLE_WIDTH
		offset_right = TOGGLE_WIDTH

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
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var action_id := String(entry.get("action_id", ""))
	var caster_type := String(entry.get("caster_unit_type", ""))
	var target_type := String(entry.get("target_unit_type", ""))

	# Left side (caster)
	row.add_child(_make_texture_rect(_unit_icon(caster_type), ICON_UNIT))
	row.add_child(_make_side_stats(
		int(entry.get("caster_hp_lost", 0)),
		int(entry.get("caster_deaths", 0)),
		0
	))

	# Action
	row.add_child(_make_texture_rect(_action_icon(action_id), ICON_ACTION))

	# Move / teleport coords (only allowed prose-ish text besides numbers)
	if bool(entry.get("show_coords", false)):
		var coord := Label.new()
		coord.text = String(entry.get("coord_text", ""))
		coord.add_theme_color_override("font_color", COLOR_TEXT)
		coord.add_theme_font_size_override("font_size", 18)
		coord.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(coord)

	var healed := int(entry.get("healed_total", 0))
	if healed > 0:
		row.add_child(_make_stat_chip(ICON_HEAL, healed, Color(0.2, 0.55, 0.28)))

	var target_hp := int(entry.get("target_hp_lost", 0))
	var target_deaths := int(entry.get("target_deaths", 0))
	if not target_type.is_empty() or target_hp > 0 or target_deaths > 0:
		row.add_child(_make_texture_rect(_unit_icon(target_type), ICON_UNIT))
		row.add_child(_make_side_stats(target_hp, target_deaths, 0))

	var captured: Dictionary = entry.duplicate(true)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect_entry(captured, card)
			card.accept_event()
	)
	_list.add_child(card)

func _make_side_stats(hp_lost: int, deaths: int, _unused: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	if hp_lost > 0:
		box.add_child(_make_stat_chip(ICON_DAMAGE, hp_lost, COLOR_TEXT))
	if deaths > 0:
		box.add_child(_make_stat_chip(ICON_DEATH, deaths, COLOR_TEXT))
	if box.get_child_count() == 0:
		# Keep layout stable with a tiny spacer when no losses.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(8, ICON_STAT.y)
		box.add_child(spacer)
	return box

func _make_stat_chip(icon: Texture2D, value: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.add_child(_make_texture_rect(icon, ICON_STAT))
	var label := Label.new()
	label.text = str(value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row

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
	rect.modulate = Color(1, 1, 1, 1 if tex else 0.2)
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
	if not caster.is_empty():
		body_lines.append(caster)
	if not target.is_empty():
		body_lines.append("→ %s" % target)
	var caster_hp := int(entry.get("caster_hp_lost", 0))
	var caster_deaths := int(entry.get("caster_deaths", 0))
	var target_hp := int(entry.get("target_hp_lost", 0))
	var target_deaths := int(entry.get("target_deaths", 0))
	var healed := int(entry.get("healed_total", 0))
	if caster_hp > 0 or caster_deaths > 0:
		body_lines.append("Caster: −%d HP, %d fallen" % [caster_hp, caster_deaths])
	if target_hp > 0 or target_deaths > 0:
		body_lines.append("Target: −%d HP, %d fallen" % [target_hp, target_deaths])
	if healed > 0:
		body_lines.append("Healed +%d" % healed)
	if bool(entry.get("show_coords", false)):
		body_lines.append("Tile %s" % String(entry.get("coord_text", "")))
	content.body = "\n".join(body_lines) if not body_lines.is_empty() else "Battle event."
	content.footer = "Turn %d" % int(entry.get("turn", 0))
	_tooltip.show_for_control(control, content)

func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
