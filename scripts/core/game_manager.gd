class_name GameManager
extends Node2D

const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const TurnManagerRes = preload("res://scripts/core/turn_manager.gd")
const ActionResolverScript = preload("res://scripts/actions/action_resolver.gd")
const BattleStateScript = preload("res://scripts/actions/battle_state.gd")
const HexLayoutScript = preload("res://scripts/core/hex_layout.gd")
const ActionPlaybackScript = preload("res://scripts/battle/action_playback.gd")

@export var map_radius: int = 3
var tile_size: float = HexLayoutScript.DEFAULT_TILE_SIZE
var tile_size_xy_ratio: float = HexLayoutScript.DEFAULT_XY_RATIO
const TEAM_IDS: Array[String] = ["GREEN", "BLUE"]

@onready var grid_visu : Dictionary[Vector2i, TileVisu] = {}
@onready var grid_model : Dictionary[Vector2i, Tile] = {}
@onready var legions : Array[Legion] = []

var tilesContainer : Node
var ui : GameUI
var mapGenerator : MapGenerator
var tile_info_panel
var tile_info_layer: CanvasLayer
var combat_fx_layer: CanvasLayer
var turn_hud: TurnHud
var turn_manager: TurnManager
var input: GameInput
var _action_playback: RefCounted

func _ready():
	input = GameInput.new(self)
	ui = GameUI.new(self)
	mapGenerator = MapGenerator.new(tile_size, tile_size_xy_ratio)
	# TODO: fix this when refactor mapgenerator
	tilesContainer = Node.new()
	tilesContainer.name = "Tiles" 
	get_tree().root.add_child.call_deferred(tilesContainer)
	mapGenerator.generate_hex_map(map_radius, tilesContainer, self.grid_visu, self.grid_model)

	turn_manager = TurnManagerRes.new(TEAM_IDS)
	turn_manager.start_match(TEAM_IDS[0])
	_setup_tile_info_ui()
	_setup_combat_fx_ui()
	_setup_turn_hud()
	EventBus.legion_ap_changed.connect(_on_legion_ap_changed)

func _input(event: InputEvent) -> void:
	if input.is_locked():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
		ui.cycle_legion_tab()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE:
		ui.pass_current_legion()
		get_viewport().set_input_as_handled()

func can_act_legion(legion: Legion) -> bool:
	return legion != null and turn_manager.is_legion_active(legion) and legion.has_ap()

func can_select_legion_at(coords: Vector2i) -> bool:
	var tile: Tile = grid_model.get(coords)
	if not tile or not tile.has_legion():
		return false
	return can_act_legion(tile.legion)

func end_team_turn() -> void:
	ui.deselect()
	var next_team: String = turn_manager.end_team_turn(legions)
	if turn_hud:
		turn_hud.show_active_team(next_team)
	EventBus.turn_changed.emit(next_team)

func _notify_legion_ap_changed(legion: Legion) -> void:
	EventBus.legion_ap_changed.emit(legion)

func _on_legion_ap_changed(legion: Legion) -> void:
	if not tile_info_panel or not tile_info_panel.visible:
		return
	var tile: Tile = grid_model.get(legion.tile_coords)
	if tile and tile.has_legion():
		tile_info_panel.show_tile(tile)

func _setup_turn_hud() -> void:
	if not tile_info_layer:
		return
	turn_hud = preload("res://scenes/ui/turn_hud.tscn").instantiate()
	tile_info_layer.add_child(turn_hud)
	turn_hud.show_active_team(turn_manager.active_team_id)
	turn_hud.next_turn_pressed.connect(end_team_turn)

func _setup_tile_info_ui() -> void:
	tile_info_layer = CanvasLayer.new()
	tile_info_layer.name = "UI"
	add_child(tile_info_layer)

	tile_info_panel = preload("res://scenes/ui/tile_info_panel.tscn").instantiate()
	tile_info_layer.add_child(tile_info_panel)
	tile_info_panel.hide()

	var action_bar = preload("res://scenes/ui/battle_action_bar.tscn").instantiate()
	tile_info_layer.add_child(action_bar)
	ui.attach_action_bar(action_bar)

func _setup_combat_fx_ui() -> void:
	combat_fx_layer = CanvasLayer.new()
	combat_fx_layer.name = "CombatFX"
	combat_fx_layer.layer = 2
	add_child(combat_fx_layer)
	_action_playback = ActionPlaybackScript.new(
		self,
		func(c: Vector2i) -> TileVisu: return grid_visu.get(c),
		_legion_visu_for,
		combat_fx_layer
	)

# Todo: refactor HexTile to have a logic side?
func spawn_unit(coords: Vector2i):
	var tile = grid_model.get(coords)
	var tile_visu = grid_visu.get(coords)
	if not tile or not tile_visu:
		return

	# Spawns random legion at given coords
	if tile.has_legion() or not tile.walkable:
		print("tile not adequate for spawning")
		return # only spawn if tile is empty
	var team_id: String = turn_manager.active_team_id
	var unit_ids := UnitDefs.get_all_ids()
	if unit_ids.is_empty():
		return
	var legion = Legion.new(unit_ids[randi() % unit_ids.size()], randi() % 8 + 1, coords, team_id)
	legion.refresh_ap()
	var legionVisu = preload("res://scenes/legion.tscn").instantiate()
	# TODO: refactor this into own folder (like for the tiles)
	self.add_child(legionVisu)
	legions.append(legion)
	tile.legion = legion
	tile_visu.legion_visu = legionVisu
	legionVisu.init(legion)
	legionVisu.position = tile_visu.position
	_notify_legion_ap_changed(legion)
	# Let Y-sort / internal unit z-indices handle draw order.

func inspect_tile(coords: Vector2i) -> void:
	if not tile_info_panel:
		return
	var tile: Tile = grid_model.get(coords)
	if not tile or not tile.has_legion():
		tile_info_panel.hide()
		return
	tile_info_panel.show_tile(tile)
	tile_info_panel.show()

func clear_inspect() -> void:
	if tile_info_panel:
		tile_info_panel.hide()

func move_unit(from_coords: Vector2i, to_coords: Vector2i) -> void:
	var result := apply_battle_action("move", from_coords, to_coords)
	if not result.get("ok", false):
		return
	if "legion_moved" in result.get("events", []):
		var legion: Legion = result.get("payload", {}).get("legion")
		var tween := _animate_resolved_move(from_coords, to_coords)
		if legion:
			_notify_legion_ap_changed(legion)
		if tween:
			_finish_action_after_tweens([tween], func() -> void: pass)

func attack_unit(from_coords: Vector2i, to_coords: Vector2i) -> void:
	use_battle_action("melee_attack", from_coords, to_coords)

func swap_legions(from_coords: Vector2i, to_coords: Vector2i) -> void:
	use_battle_action("move", from_coords, to_coords)

func apply_battle_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> Dictionary:
	var cmd := {
		"action_id": action_id,
		"from": from_coords,
		"to": to_coords,
	}
	if action_id == "melee_attack":
		cmd["rng_seed"] = randi()
	return ActionResolverScript.resolve(BattleStateScript.from_game_manager(self), cmd)

func use_battle_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input.is_locked():
		return
	var result: Dictionary = apply_battle_action(action_id, from_coords, to_coords)
	if not result.get("ok", false):
		return

	input.begin_action()

	var events: Array = result.get("events", [])
	var payload: Dictionary = result.get("payload", {})
	if not ("legion_healed" in events or "combat_resolved" in events):
		ui.clear_overlays()
	var refresh_coords := from_coords
	var tweens: Array = []

	if "legion_moved" in events:
		tweens.append(_animate_resolved_move(from_coords, to_coords))
		refresh_coords = to_coords
		_notify_legion_ap_changed(payload.get("legion"))
	elif "legions_swapped" in events:
		tweens.append_array(_animate_resolved_swap(from_coords, to_coords))
		refresh_coords = to_coords
		var legion_a: Legion = grid_model.get(to_coords).legion
		var legion_b: Legion = grid_model.get(from_coords).legion
		_notify_legion_ap_changed(legion_a)
		_notify_legion_ap_changed(legion_b)
	elif "combat_resolved" in events:
		await _action_playback.play_combat(from_coords, to_coords, payload.get("combat", {}))
		_cleanup_dead_legion(from_coords)
		_cleanup_dead_legion(to_coords)
		ui.deselect()
		input.end_action()
		return
	elif "legion_healed" in events:
		await _action_playback.play_heal(from_coords, payload, {
			"deselect_after": true,
			"deselect": ui.deselect,
			"on_ap_changed": _notify_legion_ap_changed,
		})
		input.end_action()
		return

	_finish_action_after_tweens(tweens, func() -> void:
		ui.refresh_after_action(refresh_coords)
		input.end_action()
	)

func _animate_resolved_move(from_coords: Vector2i, to_coords: Vector2i) -> Tween:
	var from_visu: TileVisu = grid_visu.get(from_coords)
	var to_visu: TileVisu = grid_visu.get(to_coords)
	if not from_visu or not to_visu or not from_visu.legion_visu:
		return null
	var legion_visu: LegionVisu = from_visu.legion_visu
	from_visu.legion_visu = null
	to_visu.legion_visu = legion_visu
	return legion_visu.juice_move(to_visu.position)

func _animate_resolved_swap(from_coords: Vector2i, to_coords: Vector2i) -> Array:
	var from_visu: TileVisu = grid_visu.get(from_coords)
	var to_visu: TileVisu = grid_visu.get(to_coords)
	if not from_visu or not to_visu or not from_visu.legion_visu or not to_visu.legion_visu:
		return []
	var visu_a: LegionVisu = from_visu.legion_visu
	var visu_b: LegionVisu = to_visu.legion_visu
	from_visu.legion_visu = visu_b
	to_visu.legion_visu = visu_a
	return [
		visu_a.juice_move(to_visu.position),
		visu_b.juice_move(from_visu.position),
	]

func _finish_action_after_tweens(tweens: Array, on_done: Callable) -> void:
	for tween in tweens:
		if tween != null and is_instance_valid(tween):
			await tween.finished
	if on_done.is_valid():
		on_done.call()

func _legion_visu_for(legion: Legion) -> LegionVisu:
	for tile_visu in grid_visu.values():
		if tile_visu and tile_visu.legion_visu and tile_visu.legion_visu.legion == legion:
			return tile_visu.legion_visu
	return null

func _cleanup_dead_legion(coords: Vector2i) -> void:
	var tile: Tile = grid_model.get(coords)
	var visu: TileVisu = grid_visu.get(coords)
	if not tile or not visu:
		return
	if tile.legion and tile.legion.units.size() > 0:
		return
	if tile.legion:
		legions.erase(tile.legion)
	tile.legion = null
	if visu.legion_visu:
		visu.legion_visu.queue_free()
	visu.legion_visu = null
