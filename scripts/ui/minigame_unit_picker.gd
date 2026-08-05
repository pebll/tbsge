class_name MinigameUnitPicker
extends Control

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

signal unit_selected(unit_type: String)
signal unit_inspected(unit_type: String)
signal cancelled

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_BLOCK_BG := Color(0.93, 0.89, 0.82)
const BORDER_THICK := 4
const RADIUS := 16
const ICON_GOLD := preload("res://assets/icons/base_icons_sprites/coin.png")

@onready var grid: GridContainer = %UnitGrid
@onready var title_label: Label = %TitleLabel
@onready var cancel_button: GameButton = %CancelButton
@onready var panel: PanelContainer = %PickerPanel

func _ready() -> void:
	_apply_style()
	cancel_button.pressed.connect(func(): _close(false))
	_build_cards()
	hide()

func _apply_style() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = COLOR_BG
	panel_sb.border_color = COLOR_BORDER
	panel_sb.border_width_left = BORDER_THICK
	panel_sb.border_width_right = BORDER_THICK
	panel_sb.border_width_top = BORDER_THICK
	panel_sb.border_width_bottom = BORDER_THICK
	panel_sb.corner_radius_top_left = RADIUS
	panel_sb.corner_radius_top_right = RADIUS
	panel_sb.corner_radius_bottom_left = RADIUS
	panel_sb.corner_radius_bottom_right = RADIUS
	panel_sb.content_margin_left = 28
	panel_sb.content_margin_right = 28
	panel_sb.content_margin_top = 24
	panel_sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_sb)

	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 34)

func _build_cards() -> void:
	var db: UnitDatabase = load("res://data/unit_db.tres")
	if db == null:
		return
	var defs: Array = []
	for def in db.defs:
		if def != null:
			defs.append(def)
	defs.sort_custom(func(a: UnitDefinition, b: UnitDefinition) -> bool:
		if a.price != b.price:
			return a.price < b.price
		return a.display_name < b.display_name
	)
	for def in defs:
		grid.add_child(_build_card(def))

func _build_card(def: UnitDefinition) -> Control:
	var card := PanelContainer.new()
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
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(148, 168)
	card.tooltip_text = "%s — left-click to place, right-click to inspect" % def.display_name

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(108, 108)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = def.icon
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 4)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost := Label.new()
	cost.text = str(def.price)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 22)
	cost.add_theme_color_override("font_color", COLOR_TEXT)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(cost)
	var gold_icon := TextureRect.new()
	gold_icon.texture = ICON_GOLD
	gold_icon.custom_minimum_size = Vector2(22, 22)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(gold_icon)
	vbox.add_child(cost_row)

	# Flat overlay catches left/right clicks without blocking layout.
	var hit := Control.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_pressed(def.id)
			hit.accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			unit_inspected.emit(def.id)
			hit.accept_event()
	)
	card.add_child(hit)

	return card

func open_for_slot(coords: Vector2i) -> void:
	title_label.text = "Choose unit for (%d, %d)" % [coords.x, coords.y]
	show()

func _on_card_pressed(unit_type: String) -> void:
	_close(true, unit_type)

func _close(selected: bool, unit_type: String = "") -> void:
	hide()
	if selected:
		unit_selected.emit(unit_type)
	else:
		cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close(false)
		get_viewport().set_input_as_handled()
