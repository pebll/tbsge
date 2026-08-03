class_name TooltipPopup
extends PanelContainer

signal keyword_inspect_requested(keyword_id: String)
signal dismiss_requested

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_CHIP_BG := Color(0.93, 0.89, 0.82)
const BORDER_THICK := 4
const RADIUS := 16

var _title: Label
var _body: Label
var _footer: Label
var _icon: TextureRect
var _keywords_row: HBoxContainer
var _header_row: HBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_style()
	hide()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_header_row)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.hide()
	_header_row.add_child(_icon)

	_title = Label.new()
	_title.add_theme_color_override("font_color", COLOR_TEXT)
	_title.add_theme_font_size_override("font_size", 26)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_row.add_child(_title)

	_body = Label.new()
	_body.add_theme_color_override("font_color", COLOR_TEXT)
	_body.add_theme_font_size_override("font_size", 18)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(_body)

	_keywords_row = HBoxContainer.new()
	_keywords_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_keywords_row)

	_footer = Label.new()
	_footer.add_theme_color_override("font_color", Color(0.35, 0.30, 0.26))
	_footer.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_footer)

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

func present(content: TooltipContent) -> void:
	if content == null:
		hide()
		return
	_title.text = content.title
	_body.text = content.body
	_footer.text = content.footer
	_footer.visible = not content.footer.is_empty()
	if content.icon:
		_icon.texture = content.icon
		_icon.show()
	else:
		_icon.hide()
	_rebuild_keywords(content.keywords)
	show()

func _rebuild_keywords(keyword_ids: Array[String]) -> void:
	for child in _keywords_row.get_children():
		child.queue_free()
	_keywords_row.visible = not keyword_ids.is_empty()
	for kid in keyword_ids:
		var chip := Button.new()
		chip.text = KeywordDefs.get_label(kid)
		chip.focus_mode = Control.FOCUS_NONE
		chip.mouse_default_cursor_shape = Control.CURSOR_HELP
		_style_chip(chip)
		var captured := kid
		chip.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				keyword_inspect_requested.emit(captured)
				chip.accept_event()
		)
		chip.pressed.connect(func() -> void:
			keyword_inspect_requested.emit(captured)
		)
		_keywords_row.add_child(chip)

func _style_chip(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_CHIP_BG
	sb.border_color = COLOR_BORDER
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.95, 0.91, 0.84)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", 14)
