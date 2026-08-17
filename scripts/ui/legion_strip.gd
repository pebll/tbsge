class_name LegionStrip
extends Control

## Compact battle legion HUD: 6×2 size-grid under the action bar.
## Chrome matches UiTheme parchment panels; team color = fat outer border only.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiStatIcons = preload("res://scripts/ui/ui_stat_icons.gd")
const UnitFootprintScript = preload("res://scripts/ui/interact/unit_footprint.gd")

const CELL_PX := 96.0
const BOARD_W := 6.0
const BOARD_H := 2.0
const BOARD_PX := Vector2(BOARD_W * CELL_PX, BOARD_H * CELL_PX)
const BOARD_INSET := 6.0
const AGG_GAP := 10.0
const BOTTOM_MARGIN := 48.0
const TEAM_BORDER := 8

var _root: VBoxContainer
var _agg_panel: PanelContainer
var _agg_row: HBoxContainer
var _board_panel: PanelContainer
var _board: Control
var _units_layer: Control
var _policy: UiTooltipPolicy
var _hover_tooltip: UiHoverTooltip
var _cells: Dictionary = {} ## Unit -> LegionUnitCell
var _legion: Legion = null
var _sticky: bool = false
var _settings_connected := false
var _placements: Array = []

func _ready() -> void:
	name = "LegionStrip"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_layout_anchors()
	_policy = UiTooltipPolicy.new()
	_policy.configure(
		func(source: Object, payload) -> void:
			_show_unit_tooltip(source, payload),
		func(_source: Object) -> void:
			if _hover_tooltip:
				_hover_tooltip.dismiss()
	)
	if not _settings_connected and GameSettings:
		GameSettings.settings_changed.connect(_on_settings_changed)
		_settings_connected = true
	hide()

func hide_strip() -> void:
	_sticky = false
	_legion = null
	_placements.clear()
	_clear_cells()
	if _policy:
		_policy.clear()
	if _hover_tooltip:
		_hover_tooltip.dismiss()
	hide()

func show_legion(legion: Legion, sticky: bool = false) -> void:
	if legion == null or legion.units.is_empty():
		hide_strip()
		return
	if visible and _sticky and not sticky:
		return
	var was_visible := visible
	_legion = legion
	_sticky = sticky
	_render()
	show()
	if not was_visible:
		UiTheme.juice_pop_in(self, UiTheme.INTERACT_ENTRY_DURATION)

func is_showing_legion(legion: Legion) -> bool:
	return visible and _legion == legion

func current_legion() -> Legion:
	return _legion

func is_sticky() -> bool:
	return _sticky

func apply_unit_vitals_fx(unit: Unit, hp: float, shield: float) -> void:
	if not visible or not _cells.has(unit):
		return
	var cell: LegionUnitCell = _cells[unit]
	cell.apply_vitals(hp, shield, true)

func refresh_if_legion(legion: Legion) -> void:
	if not visible or _legion != legion or legion == null:
		return
	_render()

func _layout_anchors() -> void:
	var total_h := _estimate_height()
	var total_w := BOARD_PX.x + float(TEAM_BORDER * 2) + BOARD_INSET * 2.0 + 8.0
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -total_w * 0.5
	offset_right = total_w * 0.5
	offset_bottom = -BOTTOM_MARGIN
	offset_top = -BOTTOM_MARGIN - total_h
	custom_minimum_size = Vector2(total_w, total_h)

func _estimate_height() -> float:
	return 44.0 + AGG_GAP + BOARD_PX.y + float(TEAM_BORDER * 2) + BOARD_INSET * 2.0

func _build() -> void:
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", int(AGG_GAP))
	_root.alignment = BoxContainer.ALIGNMENT_END
	add_child(_root)

	_agg_panel = PanelContainer.new()
	_agg_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_agg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_agg_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, 12, UiTheme.BORDER_THICK, 10)
	)
	_root.add_child(_agg_panel)

	_agg_row = HBoxContainer.new()
	_agg_row.add_theme_constant_override("separation", 16)
	_agg_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_agg_panel.add_child(_agg_row)

	_board_panel = PanelContainer.new()
	_board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", int(BOARD_INSET))
	board_margin.add_theme_constant_override("margin_right", int(BOARD_INSET))
	board_margin.add_theme_constant_override("margin_top", int(BOARD_INSET))
	board_margin.add_theme_constant_override("margin_bottom", int(BOARD_INSET))
	_board_panel.add_child(board_margin)

	_board = Control.new()
	_board.custom_minimum_size = BOARD_PX
	_board.size = BOARD_PX
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	board_margin.add_child(_board)

	_units_layer = Control.new()
	_units_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_units_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_units_layer)

	_hover_tooltip = UiHoverTooltip.new()
	add_child(_hover_tooltip)

	_apply_board_chrome(UiTheme.COLOR_BORDER)

func _render() -> void:
	if _legion == null:
		return
	_apply_team_chrome(_legion.team_id)
	_rebuild_aggregates(_legion)
	_rebuild_cells()
	_layout_anchors()

func _rebuild_aggregates(legion: Legion) -> void:
	for child in _agg_row.get_children():
		child.queue_free()
	var hp := 0.0
	var shield := 0.0
	var atk := 0.0
	var ranged := 0.0
	var any_ranged := false
	for u in legion.units:
		if u == null:
			continue
		hp += u.current_health
		shield += float(u.shield_remaining)
		atk += u.attack
		if u.has_ranged():
			any_ranged = true
			ranged += u.ranged_attack
	_agg_row.add_child(UiStatIcons.make_row(UiStatIcons.ICON_HEALTH, "%d" % int(round(hp)), 26, 20, 6))
	if shield > 0.0:
		_agg_row.add_child(UiStatIcons.make_row(UiStatIcons.ICON_SHIELD, "%d" % int(round(shield)), 26, 20, 6))
	_agg_row.add_child(UiStatIcons.make_row(UiStatIcons.ICON_ATTACK, "%d" % int(round(atk)), 26, 20, 6))
	if any_ranged:
		_agg_row.add_child(UiStatIcons.make_row(UiStatIcons.ICON_BOW, "%d" % int(round(ranged)), 26, 20, 6))

func _rebuild_cells() -> void:
	_clear_cells()
	var sizes: Array = []
	var units: Array[Unit] = []
	for u in _legion.units:
		if u == null:
			continue
		var sz := u.definition.size if u.definition else 1.0
		sizes.append(sz)
		units.append(u)
	_placements = UnitFootprintScript.pack(sizes)
	if _placements.is_empty() and not sizes.is_empty():
		_placements = _fallback_placements(sizes)
	for i in range(mini(units.size(), _placements.size())):
		var cell := LegionUnitCell.new()
		_units_layer.add_child(cell)
		var u: Unit = units[i]
		var captured: Unit = u
		cell.setup(
			u,
			_legion,
			_placements[i],
			CELL_PX,
			_policy,
			func(_source: Object) -> Dictionary:
				return _unit_tooltip_payload_for(captured)
		)
		_cells[u] = cell

func _fallback_placements(sizes: Array) -> Array:
	var out: Array = []
	var x := 0.0
	for s in sizes:
		var fp := UnitFootprintScript.footprint(float(s))
		if fp == Vector2.ZERO:
			fp = Vector2(1, 1)
		out.append({"size": float(s), "pos": Vector2(x, 0.0), "footprint": fp})
		x += fp.x
		if x >= UnitFootprintScript.BOARD.x - 0.001:
			x = 0.0
	return out

func _clear_cells() -> void:
	for key in _cells.keys():
		var cell: Node = _cells[key]
		if is_instance_valid(cell):
			cell.queue_free()
	_cells.clear()
	if _units_layer:
		for child in _units_layer.get_children():
			child.queue_free()

func _apply_team_chrome(team_id: String) -> void:
	var accent := UiTheme.COLOR_BORDER
	var team_res: Resource = TeamDefs.get_def(team_id)
	if team_res is TeamDefinition:
		accent = (team_res as TeamDefinition).color
	_apply_board_chrome(accent)

func _apply_board_chrome(border: Color) -> void:
	_board_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, border, UiTheme.RADIUS, TEAM_BORDER, 0)
	)

func _unit_tooltip_payload_for(u: Unit) -> Dictionary:
	if u == null:
		return {}
	var def: UnitDefinition = u.definition
	var title := def.display_name if def and not def.display_name.is_empty() else u.unit_type
	return {
		"title": title,
		"rows": UiStatIcons.unit_stat_rows(u, _legion),
	}

func _show_unit_tooltip(source: Object, payload) -> void:
	if payload == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = payload
	if data.is_empty() or _hover_tooltip == null:
		return
	var title := String(data.get("title", ""))
	if data.has("rows"):
		_hover_tooltip.present_stat_rows(title, data.get("rows", []), source as Control)
	else:
		_hover_tooltip.present(title, String(data.get("body", "")), source as Control)

func _on_settings_changed() -> void:
	for key in _cells.keys():
		var cell: LegionUnitCell = _cells[key]
		if cell:
			cell.set_hp_style(GameSettings.legion_strip_hp_style)
	if visible and _legion:
		_rebuild_aggregates(_legion)
