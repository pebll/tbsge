class_name TbsUnitDefinition
extends Resource


@export var id: String = ""              # e.g. "KNIGHT"
@export var display_name: String = ""
@export var max_hp: int = 10
@export var move_range: int = 1
@export var attack_range: int = 1
@export var attack_power: int = 1
@export var team_id: int = 0

# Art hooks (game provides these)
@export var sprite_front: Texture2D
@export var sprite_back: Texture2D

