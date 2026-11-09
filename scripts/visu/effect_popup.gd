extends Node2D

## A small effect icon that pops above a legion, floats up and fades (Super Auto Pets
## style). Uses the effect's icon when it has one, else its colour + first letter.
## Optional short text next to it ("-3", "+2").

const EffectVisuals = preload("res://scripts/visu/effect_visuals.gd")

const RISE := 46.0
const DURATION := 0.9
const RADIUS := 13.0

var _effect_id := ""
var _text := ""

static func spawn(parent: Node, at: Vector2, effect_id: String, text: String = "", delay: float = 0.0) -> Node2D:
	var p = load("res://scripts/visu/effect_popup.gd").new()
	p._effect_id = effect_id
	p._text = text
	p.position = at
	p.z_index = 50
	p.modulate.a = 0.0
	parent.add_child(p)
	p._play(delay)
	return p

## Above a legion on the map (sibling of its visual, so it isn't hidden or re-laid out).
static func spawn_over(visu: Node2D, effect_id: String, text: String = "", delay: float = 0.0) -> void:
	if visu == null or not is_instance_valid(visu) or visu.get_parent() == null or not visu.visible:
		return
	spawn(visu.get_parent(), visu.position + Vector2(randf_range(-26.0, 26.0), -78.0 - randf_range(0.0, 14.0)), effect_id, text, delay)

func _play(delay: float) -> void:
	scale = Vector2(0.4, 0.4)
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 1.0, 0.08)
	t.parallel().tween_property(self, "scale", Vector2.ONE * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.08)
	t.tween_property(self, "position:y", position.y - RISE, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, DURATION * 0.5).set_delay(DURATION * 0.5)
	t.tween_callback(queue_free)

func _draw() -> void:
	var look: Dictionary = EffectVisuals.look(_effect_id)
	var col: Color = look["color"]
	draw_circle(Vector2.ZERO, RADIUS + 2.5, Color(0.12, 0.10, 0.08))
	draw_circle(Vector2.ZERO, RADIUS, col)
	var icon: Texture2D = look["icon"]
	var font := ThemeDB.fallback_font
	if icon != null:
		var s := RADIUS * 1.6
		draw_texture_rect(icon, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false)
	else:
		draw_string(font, Vector2(-RADIUS, 6.0), String(look["mark"]), HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 17, Color.WHITE)
	if not _text.is_empty():
		var pos := Vector2(RADIUS + 4.0, 7.0)
		draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.12, 0.10, 0.08))
		draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
