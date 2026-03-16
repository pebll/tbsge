class_name TbsBaseUnit
extends Node2D


var state: TbsUnitState

@onready var sprite: Sprite2D = $Sprite2D


func bind_state(p_state: TbsUnitState, def: TbsUnitDefinition) -> void:
	state = p_state
	if def and def.sprite_front:
		sprite.texture = def.sprite_front


func play_move(from_pos: Vector2, to_pos: Vector2) -> void:
	position = from_pos
	var tween := create_tween()
	tween.tween_property(self, "position", to_pos, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func play_attack(direction: Vector2) -> void:
	# Simple nudge; games can override with richer animations.
	var tween := create_tween()
	var offset := direction.normalized() * 10.0
	tween.tween_property(self, "position", position + offset, 0.1)
	tween.tween_property(self, "position", position, 0.1)

