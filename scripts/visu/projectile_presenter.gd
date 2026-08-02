class_name ProjectilePresenter
extends RefCounted

## Spawns a world-space projectile along a parabola from shooter to target.
## Parent layer should be a Node2D under a CanvasLayer with follow_viewport_enabled.

## Art faces upper-right; subtract this when aligning to velocity.
const ART_FORWARD_ANGLE := -PI * 0.25
## Match unit sprite ballpark; projectile sheets are full-res otherwise.
const PROJECTILE_SCALE := Vector2(0.12, 0.12)

var _layer: Node2D

func _init(layer: Node2D) -> void:
	_layer = layer

func play_parabola(
	host: Node,
	from_global: Vector2,
	to_global: Vector2,
	texture: Texture2D,
	motion: int,
	duration: float = 0.28,
	arc_height: float = 48.0
) -> void:
	if host == null or _layer == null or texture == null:
		return

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = PROJECTILE_SCALE
	sprite.z_index = 10
	sprite.position = from_global
	_layer.add_child(sprite)

	var mid := (from_global + to_global) * 0.5 + Vector2(0.0, -absf(arc_height))
	var prev_pos := from_global
	var spin := 0.0

	var tween := host.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var pos := _bezier(from_global, mid, to_global, t)
			sprite.position = pos
			var delta := pos - prev_pos
			if motion == UnitDefinition.ProjectileMotion.ARROW:
				if delta.length_squared() > 0.01:
					sprite.rotation = delta.angle() - ART_FORWARD_ANGLE
			else:
				spin += 0.45
				sprite.rotation = spin
			prev_pos = pos,
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()

static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * b + t * t * c

static func load_projectile_texture(projectile_id: String) -> Texture2D:
	if projectile_id.is_empty():
		return null
	var path := "res://assets/projectiles/%s.png" % projectile_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Projectile texture missing: %s" % path)
	return null
