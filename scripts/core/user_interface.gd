class_name GameUI

const LIFT_NONE := 0.0
const LIFT_OPTION := 2.0
const LIFT_SELECTED := 4.0

var gamemanager: GameManager

var selected_coords: Vector2i
var has_selected: bool = false
var movable_coords: Array[Vector2i] = []
var attackable_coords: Array[Vector2i] = []
var swappable_coords: Array[Vector2i] = []

## Every coord we last painted — cleared in one place so colors never stick.
var _overlay_coords: Array[Vector2i] = []

var _info_tile_coords: Vector2i
var _info_visible_for_tile: bool = false

func _init(gamemanager_: GameManager) -> void:
	gamemanager = gamemanager_
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.tile_right_clicked.connect(_on_tile_right_clicked)
	EventBus.tile_hover_entered.connect(_on_tile_hover_entered)
	EventBus.tile_hover_exited.connect(_on_tile_hover_exited)

func can_accept_command() -> bool:
	return not gamemanager.input.is_locked()

# --- EventBus handlers (raw pointer → command) --------------------------------

func _on_tile_clicked(coords: Vector2i) -> void:
	if not can_accept_command():
		return
	AudioManager.play_sfx("tile_click")
	_dispatch_click(coords)

func _on_tile_right_clicked(coords: Vector2i) -> void:
	_info_tile_coords = coords
	_info_visible_for_tile = true
	gamemanager.inspect_tile(coords)

func _on_tile_hover_entered(coords: Vector2i) -> void:
	if not coords in _overlay_coords:
		return
	AudioManager.play_sfx("tile_hover")
	var tile_visu := _tile_visu(coords)
	if tile_visu:
		tile_visu.set_hover_boost(true)
	if has_selected:
		var selected_visu := _tile_visu(selected_coords)
		if selected_visu and selected_visu.legion_visu and tile_visu:
			var dir := (tile_visu.position - selected_visu.position).normalized()
			selected_visu.legion_visu.update_direction(dir)

func _on_tile_hover_exited(coords: Vector2i) -> void:
	if _info_visible_for_tile and coords == _info_tile_coords:
		_info_visible_for_tile = false
		gamemanager.clear_inspect()
	if coords in _overlay_coords:
		var tile_visu := _tile_visu(coords)
		if tile_visu:
			tile_visu.set_hover_boost(false)
	if has_selected:
		var selected_visu := _tile_visu(selected_coords)
		if selected_visu and selected_visu.legion_visu:
			selected_visu.legion_visu.juice_direct_reset()

# --- Command dispatch ---------------------------------------------------------

func _dispatch_click(coords: Vector2i) -> void:
	if coords in movable_coords:
		gamemanager.move_unit(selected_coords, coords)
		return
	if coords in swappable_coords:
		gamemanager.swap_legions(selected_coords, coords)
		return
	if coords in attackable_coords:
		gamemanager.attack_unit(selected_coords, coords)
		return
	if has_selected and coords == selected_coords:
		deselect()
		return
	var tile: Tile = gamemanager.grid_model.get(coords)
	if tile and tile.has_legion():
		deselect()
		if gamemanager.can_select_legion_at(coords):
			select_tile(coords)
		return
	deselect()
	gamemanager.spawn_unit(coords)

# --- Selection / overlays (single paint path) ---------------------------------

func clear_overlays() -> void:
	for c in _overlay_coords:
		var t := _tile_visu(c)
		if t:
			t.set_hover_boost(false)
			t.set_gameplay_overlay("", LIFT_NONE)
	_overlay_coords.clear()
	movable_coords.clear()
	attackable_coords.clear()
	swappable_coords.clear()

func deselect() -> void:
	clear_overlays()
	has_selected = false

func select_tile(coords: Vector2i) -> void:
	var selected_tile: Tile = gamemanager.grid_model.get(coords)
	if not selected_tile or not selected_tile.has_legion():
		return
	if not gamemanager.can_act_legion(selected_tile.legion):
		return
	_paint_selection(coords, selected_tile.legion)

func refresh_after_action(legion_coords: Vector2i) -> void:
	var tile: Tile = gamemanager.grid_model.get(legion_coords)
	if tile and tile.legion and gamemanager.can_act_legion(tile.legion):
		select_tile(legion_coords)
	else:
		deselect()

func _paint_selection(coords: Vector2i, legion: Legion) -> void:
	clear_overlays()
	has_selected = true
	selected_coords = coords

	_paint_tile(coords, "selected", LIFT_SELECTED)

	attackable_coords = []
	if legion.has_ap():
		for t in Utils.get_attackable_tiles(gamemanager.grid_model.get(coords), gamemanager.grid_model):
			attackable_coords.append(t.coords)

	movable_coords = []
	if legion.can_afford(1):
		for t in Utils.get_movable_tiles(gamemanager.grid_model.get(coords), gamemanager.grid_model):
			movable_coords.append(t.coords)

	swappable_coords = []
	if legion.can_afford(1):
		for t in Utils.get_swappable_tiles(gamemanager.grid_model.get(coords), gamemanager.grid_model):
			if t.legion.can_afford(1):
				swappable_coords.append(t.coords)

	for c in movable_coords:
		_paint_tile(c, "movable", LIFT_OPTION)
	for c in attackable_coords:
		_paint_tile(c, "attackable", LIFT_OPTION)
	for c in swappable_coords:
		_paint_tile(c, "swappable", LIFT_OPTION)

func _paint_tile(coords: Vector2i, state: String, lift: float) -> void:
	if coords in _overlay_coords:
		return
	_overlay_coords.append(coords)
	var t := _tile_visu(coords)
	if t:
		t.set_gameplay_overlay(state, lift)

func _tile_visu(coords: Vector2i) -> TileVisu:
	return gamemanager.grid_visu.get(coords)

# --- Keyboard -----------------------------------------------------------------

func cycle_legion_tab() -> void:
	if not can_accept_command():
		return
	var coords: Vector2i = gamemanager.turn_manager.tab_next(_legions_for_turn())
	if coords == TurnManager.INVALID_COORDS:
		return
	deselect()
	select_tile(coords)

func pass_current_legion() -> void:
	if not can_accept_command():
		return
	if has_selected:
		gamemanager.turn_manager.wait_legion(selected_coords)
		deselect()
	cycle_legion_tab()

func _legions_for_turn() -> Array[Legion]:
	var out: Array[Legion] = []
	for tile in gamemanager.grid_model.values():
		if tile and tile.has_legion():
			out.append(tile.legion)
	return out
