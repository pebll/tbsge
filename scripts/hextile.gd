class_name HexTile
extends Node2D

# Define the terrain types as an enum for clarity and type safety.
const TERRAINS = ["MOUNTAIN", "WATER", "GRASS", "DESERT", "FOREST"]

# references
@onready var base_sprite: Sprite2D = $base_sprite
@onready var terrain_sprite: Sprite2D
@onready var qr_label: Label = $QR_Label
@onready var gamemanager: GameManager = GameManagerGlobal
# gameplay
var terrain_type: String
var walkable : bool
var unit : Unit
# juice
var active_tween : Tween
var jump_up : bool = false
var base_y : float
var unit_base_y : float
# visuals
@export var color_movable: Color = Color.GREEN
@export var color_selected: Color = Color.YELLOW
@export var color_attackable: Color = Color.RED
# coords
var cube_r : int
var cube_q : int
var cube_s : int
var coords : Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Randomly select a terrain type.
	terrain_type = TERRAINS[randi() % 5]
	walkable = false if terrain_type == "MOUNTAIN" or terrain_type == "WATER" else true
	unit = null
	# Set the texture based on the chosen terrain type.
	terrain_sprite = base_sprite.get_child(0)
	terrain_sprite.texture = load("res://assets/tiles_sliced/tiles_terrain/" + terrain_type.to_lower() + ".png")
	base_sprite.texture = load("res://assets/tiles_sliced/tiles_bottom/base.png")
	
	base_y = base_sprite.position.y
	
	qr_label.text = "(%d,%d,%d)" % [cube_q, cube_r, cube_s]
	
func setup(q: int, r: int):
	cube_q = q
	cube_r = r
	cube_s = - q - r
	coords = Vector2i(q, r)

func _on_mouse_entered():
	gamemanager.on_tile_hover_entry(self)

func _on_mouse_exited():
	gamemanager.on_tile_hover_exit(self)
	
func juice_go_to(target: float):
	var time = 0.8
	active_tween = create_tween()
	active_tween.tween_property(base_sprite, "position:y", base_y - target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if unit:
		unit.current_offset = Vector2(0, -target)
		unit.active_tween = create_tween()
		unit.active_tween.tween_property(unit.sprite, "position:y", - target, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func update_state(state: String):
	if state == "selected":
		base_sprite.self_modulate = color_selected
	elif state == "attackable":
		base_sprite.self_modulate = color_attackable
	elif state == "movable":
		base_sprite.self_modulate = color_movable
	else:
		base_sprite.self_modulate = Color.WHITE

func _on_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		gamemanager.on_tile_clicked(self)
