class_name Tile
extends RefCounted

const TERRAINS := ["MOUNTAIN", "WATER", "GRASS", "DESERT", "FOREST"]

var coords: Vector2i
var cube_q: int
var cube_r: int
var cube_s: int

var terrain_type: String
var walkable: bool

var legion: Legion = null

func _init(q: int, r: int, terrain: String = "") -> void:
	cube_q = q
	cube_r = r
	cube_s = -q - r
	coords = Vector2i(q, r)

	if terrain.is_empty():
		terrain_type = TERRAINS[randi() % TERRAINS.size()]
	else:
		terrain_type = terrain

	walkable = not (terrain_type == "MOUNTAIN" or terrain_type == "WATER")

func has_legion() -> bool:
	return legion != null

