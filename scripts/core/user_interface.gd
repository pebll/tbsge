class_name GameUI

var gamemanager : GameManager

var selected_coords : Vector2i
var has_selected: bool = false
var movable_coords : Array[Vector2i] = []
var attackable_coords : Array[Vector2i] = []
var swappable_coords : Array[Vector2i] = []

var _info_tile_coords: Vector2i
var _info_visible_for_tile: bool = false

func _init(gamemanager_ : GameManager) -> void:
	gamemanager = gamemanager_
	EventBus.tile_clicked.connect(on_tile_clicked)
	EventBus.tile_right_clicked.connect(on_tile_right_clicked)
	EventBus.tile_hover_entered.connect(on_tile_hover_entry)
	EventBus.tile_hover_exited.connect(on_tile_hover_exit)
	
func on_tile_clicked(coords: Vector2i):
	AudioManager.play_sfx("tile_click")
	# if selected tile is movable tile
	if coords in movable_coords:
		gamemanager.move_unit(selected_coords, coords)
		deselect()
	elif coords in swappable_coords:
		gamemanager.swap_legions(selected_coords, coords)
		deselect()
	elif coords in attackable_coords:
		gamemanager.attack_unit(selected_coords, coords)
		# keep old behavior: deselect after animation finishes
		var selected_tile_visu: TileVisu = gamemanager.grid_visu.get(selected_coords)
		if selected_tile_visu and selected_tile_visu.legion_visu and selected_tile_visu.legion_visu.active_tween:
			selected_tile_visu.legion_visu.active_tween.finished.connect(func():
				deselect())
		else:
			deselect()
	# if selected tile is selected tile
	elif has_selected and coords == selected_coords:
		deselect()
	# if tile is another unit
	elif gamemanager.grid_model.get(coords) and gamemanager.grid_model[coords].has_legion():
		deselect()
		select_tile(coords)
	# else
	else:
		deselect()
		gamemanager.spawn_unit(coords)
		
func on_tile_right_clicked(coords: Vector2i) -> void:
	# Show instantly on right click (no selection highlight, no hover trigger).
	_info_tile_coords = coords
	_info_visible_for_tile = true
	gamemanager.inspect_tile(coords)
		
func on_tile_hover_entry(coords: Vector2i):
	# Hover no longer triggers the info panel.
	if coords in _highlighted_coords():
		AudioManager.play_sfx("tile_hover")
		var tile_visu: TileVisu = gamemanager.grid_visu.get(coords)
		if tile_visu:
			tile_visu.juice_go_to(6)
		if has_selected:
			var selected_visu: TileVisu = gamemanager.grid_visu.get(selected_coords)
			if selected_visu and selected_visu.legion_visu and tile_visu:
				var difference: Vector2 = tile_visu.position - selected_visu.position
				var dir = difference.normalized()
				selected_visu.legion_visu.update_direction(dir)
		
func on_tile_hover_exit(coords: Vector2i):
	# Hide the panel when leaving the tile that opened it.
	if _info_visible_for_tile and coords == _info_tile_coords:
		_info_visible_for_tile = false
		gamemanager.clear_inspect()
	if coords in _highlighted_coords():
		var tile_visu: TileVisu = gamemanager.grid_visu.get(coords)
		if tile_visu:
			tile_visu.juice_go_to(4)
		if has_selected:
			var selected_visu: TileVisu = gamemanager.grid_visu.get(selected_coords)
			if selected_visu and selected_visu.legion_visu:
				selected_visu.legion_visu.juice_direct_reset()

func _highlighted_coords() -> Array[Vector2i]:
	return movable_coords + attackable_coords + swappable_coords

func deselect():
	if has_selected:
		var selected_tile_visu: TileVisu = gamemanager.grid_visu.get(selected_coords)
		if selected_tile_visu:
			selected_tile_visu.juice_go_to(0)
			selected_tile_visu.update_state("")
	for c in _highlighted_coords():
		var t: TileVisu = gamemanager.grid_visu.get(c)
		if t:
			t.juice_go_to(0)
			t.update_state("")
	has_selected = false
	movable_coords = []
	attackable_coords = []
	swappable_coords = []
	
func select_tile(coords: Vector2i):
	selected_coords = coords
	has_selected = true
	var selected_tile = gamemanager.grid_model.get(coords)
	var selected_tile_visu: TileVisu = gamemanager.grid_visu.get(coords)
	if selected_tile_visu:
		selected_tile_visu.juice_go_to(4)
		selected_tile_visu.update_state("selected")

	if selected_tile:
		attackable_coords = []
		for t in Utils.get_attackable_tiles(selected_tile, gamemanager.grid_model):
			attackable_coords.append(t.coords)

		movable_coords = []
		for t in Utils.get_movable_tiles(selected_tile, gamemanager.grid_model):
			movable_coords.append(t.coords)

		swappable_coords = []
		for t in Utils.get_swappable_tiles(selected_tile, gamemanager.grid_model):
			swappable_coords.append(t.coords)

	for c in movable_coords:
		var t: TileVisu = gamemanager.grid_visu.get(c)
		if t:
			t.juice_go_to(2)
			t.update_state("movable")
	for c in attackable_coords:
		var t: TileVisu = gamemanager.grid_visu.get(c)
		if t:
			t.juice_go_to(2)
			t.update_state("attackable")
	for c in swappable_coords:
		var t: TileVisu = gamemanager.grid_visu.get(c)
		if t:
			t.juice_go_to(2)
			t.update_state("swappable")
