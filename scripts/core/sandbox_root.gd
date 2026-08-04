class_name SandboxRoot
extends Node2D

const SandboxConfigScript = preload("res://scripts/match/sandbox_config.gd")
const SandboxSessionScript = preload("res://scripts/match/sandbox_session.gd")
const BattleContextScript = preload("res://scripts/battle/battle_context.gd")
const BattleUIAdapterScript = preload("res://scripts/ui/battle_ui_adapter.gd")
const BattleActionRunnerScript = preload("res://scripts/battle/battle_action_runner.gd")
const BattleHostWiringScript = preload("res://scripts/battle/battle_host_wiring.gd")
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
var _tooltip_controller: TooltipController
var _action_log_panel: BattleActionLogPanel
var _pause_menu: PauseMenu
const MENU_SCENE := "res://scenes/runnables/menu.tscn"

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
	# Input exists only after battle_ui; override lock wired in _setup_battle_context.
	battle_context.is_locked_fn = func() -> bool: return input.is_locked()

	_setup_tile_info_ui()
	_setup_combat_fx_ui()
	_setup_turn_hud()
	EventBus.legion_ap_changed.connect(_on_legion_ap_changed)

func _exit_tree() -> void:
	if battle_ui:
		battle_ui.unbind()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return
	if _pause_menu and _pause_menu.is_open():
		return
	if input.is_locked():
		return
	if BattleHostWiringScript.handle_hotkeys(event, battle_ui):
		get_viewport().set_input_as_handled()

func _toggle_pause_menu() -> void:
	if _pause_menu == null:
		return
	if _pause_menu.is_open():
		_pause_menu.close_menu()
	else:
		if battle_ui:
			battle_ui.deselect()
			battle_ui.clear_overlays()
		_pause_menu.open_menu()

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

func _on_battle_log_entry_added(entry: Dictionary) -> void:
	if _action_log_panel:
		_action_log_panel.receive_entry(entry)

func spawn_unit(coords: Vector2i) -> void:
	var result := session.spawn_unit_at(coords)
	if not result.get("ok", false):
		return
	var legion: Legion = result.get("payload", {}).get("legion")
	if legion:
		presenter.spawn_legion_visu(legion)
		EventBus.legion_ap_changed.emit(legion)

func use_battle_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input.is_locked():
		return
	var cmd := {
		"type": "use_action",
		"action_id": action_id,
		"from": from_coords,
		"to": to_coords,
	}
	cmd.merge(BattleHostWiringScript.rng_seed_for_action(action_id))
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
		BattleHostWiringScript.action_hooks(session, battle_ui, {
			"deselect_after_combat": true,
			"deselect_after_heal": true,
			"on_finished": func() -> void:
				presenter.sync_spent_visuals(session),
		})
	)
	if _action_log_panel:
		_action_log_panel.reveal_pending()
	input.end_action()

func _setup_battle_context() -> void:
	battle_context = BattleContextScript.new()
	BattleHostWiringScript.wire_core_context(
		battle_context,
		session,
		presenter,
		func() -> bool: return false,
		func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
			use_battle_action(action_id, from_coords, to_coords),
		func(coords: Vector2i) -> void: inspect_tile(coords),
		func() -> void: clear_inspect(),
		func() -> Node: return tile_info_layer
	)
	battle_context.allows_spawn_fn = func(_coords: Vector2i) -> bool: return session.config.allow_spawn
	battle_context.spawn_fn = func(coords: Vector2i) -> void: spawn_unit(coords)
	battle_context.apply_move_path_fn = func(path: Array) -> void:
		for i in range(1, path.size()):
			use_battle_action("move", path[i - 1], path[i])

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

	_tooltip_controller = TooltipController.new()
	tile_info_layer.add_child(_tooltip_controller)
	if tile_info_panel.has_method("set_tooltip_controller"):
		tile_info_panel.set_tooltip_controller(_tooltip_controller)
	if action_bar.has_method("set_tooltip_controller"):
		action_bar.set_tooltip_controller(_tooltip_controller)

	_action_log_panel = BattleActionLogPanel.new()
	tile_info_layer.add_child(_action_log_panel)
	_action_log_panel.set_tooltip_controller(_tooltip_controller)
	_action_log_panel.enter_battle(session.action_log if session else null)
	EventBus.battle_log_entry_added.connect(_on_battle_log_entry_added)

	_pause_menu = PauseMenu.new()
	tile_info_layer.add_child(_pause_menu)
	_pause_menu.resume_pressed.connect(func() -> void: _pause_menu.close_menu())
	_pause_menu.abandon_pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))

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
