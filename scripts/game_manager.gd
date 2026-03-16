class_name GameManager
extends Node2D

var grid : Dictionary[Vector2i, HexTile] = {}
var units : Array[Unit] = []

@onready var utils : Utils = UtilsGlobal

func _ready():
	pass
	
func spawn_unit(tile: HexTile):
	# Spawns random unit at given coords
	if tile.unit or not tile.walkable:
		print("tile not adequate for spawning")
		return # only spawn if tile is empty
	var unit = preload("res://scenes/unit.tscn").instantiate()
	self.add_child(unit)
	units.append(unit)
	tile.unit = unit
	unit.sprite.z_index = 100
	unit.position = tile.position

func move_unit(from: HexTile, to: HexTile):
	var unit = from.unit
	from.unit = null
	to.unit = unit
	unit.juice_move(to.position)

func attack_unit(from: HexTile, to: HexTile):
	var dir = utils.get_direction(from, to)
	from.unit.update_direction(dir)
	from.unit.juice_attack(dir)
	to.unit.juice_hitted(dir)
