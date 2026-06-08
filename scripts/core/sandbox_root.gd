class_name SandboxRoot
extends Node2D

const SandboxConfigScript = preload("res://scripts/match/sandbox_config.gd")
const SandboxSessionScript = preload("res://scripts/match/sandbox_session.gd")
const BattleContextScript = preload("res://scripts/battle/battle_context.gd")
const BattleUIAdapterScript = preload("res://scripts/ui/battle_ui_adapter.gd")
const BattleActionRunnerScript = preload("res://scripts/battle/battle_action_runner.gd")
const ActionPlaybackScript = preload("res://scripts/battle/action_playback.gd")
const GridPresenterScript = preload("res://scripts/visu/grid_presenter.gd")

const DEFAULT_CONFIG_PATH := "res://data/sandbox/preview_r2.tres"

@export var config_path: String = DEFAULT_CONFIG_PATH
@export var map_radius: int = -1

var session: SandboxSessionScript
var presenter: GridPresenterScript

var grid_model: Dictionary:
	get:
		return session.grid if session else {}

var grid_visu: Dictionary:
	get:
		return presenter.grid_visu if presenter else {}

var legions: Array:
	get:
		return session.legions if session else []
var battle_context: BattleContextScript
var battle_ui: BattleUIAdapterScript
var action_runner: BattleActionRunnerScript
var input: GameInput
var tile_info_panel
var tile_info_layer: CanvasLayer
var combat_fx_layer: CanvasLayer
var turn_hud: TurnHud
var _action_playback: RefCounted

func _ready() -> void:
	var config: SandboxConfigScript = load(config_path)
	if config == null:
		push_error("Failed to load sandbox config: %s" % config_path)
		return
	if map_radius >= 0:
		config = config.duplicate()
		config.map_radius = map_radius

	session = SandboxSessionScript.new(config)
	presenter = GridPresenterScript.new()
	presenter.name = "GridPresenter"
	add_child(presenter)
	presenter.build_map_from_grid(session.grid)

	_setup_battle_context()
	battle_ui = BattleUIAdapterScript.new(battle_context)
	action_runner = BattleActionRunnerScript.new()
	input = GameInput.new(battle_ui.clear_overlays)
	battle_context.is_locked_fn = func() -> bool: return input.is_locked()

	_setup_tile_info_ui()
	_setup_combat_fx_ui()
	_setup_turn_hud()
	EventBus.legion_ap_changed.connect(_on_legion_ap_changed)

func _exit_tree() -> void:
	if battle_ui:
		battle_ui.unbind()

func _input(event: InputEvent) -> void:
	if input.is_locked():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
		battle_ui.cycle_legion_tab()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE:
		battle_ui.pass_current_legion()
		get_viewport().set_input_as_handled()

func end_team_turn() -> void:
	battle_ui.deselect()
	var result := session.apply({"type": "end_turn"})
	if result.get("ok", false) and turn_hud:
		turn_hud.show_active_team(session.turn_manager.active_team_id)
		EventBus.turn_changed.emit(session.turn_manager.active_team_id)

func inspect_tile(coords: Vector2i) -> void:
	if not tile_info_panel:
		return
	var tile: Tile = session.grid.get(coords)
	if not tile or not tile.has_legion():
		tile_info_panel.hide()
		return
	tile_info_panel.show_tile(tile)
	tile_info_panel.show()

func clear_inspect() -> void:
	if tile_info_panel:
		tile_info_panel.hide()

func spawn_unit(coords: Vector2i) -> void:
	var result := session.spawn_unit_at(coords)
	if not result.get("ok", false):
		return
	var legion: Legion = result.get("payload", {}).get("legion")
	if legion:
		presenter.spawn_legion_visu(legion)
		EventBus.legion_ap_changed.emit(legion)

func move_unit(from_coords: Vector2i, to_coords: Vector2i) -> void:
	use_battle_action("move", from_coords, to_coords)

func attack_unit(from_coords: Vector2i, to_coords: Vector2i) -> void:
	use_battle_action("melee_attack", from_coords, to_coords)

func use_battle_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input.is_locked():
		return
	var cmd := {
		"type": "use_action",
		"action_id": action_id,
		"from": from_coords,
		"to": to_coords,
	}
	if action_id == "melee_attack":
		cmd["rng_seed"] = randi()
	await _perform_use_action(cmd, from_coords)

func _perform_use_action(cmd: Dictionary, from_coords: Vector2i) -> void:
	var from_tile: Tile = session.grid.get(from_coords)
	if from_tile == null or not from_tile.has_legion():
		return

	var result := session.apply(cmd)
	if not result.get("ok", false):
		return

	input.begin_action()
	await action_runner.play_result(
		self,
		session,
		presenter,
		_action_playback,
		result,
		from_coords,
		_action_hooks(true)
	)
	input.end_action()

func _setup_battle_context() -> void:
	battle_context = BattleContextScript.new()
	battle_context.session = session
	battle_context.presenter = presenter
	battle_context.apply_action_fn = func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
		use_battle_action(action_id, from_coords, to_coords)
	battle_context.allows_spawn_fn = func(_coords: Vector2i) -> bool: return session.config.allow_spawn
	battle_context.spawn_fn = func(coords: Vector2i) -> void: spawn_unit(coords)
	battle_context.inspect_fn = func(coords: Vector2i) -> void: inspect_tile(coords)
	battle_context.clear_inspect_fn = func() -> void: clear_inspect()

func _action_hooks(unlock_on_finish: bool) -> Dictionary:
	return {
		"session": session,
		"clear_overlays": battle_ui.clear_overlays,
		"deselect": battle_ui.deselect,
		"deselect_before_combat": false,
		"deselect_after_combat": true,
		"deselect_after_heal": true,
		"on_ap_changed": func(legion: Legion) -> void: EventBus.legion_ap_changed.emit(legion),
		"refresh_after_action": battle_ui.refresh_after_action,
		"on_finished": func() -> void: pass,
	}

func _on_legion_ap_changed(legion: Legion) -> void:
	if not tile_info_panel or not tile_info_panel.visible:
		return
	var tile: Tile = session.grid.get(legion.tile_coords)
	if tile and tile.has_legion():
		tile_info_panel.show_tile(tile)

func _setup_turn_hud() -> void:
	if not tile_info_layer:
		return
	turn_hud = preload("res://scenes/ui/turn_hud.tscn").instantiate()
	tile_info_layer.add_child(turn_hud)
	turn_hud.show_active_team(session.turn_manager.active_team_id)
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
	battle_ui.attach_action_bar(action_bar)

func _setup_combat_fx_ui() -> void:
	combat_fx_layer = CanvasLayer.new()
	combat_fx_layer.name = "CombatFX"
	combat_fx_layer.layer = 2
	add_child(combat_fx_layer)
	_action_playback = ActionPlaybackScript.new(
		self,
		func(c: Vector2i) -> TileVisu: return presenter.tile_visu_at(c),
		func(legion: Legion) -> LegionVisu: return presenter.get_legion_visu(legion),
		combat_fx_layer
	)
