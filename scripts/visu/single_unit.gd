class_name SingleUnit
extends Node2D


@export var unit_type: String = ""
@export var direction_front: bool = true
@export var direction_right: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var idle_tween : Tween
@onready var active_tween : Tween
@onready var move_tween : Tween

var current_offset: Vector2 = Vector2(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var unit_ids := UnitDefs.get_all_ids()
	if unit_type.is_empty() and not unit_ids.is_empty():
		unit_type = unit_ids[randi() % unit_ids.size()]
	direction_front = true
	direction_right = true if randi() % 2 == 0 else false
	update_sprite()
	start_idle_animation()

func update_direction(direction: Vector2):
	direction_right = direction.x >= 0
	direction_front = direction.y >= 0
	juice_direct(direction)
	update_sprite()
	
func _get_base_scale() -> Vector2:
	const BASE_SPRITE_SCALE := Vector2(0.2, 0.2)
	var image_scale := 1.0
	var def := UnitDefs.get_def(unit_type)
	if def and def.image_size > 0.0:
		image_scale = def.image_size
	return BASE_SPRITE_SCALE * image_scale

func update_sprite():
	var def := UnitDefs.get_def(unit_type)
	var new_texture: Texture2D = def.icon if def else null
	var new_flip_h = !direction_right
	sprite.texture = new_texture
	sprite.flip_h = new_flip_h
	sprite.scale = _get_base_scale()

func start_idle_animation():
	var base_scale := _get_base_scale()
	sprite.scale = base_scale
	var stretch_percentage := 0.02
	var scale_a := Vector2(
		base_scale.x * (1.0 - stretch_percentage),
		base_scale.y * (1.0 + stretch_percentage)
	)
	var scale_b := Vector2(
		base_scale.x * (1.0 + stretch_percentage),
		base_scale.y * (1.0 - stretch_percentage)
	)
	var loop_time := 1.0
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(sprite, "scale", scale_a, loop_time)
	idle_tween.tween_property(sprite, "scale", scale_b, loop_time)

func juice_move(target_pos: Vector2):
	var move_time = 0.4
	move_tween = create_tween()
	active_tween = create_tween()
	move_tween.tween_property(self, "position", target_pos, move_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "rotation", 0, move_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		
func juice_attack(direction: Vector2):
	var target_pos = direction * 30
	var target_rot = 0.3 * direction.x
	var attack_time = 0.2
	active_tween = create_tween()
	active_tween.tween_property(sprite, "position", current_offset + target_pos, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(sprite, "rotation", target_rot, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "position", current_offset, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	active_tween.parallel().tween_property(sprite, "rotation", 0, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	
func juice_hitted(direction: Vector2):
	var target_pos = direction * 10
	var target_rot = 0.1 * direction.x
	var attack_time = 0.2
	# TODO: some kind of state machine for switch animation states
	active_tween = create_tween()
	active_tween.tween_property(sprite, "position", current_offset + target_pos, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(sprite, "rotation", target_rot, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(sprite, "self_modulate", Color.ORANGE_RED, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "position", current_offset, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	active_tween.parallel().tween_property(sprite, "rotation", 0, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	active_tween.parallel().tween_property(sprite, "self_modulate", Color.WHITE, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)

func juice_squish():
	if active_tween and active_tween.is_running():
		return
	active_tween = create_tween()
	var anim_time = 0.1
	var scale_factor = 1.03
	var base_scale := _get_base_scale()
	var target_scale := Vector2(base_scale.x / scale_factor, base_scale.y * scale_factor)
	active_tween.tween_property(sprite, "scale", target_scale, anim_time/2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(sprite, "scale", base_scale, anim_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

func juice_direct(direction: Vector2):
	var target_pos = -direction * 2
	var target_rot = -direction.x * 0.15
	if not direction_front:
		target_rot *= 1.2
	var attack_time = 0.2
	move_tween = create_tween()
	move_tween.tween_property(sprite, "position", current_offset + target_pos, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(sprite, "rotation", target_rot, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func juice_direct_reset():
	var target_pos = Vector2.ZERO
	var target_rot = 0
	var attack_time = 0.2
	move_tween = create_tween()
	move_tween.tween_property(sprite, "position", current_offset + target_pos, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(sprite, "rotation", target_rot, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
