class_name TbsBaseHexTile
extends Node2D


var coords: Vector2i
var tile_state: TbsTileState

@onready var base_sprite: Sprite2D = $base_sprite
@onready var terrain_sprite: Sprite2D = $base_sprite/terrain_sprite


signal pressed(tile_coords: Vector2i, tile: TbsBaseHexTile)


func bind_state(state: TbsTileState, def: TbsTerrainDefinition) -> void:
	tile_state = state
	coords = state.coords
	# Set base texture (same for all tiles)
	base_sprite.texture = load("res://assets/tiles_sliced/tiles_bottom/base.png")
	# Set terrain texture
	if def and def.tile_texture:
		terrain_sprite.texture = def.tile_texture


func set_highlight(color: Color) -> void:
	base_sprite.self_modulate = color


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(coords, self)

