extends Node2D

## Status-effect badges drawn above a legion on the map: one circle per effect, with its
## icon (or its colour and first letter) and the stack count when above 1.

const StatusDefs = preload("res://scripts/effects/status_defs.gd")
const StatusEffects = preload("res://scripts/effects/status_effects.gd")
const EffectVisuals = preload("res://scripts/visu/effect_visuals.gd")

const RADIUS := 11.0
const GAP := 4.0

var _effects: Array = []

func sync(legion: Legion) -> void:
	var next: Array = [] if legion == null else legion.statuses.duplicate(true)
	if next == _effects:
		return
	_effects = next
	visible = not _effects.is_empty()
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in range(_effects.size()):
		var e: Dictionary = _effects[i]
		var def = StatusDefs.get_def(String(e["id"]))
		var c := Vector2(i * (RADIUS * 2.0 + GAP), 0.0)
		var col: Color = def.color if def != null else Color(0.5, 0.4, 0.7)
		var debuff: bool = def.is_debuff if def != null else true
		draw_circle(c, RADIUS + 2.0, Color(0.12, 0.10, 0.08) if debuff else Color(0.98, 0.95, 0.88))
		draw_circle(c, RADIUS, col)
		if def != null and def.icon != null:
			var s := RADIUS * 1.5
			draw_texture_rect(def.icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		else:
			var mark: String = EffectVisuals.look(String(e["id"]))["mark"]
			draw_string(font, c + Vector2(-RADIUS, 5.0), mark, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 14, Color.WHITE)
		var stacks := int(e.get("stacks", 1))
		if stacks > 1:
			draw_string(font, c + Vector2(RADIUS * 0.3, RADIUS + 9.0), str(stacks), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
