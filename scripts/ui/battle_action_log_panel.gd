class_name BattleActionLogPanel
extends Control

## Full-height left dock. Fat icon/number cards; coords text only for moves.
## Toggle button stays on the left edge to pop the dock in/out.
## Combat/heal/teleport lines wait in a pending queue until reveal_pending().

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const COLOR_BG := Color(UiTheme.COLOR_PANEL, 0.96)
const COLOR_BORDER := UiTheme.COLOR_BORDER
const COLOR_CARD_BG := UiTheme.COLOR_CARD
const COLOR_ACTION_WELL := UiTheme.COLOR_PRESSED
const COLOR_TEXT := UiTheme.COLOR_TEXT
const COLOR_HEAL := Color(0.18, 0.52, 0.28)
const COLOR_WIPE := Color(0.78, 0.12, 0.12)
const BORDER_THICK := UiTheme.BORDER_THICK
const RADIUS := 14
const CARD_RADIUS := 14
const DOCK_WIDTH := 540.0
const TOGGLE_WIDTH := 40.0
const CARD_MIN_HEIGHT := 108.0
const BANNER_WIDTH := 10.0
const ICON_UNIT := Vector2(84, 84)
const ICON_ACTION := Vector2(52, 52)
const ICON_STAT := Vector2(42, 42)

const ICON_WAIT := preload("res://assets/icons/base_icons_sprites/boot.png")
const ICON_END_TURN := preload("res://assets/icons/base_icons_sprites/strong.png")
const ICON_DAMAGE := preload("res://assets/icons/base_icons_sprites/damage.png")
const ICON_DEATH := preload("res://assets/icons/base_icons_sprites/skull.png")
const ICON_HEAL := preload("res://assets/icons/base_icons_sprites/heart.png")

var _dock: PanelContainer
var _header: VBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _toggle_btn: Button
var _tooltip: TooltipController = null
var _bound_log: BattleActionLog = null
var _pending: Array[Dictionary] = []
var _expanded: bool = true
var _battle_mode: bool = false
var _dock_tween: Tween

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
	if not GameSettings.settings_changed.is_connected(_on_settings_changed):
		GameSettings.settings_changed.connect(_on_settings_changed)

func set_tooltip_controller(controller: TooltipController) -> void:
	_tooltip = controller

func enter_battle(action_log: BattleActionLog = null) -> void:
	_battle_mode = true
	_pending.clear()
	show()
	clear_entries()
	if action_log:
		bind_log(action_log)
	_set_expanded(true)
	if _dock:
		UiTheme.juice_pop_in(_dock, 0.14)

func exit_battle() -> void:
	_battle_mode = false
	_pending.clear()
	_bound_log = null
	clear_entries()
	_set_expanded(false)
	hide()

func bind_log(action_log: BattleActionLog) -> void:
	_bound_log = action_log
	_rebuild_visible_entries()

func clear_entries() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()

## Hosts call this for live EventBus entries. Combat lines may queue.
func receive_entry(entry: Dictionary) -> void:
	if not _battle_mode or entry.is_empty():
		return
	if not _is_visible(entry):
		return
	if BattleActionLog.should_defer_ui(entry):
		_pending.append(entry)
		return
	append_entry(entry)

## Flush deferred combat/heal/teleport lines after playback finishes.
func reveal_pending() -> void:
	if not _battle_mode:
		_pending.clear()
		return
	for entry in _pending:
		if _is_visible(entry):
			append_entry(entry)
	_pending.clear()

func append_entry(entry: Dictionary) -> void:
	if not _battle_mode:
		return
	if not _is_visible(entry):
		return
	_add_entry_row(entry, true)
	_scroll_to_bottom()

func is_expanded() -> bool:
	return _expanded

func _on_settings_changed() -> void:
	if _battle_mode:
		_rebuild_visible_entries()

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
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	_dock.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", 4)
	root.add_child(_header)

	var title := Label.new()
	title.text = "Battle log"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 22)
	_header.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_list)

	_toggle_btn = Button.new()
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.custom_minimum_size = Vector2(TOGGLE_WIDTH, 88)
	_toggle_btn.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_toggle_btn.offset_left = DOCK_WIDTH
	_toggle_btn.offset_right = DOCK_WIDTH + TOGGLE_WIDTH
	_toggle_btn.offset_top = -44
	_toggle_btn.offset_bottom = 44
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
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	_toggle_btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = UiTheme.COLOR_HOVER
	var pressed := sb.duplicate()
	pressed.bg_color = UiTheme.COLOR_PRESSED
	_toggle_btn.add_theme_stylebox_override("hover", hover)
	_toggle_btn.add_theme_stylebox_override("pressed", pressed)
	_toggle_btn.add_theme_stylebox_override("hover_pressed", pressed)
	_toggle_btn.add_theme_stylebox_override("focus", sb)
	_toggle_btn.add_theme_color_override("font_color", COLOR_TEXT)
	_toggle_btn.add_theme_color_override("font_hover_color", COLOR_TEXT)
	_toggle_btn.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	_toggle_btn.add_theme_font_size_override("font_size", 26)

func _on_toggle_pressed() -> void:
	UiTheme.juice_press(_toggle_btn)
	_set_expanded(not _expanded)

func _rebuild_visible_entries() -> void:
	clear_entries()
	if _bound_log == null:
		return
	for entry in _bound_log.entries:
		if _is_visible(entry) and not _is_still_pending(entry):
			_add_entry_row(entry, false)
	_scroll_to_bottom()

func _is_still_pending(entry: Dictionary) -> bool:
	for pending in _pending:
		if pending == entry:
			return true
	return false

func _is_visible(entry: Dictionary) -> bool:
	if _bound_log:
		return _bound_log.is_entry_visible(entry)
	var action_id := String(entry.get("action_id", ""))
	if (
		action_id in ["move", "swap", "teleport"]
		or bool(entry.get("show_coords", false))
	):
		return GameSettings.show_battle_log_moves
	if action_id == "end_turn":
		return GameSettings.show_battle_log_end_turns
	return true

func _set_expanded(expanded: bool) -> void:
	if _expanded == expanded and _dock != null and _dock.visible == expanded:
		_apply_toggle_chrome(expanded)
		return
	_expanded = expanded
	_apply_toggle_chrome(expanded)
	if _dock_tween and _dock_tween.is_running():
		_dock_tween.kill()
	if expanded:
		_dock.visible = true
		_dock.pivot_offset = Vector2(0, maxf(_dock.size.y, 1.0) * 0.5)
		_dock_tween = UiTheme.juice_pop_in(_dock, 0.12)
	else:
		_dock.pivot_offset = Vector2(0, maxf(_dock.size.y, 1.0) * 0.5)
		_dock_tween = UiTheme.juice_pop_out(_dock, 0.11)
		if _dock_tween:
			_dock_tween.finished.connect(func() -> void:
				if not _expanded:
					_dock.visible = false
					_dock.scale = Vector2.ONE
					_dock.modulate.a = 1.0
			, CONNECT_ONE_SHOT)

func _apply_toggle_chrome(expanded: bool) -> void:
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

func _add_entry_row(entry: Dictionary, animate: bool = false) -> void:
	if _list == null or entry.is_empty():
		return

	var caster_team := String(entry.get("caster_team_id", entry.get("team", "")))
	var target_team := String(entry.get("target_team_id", ""))
	if target_team.is_empty():
		target_team = caster_team

	# Composite card: rounded team caps + center body (avoids ColorRect poking past corners).
	var card := HBoxContainer.new()
	card.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "Right-click to inspect"

	card.add_child(_make_banner_cap(caster_team, true))
	var body := PanelContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", _card_body_stylebox())
	card.add_child(body)
	card.add_child(_make_banner_cap(target_team, false))

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	body.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var action_id := String(entry.get("action_id", ""))
	var caster_type := String(entry.get("caster_unit_type", ""))
	var target_type := String(entry.get("target_unit_type", ""))
	var healed := int(entry.get("healed_total", 0))

	row.add_child(_make_side_block(
		caster_type,
		int(entry.get("caster_hp_lost", 0)),
		int(entry.get("caster_deaths", 0)),
		bool(entry.get("caster_wiped", false)),
		healed if action_id == "self_heal" else 0
	))

	row.add_child(_make_action_well(action_id, entry))

	var target_hp := int(entry.get("target_hp_lost", 0))
	var target_deaths := int(entry.get("target_deaths", 0))
	var target_wiped := bool(entry.get("target_wiped", false))
	var has_target := (
		not target_type.is_empty()
		or target_hp > 0
		or target_deaths > 0
		or target_wiped
		or (healed > 0 and action_id == "heal_ally")
	)
	if has_target:
		row.add_child(_make_side_block(
			target_type,
			target_hp,
			target_deaths,
			target_wiped,
			healed if action_id == "heal_ally" else 0
		))
	elif bool(entry.get("show_coords", false)):
		row.add_child(_make_empty_side_spacer())

	var captured: Dictionary = entry.duplicate(true)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect_entry(captured, card)
			card.accept_event()
	)
	_list.add_child(card)
	if animate:
		card.modulate.a = 0.0
		card.scale = Vector2(0.92, 0.82)
		call_deferred("_juice_card_in", card)

func _juice_card_in(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	UiTheme.juice_pop_in(card, 0.13)

func _make_banner_cap(team_id: String, left_side: bool) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.custom_minimum_size = Vector2(BANNER_WIDTH, CARD_MIN_HEIGHT)
	cap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", _banner_cap_stylebox(team_id, left_side))
	return cap
func _banner_cap_stylebox(team_id: String, left_side: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _team_color(team_id)
	sb.border_color = COLOR_BORDER
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	if left_side:
		sb.border_width_left = 3
		sb.border_width_right = 0
		sb.corner_radius_top_left = CARD_RADIUS
		sb.corner_radius_bottom_left = CARD_RADIUS
		sb.corner_radius_top_right = 0
		sb.corner_radius_bottom_right = 0
	else:
		sb.border_width_left = 0
		sb.border_width_right = 3
		sb.corner_radius_top_left = 0
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_top_right = CARD_RADIUS
		sb.corner_radius_bottom_right = CARD_RADIUS
	return sb

func _team_color(team_id: String) -> Color:
	if team_id.is_empty():
		return COLOR_BORDER
	var team_res: Resource = TeamDefs.get_def(team_id)
	if team_res is TeamDefinition:
		return (team_res as TeamDefinition).color
	return COLOR_BORDER

func _make_side_block(
	unit_type: String,
	hp_lost: int,
	deaths: int,
	wiped: bool = false,
	healed: int = 0
) -> Control:
	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", 10)
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	block.add_child(_make_unit_portrait(unit_type, wiped))
	block.add_child(_make_side_stats(hp_lost, deaths, healed))
	return block

func _make_unit_portrait(unit_type: String, wiped: bool) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = ICON_UNIT

	var portrait := _make_texture_rect(_unit_icon(unit_type), ICON_UNIT)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if wiped:
		portrait.modulate = Color(0.55, 0.55, 0.55, 0.85)
	wrap.add_child(portrait)

	if wiped:
		var mark := Label.new()
		mark.text = "✕"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mark.add_theme_color_override("font_color", COLOR_WIPE)
		mark.add_theme_font_size_override("font_size", 64)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(mark)

	return wrap

func _make_action_well(action_id: String, entry: Dictionary) -> Control:
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(96, 88)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_ACTION_WELL
	sb.border_color = COLOR_BORDER
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	well.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	well.add_child(vbox)

	var icon_wrap := CenterContainer.new()
	icon_wrap.add_child(_make_texture_rect(_action_icon(action_id), ICON_ACTION))
	vbox.add_child(icon_wrap)

	if bool(entry.get("show_coords", false)):
		var coord := Label.new()
		coord.text = String(entry.get("coord_text", ""))
		coord.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coord.add_theme_color_override("font_color", COLOR_TEXT)
		coord.add_theme_font_size_override("font_size", 20)
		vbox.add_child(coord)

	return well

func _make_empty_side_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(ICON_UNIT.x + 40, ICON_UNIT.y)
	return spacer

func _make_side_stats(hp_lost: int, deaths: int, healed: int = 0) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if healed > 0:
		box.add_child(_make_stat_chip(ICON_HEAL, healed, COLOR_HEAL))
	if hp_lost > 0:
		box.add_child(_make_stat_chip(ICON_DAMAGE, hp_lost, COLOR_TEXT))
	if deaths > 0:
		box.add_child(_make_stat_chip(ICON_DEATH, deaths, COLOR_TEXT))
	if box.get_child_count() == 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(ICON_STAT.x + 28, ICON_STAT.y)
		box.add_child(spacer)
	return box

func _make_stat_chip(icon: Texture2D, value: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_make_texture_rect(icon, ICON_STAT))
	var label := Label.new()
	label.text = str(value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 34)
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

func _card_body_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
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
	if bool(entry.get("caster_wiped", false)):
		body_lines.append("Caster legion wiped")
	if bool(entry.get("target_wiped", false)):
		body_lines.append("Target legion wiped")
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
