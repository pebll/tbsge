class_name TileVisu
extends Node2D

var base_sprite: Sprite2D
var terrain_sprite: Sprite2D
var qr_label: Label

@export var color_movable: Color = Color.GREEN
@export var color_selected: Color = Color.YELLOW
@export var color_attackable: Color = Color.RED

var tile: Tile
var legion_visu: LegionVisu = null

var active_tween: Tween
var base_y: float

func init(p_tile: Tile) -> void:
	tile = p_tile
	# This can be called before the node enters the tree (e.g. when the parent is added deferred),
	# so we must not rely on @onready here.
	base_sprite = get_node("base_sprite")
	qr_label = get_node("QR_Label")
	terrain_sprite = base_sprite.get_child(0)
	terrain_sprite.texture = load("res://assets/tiles_sliced/tiles_terrain/" + tile.terrain_type.to_lower() + ".png")
	base_sprite.texture = load("res://assets/tiles_sliced/tiles_bottom/base.png")
	base_y = base_sprite.position.y
	qr_label.text = "(%d,%d,%d)" % [tile.cube_q, tile.cube_r, tile.cube_s]

func has_legion_visu() -> bool:
	return legion_visu != null

func _on_mouse_entered():
	EventBus.tile_hover_entered.emit(tile.coords)

func _on_mouse_exited():
	EventBus.tile_hover_exited.emit(tile.coords)

func _on_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		EventBus.tile_clicked.emit(tile.coords)

func juice_go_to(target: float):
	var time = 0.8
	active_tween = create_tween()
	active_tween.tween_property(base_sprite, "position:y", base_y - target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if legion_visu:
		legion_visu.current_offset = Vector2(0, -target)
		legion_visu.active_tween = create_tween()
		legion_visu.active_tween.tween_property(legion_visu.units, "position:y", -target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func update_state(state: String):
	if state == "selected":
		base_sprite.self_modulate = color_selected
	elif state == "attackable":
		base_sprite.self_modulate = color_attackable
	elif state == "movable":
		base_sprite.self_modulate = color_movable
	else:
		base_sprite.self_modulate = Color.WHITE
