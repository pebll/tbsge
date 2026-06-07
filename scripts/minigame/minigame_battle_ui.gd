class_name MinigameBattleUI
extends RefCounted

const LIFT_NONE := 0.0
const LIFT_OPTION := 2.0
const LIFT_SELECTED := 4.0

var root: MinigameRoot
var selected_coords: Vector2i
var has_selected: bool = false
var movable_coords: Array[Vector2i] = []
var attackable_coords: Array[Vector2i] = []
var swappable_coords: Array[Vector2i] = []
var _overlay_coords: Array[Vector2i] = []
var _info_tile_coords: Vector2i
var _info_visible_for_tile: bool = false

func _init(p_root: MinigameRoot) -> void:
	root = p_root
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.tile_right_clicked.connect(_on_tile_right_clicked)
	EventBus.tile_hover_entered.connect(_on_tile_hover_entered)
	EventBus.tile_hover_exited.connect(_on_tile_hover_exited)

func can_accept_command() -> bool:
	return not root.input_locked

func _on_tile_clicked(coords: Vector2i) -> void:
	if not can_accept_command():
		return
	if root.session.phase != MinigameSession.Phase.BATTLE:
		return
	AudioManager.play_sfx("tile_click")
	_dispatch_click(coords)

func _on_tile_right_clicked(coords: Vector2i) -> void:
	if root.session.phase != MinigameSession.Phase.BATTLE:
		return
	_info_tile_coords = coords
	_info_visible_for_tile = true
	root.inspect_tile(coords)

func _on_tile_hover_entered(coords: Vector2i) -> void:
	if not coords in _overlay_coords:
		return
	AudioManager.play_sfx("tile_hover")
	var tile_visu := root.presenter.tile_visu_at(coords)
	if tile_visu:
		tile_visu.set_hover_boost(true)
	if has_selected:
		var selected_visu := root.presenter.tile_visu_at(selected_coords)
		if selected_visu and selected_visu.legion_visu and tile_visu:
			var dir := (tile_visu.position - selected_visu.position).normalized()
			selected_visu.legion_visu.update_direction(dir)

func _on_tile_hover_exited(coords: Vector2i) -> void:
	if _info_visible_for_tile and coords == _info_tile_coords:
		_info_visible_for_tile = false
		root.clear_inspect()
	if coords in _overlay_coords:
		var tile_visu := root.presenter.tile_visu_at(coords)
		if tile_visu:
			tile_visu.set_hover_boost(false)
	if has_selected:
		var selected_visu := root.presenter.tile_visu_at(selected_coords)
		if selected_visu and selected_visu.legion_visu:
			selected_visu.legion_visu.juice_direct_reset()

func _dispatch_click(coords: Vector2i) -> void:
	if coords in movable_coords:
		root.request_move(selected_coords, coords)
		return
	if coords in swappable_coords:
		root.request_swap(selected_coords, coords)
		return
	if coords in attackable_coords:
		root.request_attack(selected_coords, coords)
		return
	if has_selected and coords == selected_coords:
		deselect()
		return
	var tile: Tile = root.session.grid.get(coords)
	if tile and tile.has_legion():
		deselect()
		if root.session.can_act_legion(tile.legion):
			select_tile(coords)
		return
	deselect()

func deselect() -> void:
	clear_overlays()
	has_selected = false

func select_tile(coords: Vector2i) -> void:
	var tile: Tile = root.session.grid.get(coords)
	if not tile or not tile.has_legion():
		return
	if not root.session.can_act_legion(tile.legion):
		return
	_paint_selection(coords, tile.legion)

func refresh_after_action(legion_coords: Vector2i) -> void:
	var tile: Tile = root.session.grid.get(legion_coords)
	if tile and tile.legion and root.session.can_act_legion(tile.legion):
		select_tile(legion_coords)
	else:
		deselect()

func clear_overlays() -> void:
	for c in _overlay_coords:
		var t := root.presenter.tile_visu_at(c)
		if t:
			t.set_hover_boost(false)
			t.set_gameplay_overlay("", LIFT_NONE)
	_overlay_coords.clear()
	movable_coords.clear()
	attackable_coords.clear()
	swappable_coords.clear()

func _paint_selection(coords: Vector2i, legion: Legion) -> void:
	clear_overlays()
	has_selected = true
	selected_coords = coords
	_paint_tile(coords, "selected", LIFT_SELECTED)

	if legion.has_ap():
		attackable_coords = root.session.get_attackable_coords(coords)
	if legion.can_afford(1):
		movable_coords = root.session.get_movable_coords(coords)
	if legion.can_afford(1):
		swappable_coords = root.session.get_swappable_coords(coords)
		var filtered: Array[Vector2i] = []
		for c in swappable_coords:
			var t: Tile = root.session.grid.get(c)
			if t and t.legion and t.legion.can_afford(1):
				filtered.append(c)
		swappable_coords = filtered

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
	var t := root.presenter.tile_visu_at(coords)
	if t:
		t.set_gameplay_overlay(state, lift)

func cycle_legion_tab() -> void:
	if not can_accept_command():
		return
	var coords: Vector2i = root.session.turn_manager.tab_next(root.session._typed_legions())
	if coords == TurnManager.INVALID_COORDS:
		return
	deselect()
	select_tile(coords)

func pass_current_legion() -> void:
	if not can_accept_command():
		return
	if has_selected:
		root.session.turn_manager.wait_legion(selected_coords)
		deselect()
	cycle_legion_tab()
