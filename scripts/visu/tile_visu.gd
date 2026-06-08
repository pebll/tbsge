class_name TileVisu
extends Node2D

var base_sprite: Sprite2D
var terrain_sprite: Sprite2D
var qr_label: Label

@export var color_movable: Color = Color.GREEN
@export var color_selected: Color = Color.YELLOW
@export var color_attackable: Color = Color.RED
@export var color_swappable: Color = Color(0.35, 0.65, 0.95)
@export var color_deployable: Color = Color(0.45, 0.82, 0.55)
@export var color_deployed: Color = Color(0.55, 0.75, 0.95)
@export var color_healable: Color = Color(0.25, 1.0, 0.35)

var tile: Tile
var legion_visu: LegionVisu = null

var active_tween: Tween
var base_y: float

var _gameplay_state: String = ""
var _gameplay_lift: float = 0.0
var _hover_boost: bool = false

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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.tile_right_clicked.emit(tile.coords)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			EventBus.tile_clicked.emit(tile.coords)

func set_gameplay_overlay(state: String, lift: float) -> void:
	_gameplay_state = state
	_gameplay_lift = lift
	_apply_state()
	_sync_lift()

func set_hover_boost(enabled: bool) -> void:
	_hover_boost = enabled
	_sync_lift()

func _sync_lift() -> void:
	var target := _gameplay_lift
	if _hover_boost and _gameplay_lift > 0.0:
		target = 6.0
	juice_go_to(target)

func juice_go_to(target: float) -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
	if legion_visu and legion_visu.active_tween and legion_visu.active_tween.is_running():
		legion_visu.active_tween.kill()
	var time := 0.8
	active_tween = create_tween()
	active_tween.tween_property(base_sprite, "position:y", base_y - target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if legion_visu:
		legion_visu.current_offset = Vector2(0, -target)
		legion_visu.active_tween = create_tween()
		legion_visu.active_tween.tween_property(legion_visu.units, "position:y", -target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func update_state(state: String) -> void:
	set_gameplay_overlay(state, _gameplay_lift)

func _apply_state() -> void:
	if not base_sprite:
		return
	if _gameplay_state == "selected":
		base_sprite.self_modulate = color_selected
	elif _gameplay_state == "attackable":
		base_sprite.self_modulate = color_attackable
	elif _gameplay_state == "swappable":
		base_sprite.self_modulate = color_swappable
	elif _gameplay_state == "movable":
		base_sprite.self_modulate = color_movable
	elif _gameplay_state == "deployable":
		base_sprite.self_modulate = color_deployable
	elif _gameplay_state == "deployed":
		base_sprite.self_modulate = color_deployed
	elif _gameplay_state == "healable":
		base_sprite.self_modulate = color_healable
	else:
		base_sprite.self_modulate = Color.WHITE
