class_name MinigameDraftPanel
extends PanelContainer

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

signal unit_type_changed(unit_type: String)
signal count_changed(count: int)
signal ready_pressed
signal clear_slot_pressed

@onready var team_label: Label = %TeamLabel
@onready var budget_label: Label = %BudgetLabel
@onready var unit_grid: GridContainer = %UnitGrid
@onready var count_label: Label = %CountLabel
@onready var minus_button: Button = %MinusButton
@onready var plus_button: Button = %PlusButton
@onready var ready_button: Button = %ReadyButton
@onready var clear_button: Button = %ClearButton
@onready var info_label: Label = %InfoLabel

const COLOR_BG := Color(0.91, 0.86, 0.78)
const COLOR_BORDER := Color(0.78, 0.70, 0.58)
const COLOR_TEXT := Color(0.12, 0.10, 0.08)
const BORDER_THICK := 4
const RADIUS := 16

var _selected_type: String = "ARCHER"
var _selected_count: int = 4
var _unit_buttons: Dictionary = {}

func _ready() -> void:
	_apply_style()
	minus_button.pressed.connect(_on_minus)
	plus_button.pressed.connect(_on_plus)
	ready_button.pressed.connect(func(): ready_pressed.emit())
	clear_button.pressed.connect(func(): clear_slot_pressed.emit())
	_build_unit_picker()
	_refresh_count_ui()

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
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sb)
	for label in [team_label, budget_label, count_label, info_label]:
		label.add_theme_color_override("font_color", COLOR_TEXT)

func _build_unit_picker() -> void:
	var db: UnitDatabase = load("res://data/unit_db.tres")
	if db == null:
		return
	for def in db.defs:
		if def == null:
			continue
		var btn := Button.new()
		btn.text = "%s (%dg)" % [def.display_name, def.price]
		btn.toggle_mode = true
		btn.button_pressed = def.id == _selected_type
		btn.pressed.connect(func(): _select_type(def.id))
		unit_grid.add_child(btn)
		_unit_buttons[def.id] = btn

func _select_type(unit_type: String) -> void:
	_selected_type = unit_type
	for id in _unit_buttons.keys():
		_unit_buttons[id].button_pressed = id == unit_type
	var max_count := MinigameRulesScript.max_units_in_legion(unit_type)
	_selected_count = clampi(_selected_count, 1, max_count)
	_refresh_count_ui()
	unit_type_changed.emit(unit_type)

func _on_minus() -> void:
	_selected_count = maxi(1, _selected_count - 1)
	_refresh_count_ui()
	count_changed.emit(_selected_count)

func _on_plus() -> void:
	var max_count := MinigameRulesScript.max_units_in_legion(_selected_type)
	_selected_count = mini(max_count, _selected_count + 1)
	_refresh_count_ui()
	count_changed.emit(_selected_count)

func _refresh_count_ui() -> void:
	count_label.text = "Units: %d / %d" % [
		_selected_count,
		MinigameRulesScript.max_units_in_legion(_selected_type),
	]
	var cost := MinigameRulesScript.legion_cost(_selected_type, _selected_count)
	var fill := MinigameRulesScript.legion_fill(_selected_type, _selected_count)
	info_label.text = "Cost: %d gold  |  Size: %.1f / 12" % [cost, fill]

func show_for_team(team_id: String, draft_data: Dictionary) -> void:
	var team_res: Resource = TeamDefs.get_def(team_id)
	var name := team_id
	if team_res is TeamDefinition:
		name = (team_res as TeamDefinition).display_name
	team_label.text = "%s — Army Setup" % name
	budget_label.text = "Gold: %d / %d" % [
		int(draft_data.get("remaining_budget", 0)),
		int(draft_data.get("budget_total", 0)),
	]
	show()

func get_selected_type() -> String:
	return _selected_type

func get_selected_count() -> int:
	return _selected_count

func set_selected_count(count: int) -> void:
	_selected_count = clampi(count, 1, MinigameRulesScript.max_units_in_legion(_selected_type))
	_refresh_count_ui()
