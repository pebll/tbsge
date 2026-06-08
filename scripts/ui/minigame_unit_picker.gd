class_name MinigameUnitPicker
extends Control

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

signal unit_selected(unit_type: String)
signal cancelled

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const COLOR_BLOCK_BG := Color(0.93, 0.89, 0.82)
const BORDER_THICK := 4
const RADIUS := 16

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
	for def in db.defs:
		if def == null:
			continue
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
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(180, 220)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(120, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = def.icon
	vbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(name_label)

	var info := Label.new()
	info.text = "%dg  •  %.1f size  •  max %d" % [
		def.price,
		def.size,
		MinigameRulesScript.max_units_in_legion(def.id),
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(info)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(func(): _on_card_pressed(def.id))
	card.add_child(btn)
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
