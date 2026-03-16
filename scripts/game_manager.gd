class_name GameManager
extends Node2D

var grid : Dictionary[Vector2i, HexTile] = {}
var units : Array[Unit] = []
var selected_tile : HexTile = null
var movable_tiles : Array[HexTile] = []
var attackable_tiles : Array[HexTile] = []

func _ready():
	pass

func on_tile_clicked(tile: HexTile):
	# if selected tile is movable tile
	if tile in movable_tiles:
		move_unit(selected_tile, tile)
		#tile.unit.move_tween.finished.connect(func():
		deselect()
	elif tile in attackable_tiles:
		attack_unit(selected_tile, tile)
		selected_tile.unit.active_tween.finished.connect(func():
			deselect())
	# if selected tile is selected tile
	elif tile == selected_tile:
		deselect()
	# if tile is another unit
	elif tile.unit:
		deselect()
		select_tile(tile)
	# else
	else:
		deselect()
		spawn_unit(tile)

		
func on_tile_hover_entry(tile: HexTile):
	if tile in movable_tiles + attackable_tiles:
		tile.juice_go_to(6)
		var dir = get_direction(selected_tile, tile)
		selected_tile.unit.update_direction(dir)
		
func on_tile_hover_exit(tile: HexTile):
	if tile in movable_tiles + attackable_tiles:
		tile.juice_go_to(4)
		selected_tile.unit.juice_direct_reset()
		
func deselect():
	if selected_tile:
		selected_tile.juice_go_to(0)
		selected_tile.update_state("")
	for t in movable_tiles + attackable_tiles:
		t.juice_go_to(0)
		t.update_state("")
	selected_tile = null
	movable_tiles = []
	attackable_tiles = []
	
func select_tile(tile: HexTile):
	selected_tile = tile
	selected_tile.juice_go_to(4)
	selected_tile.update_state("selected")
	attackable_tiles = get_attackable_tiles(tile)
	movable_tiles = get_movable_tiles(tile)
	for t in movable_tiles:
		t.juice_go_to(2)
		t.update_state("movable")
	for t in attackable_tiles:
		t.juice_go_to(2)
		t.update_state("attackable")

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
	var dir = get_direction(from, to)
	from.unit.update_direction(dir)
	from.unit.juice_attack(dir)
	to.unit.juice_hitted(dir)

func get_direction(from: HexTile, to: HexTile) -> Vector2:
	var difference : Vector2 = to.position - from.position
	var direction : Vector2 = difference.normalized()
	return direction

func get_surrounding_tiles(tile: HexTile) -> Array[HexTile]:
	var offsets : Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),Vector2i(0, -1), Vector2i(1, -1)]
	var tiles : Array[HexTile]= []
	for offset in offsets:
		var t = grid.get(tile.coords + offset)
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
	
