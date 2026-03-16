class_name TbsTerrainDefinition
extends Resource


@export var id: String = ""            # e.g. "GRASS"
@export var display_name: String = ""
@export var walkable: bool = true
@export var move_cost: int = 1

# Art hook
@export var tile_texture: Texture2D

