class_name UiHoverTooltip
extends Control

## Lightweight hover tooltip host used by UiTooltipPolicy (not right-click inspect).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiStatIcons = preload("res://scripts/ui/ui_stat_icons.gd")

var _panel: PanelContainer
var _title: Label
var _body: Label
var _stats_box: VBoxContainer
var _anchor: Control = null

func _ready() -> void:
	name = "UiHoverTooltip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	top_level = true
	hide()
	_build()

func present(title: String, body: String = "", anchor: Control = null) -> void:
	await _present_internal(title, body, [], anchor)

func present_stat_rows(title: String, rows: Array, anchor: Control = null) -> void:
	await _present_internal(title, "", rows, anchor)

func _present_internal(title: String, body: String, rows: Array, anchor: Control) -> void:
	if _panel == null:
		_build()
	_anchor = anchor
	_title.text = title
	if rows.is_empty():
		_body.text = body
		_body.visible = not body.is_empty()
		_stats_box.visible = false
	else:
		_body.visible = false
		_stats_box.visible = true
		UiStatIcons.populate_stat_vbox(
			_stats_box,
			rows,
			UiStatIcons.TOOLTIP_ICON_PX,
			UiStatIcons.TOOLTIP_FONT_SIZE
		)
	_panel.show()
	show()
	await get_tree().process_frame
	if not visible:
		return
	_place()
	UiTheme.juice_pop_in(_panel, 0.1)

func dismiss() -> void:
	_anchor = null
	hide()

func _build() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(
		"panel",
		UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, UiTheme.RADIUS, UiTheme.BORDER_THICK, 14)
	)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	_title.add_theme_font_size_override("font_size", UiStatIcons.TOOLTIP_TITLE_FONT_SIZE)
	vbox.add_child(_title)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	_stats_box.visible = false
	vbox.add_child(_stats_box)

	_body = Label.new()
	_body.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_MUTED)
	_body.add_theme_font_size_override("font_size", 18)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(_body)

func _place() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var pos := get_global_mouse_position() + Vector2(14, 14)
	if _anchor and is_instance_valid(_anchor):
		var rect := _anchor.get_global_rect()
		pos = Vector2(
			rect.position.x + rect.size.x * 0.5 - _panel.size.x * 0.5,
			rect.position.y - _panel.size.y - 10.0
		)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, viewport_size.x - _panel.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, viewport_size.y - _panel.size.y - 8.0))
	global_position = pos
