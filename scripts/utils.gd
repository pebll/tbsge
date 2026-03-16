class_name Utils
extends Node

@onready var gamemanager : GameManager = GameManagerGlobal

func get_direction(from: HexTile, to: HexTile) -> Vector2:
	var difference : Vector2 = to.position - from.position
	var direction : Vector2 = difference.normalized()
	return direction

func get_surrounding_tiles(tile: HexTile) -> Array[HexTile]:
	var offsets : Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),Vector2i(0, -1), Vector2i(1, -1)]
	var tiles : Array[HexTile]= []
	for offset in offsets:
		var t = gamemanager.grid.get(tile.coords + offset)
		if t:
			tiles.append(t)
	return tiles

func get_surrounding_walkable_tiles(tile: HexTile) -> Array[HexTile]:
	var tiles = get_surrounding_tiles(tile)
	var walkable_tiles : Array[HexTile] = []
	for t in tiles:
		if t.walkable:
			walkable_tiles.append(t)
	return walkable_tiles

func get_movable_tiles(tile: HexTile) -> Array[HexTile]:
	var tiles = get_surrounding_walkable_tiles(tile)
	var new_tiles : Array[HexTile] = []
	for t in tiles:
		if not t.unit:
			new_tiles.append(t)
	return new_tiles

func get_attackable_tiles(tile: HexTile) -> Array[HexTile]:
	var tiles = get_surrounding_walkable_tiles(tile)
	var new_tiles : Array[HexTile] = []
	for t in tiles:
		if t.unit:
			new_tiles.append(t)
	return new_tiles
