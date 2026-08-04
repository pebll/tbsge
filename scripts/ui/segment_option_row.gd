class_name SegmentOptionRow
extends VBoxContainer

## Exclusive segmented button row with optional hover tooltips.

signal selection_changed(id: String)

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameButtonScene = preload("res://scenes/ui/game_button.tscn")

var _label: Label
var _row: HBoxContainer
var _buttons: Dictionary = {} # id -> GameButton
var _selected_id: String = ""
var _button_width: int = 0
var _button_font_size: int = 20
var _button_height: int = 48

func _ready() -> void:
	if get_child_count() == 0:
		_ensure_structure()
	_apply_label_style()

func setup(title: String, options: Array, selected_id: String = "") -> void:
	_ensure_structure()
	_label.text = title
	_apply_label_style()

	for child in _row.get_children():
		child.queue_free()
	_buttons.clear()

	for opt in options:
		var id := String(opt.get("id", ""))
		if id.is_empty():
			continue
		var btn: GameButton = GameButtonScene.instantiate()
		btn.text = String(opt.get("text", id))
		btn.tooltip_text = String(opt.get("tooltip", ""))
		btn.font_size = _button_font_size
		btn.button_height = _button_height
		btn.hover_lift = 2.0
		btn.hover_scale = 1.02
		var opt_width := int(opt.get("width", 0))
		if opt_width > 0:
			btn.preferred_width = opt_width
		elif _button_width > 0:
			btn.preferred_width = _button_width
		else:
			btn.max_width = 160
		btn.pressed.connect(_on_button_pressed.bind(id))
		_row.add_child(btn)
		_buttons[id] = btn

	if selected_id.is_empty() and not options.is_empty():
		selected_id = String(options[0].get("id", ""))
	set_selected(selected_id, false)

func configure_buttons(width: int = 0, font_size: int = 20, height: int = 48) -> void:
	_button_width = width
	_button_font_size = font_size
	_button_height = height

func get_selected() -> String:
	return _selected_id

func set_selected(id: String, emit_change: bool = true) -> void:
	if not _buttons.has(id) and not _buttons.is_empty():
		return
	_selected_id = id
	for btn_id in _buttons:
		var btn: GameButton = _buttons[btn_id]
		btn.selected = (btn_id == id)
	if emit_change:
		selection_changed.emit(id)

func _ensure_structure() -> void:
	if _label != null:
		return
	add_theme_constant_override("separation", 8)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)

func _apply_label_style() -> void:
	if _label == null:
		return
	_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	_label.add_theme_font_size_override("font_size", 20)

func _on_button_pressed(id: String) -> void:
	if id == _selected_id:
		return
	set_selected(id, true)
