extends PanelContainer

## Small tag floating above the hovered target: what this attack is expected to do to it
## ("💥 16–20  💀 0–2"), plus the retaliation you take ("↩ 1–4"). Same estimate as the VS
## comparison bar, shown where the player is looking.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const BattleExpectationEstimatorScript = preload("res://scripts/battle/battle_expectation_estimator.gd")

var _label: Label
var _anchor_node: Node2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.panel_stylebox(UiTheme.COLOR_PANEL, UiTheme.COLOR_BORDER, 12, 3, 6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	hide()

func show_for(
	attacker: Legion, defender: Legion, action_id: String,
	from_coords: Vector2i, to_coords: Vector2i, grid: Dictionary, anchor: Node2D
) -> void:
	if attacker == null or defender == null or anchor == null or action_id in ["self_heal", "heal_ally"]:
		hide()
		return
	var est: Dictionary = BattleExpectationEstimatorScript.estimate(
		attacker, defender, action_id, from_coords, to_coords, grid
	)
	var parts := PackedStringArray()
	parts.append("💥 " + _range(int(est.get("enemy_damage_min", 0)), int(est.get("enemy_damage_max", 0))))
	var kills_hi := int(est.get("enemy_losses_max", 0))
	if kills_hi > 0:
		parts.append("💀 " + _range(int(est.get("enemy_losses_min", 0)), kills_hi))
	var back_hi := int(est.get("own_damage_max", 0))
	if back_hi > 0:
		parts.append("↩ " + _range(int(est.get("own_damage_min", 0)), back_hi))
	_label.text = "   ".join(parts)
	_anchor_node = anchor
	show()
	reset_size()
	_place()

## Plain text tag (e.g. a move's AP cost) above a hex; empty text hides it.
func show_text(text: String, anchor: Node2D) -> void:
	if text.is_empty() or anchor == null:
		hide()
		return
	_label.text = text
	_anchor_node = anchor
	show()
	reset_size()
	_place()

func _process(_delta: float) -> void:
	if visible:
		_place()

func _place() -> void:
	if _anchor_node == null or not is_instance_valid(_anchor_node):
		hide()
		return
	var at := _anchor_node.get_global_transform_with_canvas().origin
	var sz := get_combined_minimum_size()
	var vp := get_viewport_rect().size
	position = Vector2(
		clampf(at.x - sz.x * 0.5, 8.0, vp.x - sz.x - 8.0),
		clampf(at.y - sz.y - 96.0, 8.0, vp.y - sz.y - 8.0)
	)

static func _range(lo: int, hi: int) -> String:
	return str(lo) if lo == hi else "%d–%d" % [lo, hi]
