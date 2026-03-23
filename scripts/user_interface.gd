class_name UserInterface

var gamemanager : GameManager

var selected_tile : HexTile = null
var movable_tiles : Array[HexTile] = []
var attackable_tiles : Array[HexTile] = []

func _init(gamemanager_ : GameManager) -> void:
	gamemanager = gamemanager_
	EventBus.tile_clicked.connect(on_tile_clicked)
	EventBus.tile_hover_entered.connect(on_tile_hover_entry)
	EventBus.tile_hover_exited.connect(on_tile_hover_exit)
	
func on_tile_clicked(tile: HexTile):
	AudioManager.play_sfx("tile_click")
	# if selected tile is movable tile
	if tile in movable_tiles:
		gamemanager.move_unit(selected_tile, tile)
		deselect()
	elif tile in attackable_tiles:
		gamemanager.attack_unit(selected_tile, tile)
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
		gamemanager.spawn_unit(tile)

		
func on_tile_hover_entry(tile: HexTile):
	if tile in movable_tiles + attackable_tiles:
		AudioManager.play_sfx("tile_hover")
		tile.juice_go_to(6)
		var dir = Utils.get_direction(selected_tile, tile)
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
	attackable_tiles = Utils.get_attackable_tiles(tile, gamemanager.grid)
	movable_tiles = Utils.get_movable_tiles(tile, gamemanager.grid)
	for t in movable_tiles:
		t.juice_go_to(2)
		t.update_state("movable")
	for t in attackable_tiles:
		t.juice_go_to(2)
		t.update_state("attackable")
