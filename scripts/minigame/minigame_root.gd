class_name MinigameRoot
extends Node2D

const CONFIG_PATH := "res://data/minigame/duel_r3.tres"
const MINIGAME_SCENE := "res://scenes/runnables/minigame.tscn"
const MENU_SCENE := "res://scenes/runnables/menu.tscn"

const ActionPlaybackScript = preload("res://scripts/battle/action_playback.gd")
const BattleContextScript = preload("res://scripts/battle/battle_context.gd")
const BattleUIAdapterScript = preload("res://scripts/ui/battle_ui_adapter.gd")
const BattleActionRunnerScript = preload("res://scripts/battle/battle_action_runner.gd")
const BattleHostWiringScript = preload("res://scripts/battle/battle_host_wiring.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigamePresenterScript = preload("res://scripts/minigame/minigame_presenter.gd")
const MinigamePhaseDepsScript = preload("res://scripts/minigame/minigame_phase_deps.gd")
const DraftPhaseControllerScript = preload("res://scripts/minigame/draft_phase_controller.gd")
const BattlePhaseControllerScript = preload("res://scripts/minigame/battle_phase_controller.gd")

@export var config_path: String = CONFIG_PATH

var session
var presenter: MinigamePresenterScript
var battle_context: BattleContextScript
var battle_ui: BattleUIAdapterScript
var action_runner: BattleActionRunnerScript
var deps: MinigamePhaseDepsScript
var draft: DraftPhaseControllerScript
var battle: BattlePhaseControllerScript

var _ui_layer: CanvasLayer
var _overlay_layer: CanvasLayer
var _setup_panel: MinigameSetupPanel
var _unit_picker: MinigameUnitPicker
var _turn_hud: TurnHud
var _tile_info_panel: TileInfoPanel
var _combat_fx_layer: CanvasLayer
var _action_playback: RefCounted
var _pass_overlay: PanelContainer
var _pass_continue_btn: GameButton
var _status_label: Label
var _game_over_panel: GameOverPanel
var _action_bar: Control
var _tooltip_controller: TooltipController
var _action_log_panel: BattleActionLogPanel
var _pause_menu: PauseMenu

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	AudioManager.ensure_music()
	var config: MinigameConfig = GameSettings.resolve_minigame_config(config_path)
	if config == null:
		push_error("Failed to load minigame config: %s" % config_path)
		return

	session = MinigameSessionScript.new(config)
	presenter = $MinigamePresenter
	action_runner = BattleActionRunnerScript.new()
	_setup_ui()
	_setup_phase_controllers()
	_setup_battle_context()
	battle_ui = BattleUIAdapterScript.new(battle_context)
	deps.battle_ui = battle_ui
	_connect_phase_signals()

	presenter.build_map(session)
	draft.enter(config.first_team_id())
	EventBus.tile_clicked.connect(_on_tile_clicked)
	EventBus.tile_right_clicked.connect(_on_tile_right_clicked)
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
	if battle.is_input_locked() or _unit_picker.visible:
		return
	if session.phase != MinigameSessionScript.Phase.BATTLE:
		return
	if BattleHostWiringScript.handle_hotkeys(event, battle_ui):
		get_viewport().set_input_as_handled()

func _toggle_pause_menu() -> void:
	if _game_over_panel and _game_over_panel.visible:
		return
	if _pause_menu == null:
		return
	if _pause_menu.is_open():
		_pause_menu.close_menu()
	else:
		if battle_ui:
			battle_ui.deselect()
			battle_ui.clear_overlays()
		_pause_menu.open_menu()

func _on_pause_resume() -> void:
	if _pause_menu:
		_pause_menu.close_menu()

func _on_pause_abandon() -> void:
	GameSettings.clear_match_launch()
	get_tree().change_scene_to_file(MENU_SCENE)

func inspect_tile(coords: Vector2i) -> void:
	if session.phase == MinigameSessionScript.Phase.DRAFT:
		draft.inspect_tile(coords)
	else:
		battle.inspect_tile(coords)

func clear_inspect() -> void:
	if _tile_info_panel:
		_tile_info_panel.hide()

func request_use_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	await battle.request_use_action(action_id, from_coords, to_coords)

func _setup_phase_controllers() -> void:
	deps = MinigamePhaseDepsScript.new()
	deps.host = self
	deps.session = session
	deps.presenter = presenter
	deps.action_runner = action_runner
	deps.action_playback = _action_playback
	deps.setup_panel = _setup_panel
	deps.unit_picker = _unit_picker
	deps.turn_hud = _turn_hud
	deps.tile_info_panel = _tile_info_panel
	deps.pass_overlay = _pass_overlay
	deps.status_label = _status_label
	deps.game_over_panel = _game_over_panel
	deps.action_bar = _action_bar
	deps.action_log_panel = _action_log_panel
	deps.pause_menu = _pause_menu

	draft = DraftPhaseControllerScript.new(deps)
	battle = BattlePhaseControllerScript.new(deps)
	draft.battle_started.connect(_on_battle_started)

func _setup_battle_context() -> void:
	battle_context = BattleContextScript.new()
	BattleHostWiringScript.wire_core_context(
		battle_context,
		session,
		presenter,
		func() -> bool: return battle.is_input_locked(),
		func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
			request_use_action(action_id, from_coords, to_coords),
		func(coords: Vector2i) -> void: inspect_tile(coords),
		func() -> void: clear_inspect(),
		func() -> Node: return _overlay_layer
	)
	battle_context.apply_move_path_fn = func(path: Array) -> void:
		battle.request_move_path(path)
	battle_context.battle_phase_fn = func() -> bool: return session.phase == MinigameSessionScript.Phase.BATTLE

func _connect_phase_signals() -> void:
	_setup_panel.ready_pressed.connect(func() -> void: draft.handle_ready())
	_unit_picker.unit_selected.connect(func(unit_type: String) -> void: draft.handle_unit_picked(unit_type))
	_unit_picker.cancelled.connect(func() -> void: draft.handle_picker_cancelled())
	_turn_hud.next_turn_pressed.connect(func() -> void: battle.handle_end_turn())
	_tile_info_panel.draft_count_min_pressed.connect(func() -> void: draft.handle_count_min())
	_tile_info_panel.draft_count_decrease_pressed.connect(func() -> void: draft.handle_count_decrease())
	_tile_info_panel.draft_count_increase_pressed.connect(func() -> void: draft.handle_count_increase())
	_tile_info_panel.draft_count_max_pressed.connect(func() -> void: draft.handle_count_max())
	_tile_info_panel.draft_clear_slot_pressed.connect(func() -> void: draft.handle_clear_slot())
	_tile_info_panel.draft_change_type_pressed.connect(func() -> void: draft.handle_change_type())
	_tile_info_panel.draft_move_pressed.connect(func() -> void: draft.handle_move_mode())
	_pass_continue_btn.pressed.connect(_on_pass_continue_pressed)
	battle_ui.attach_action_bar(_action_bar)

func _on_pass_continue_pressed() -> void:
	if session.phase == MinigameSessionScript.Phase.BATTLE:
		battle.handle_pass_continue()
	else:
		draft.handle_pass_continue()

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	add_child(_ui_layer)

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "OverlayUI"
	_overlay_layer.layer = 10
	add_child(_overlay_layer)

	_setup_panel = preload("res://scenes/ui/minigame_setup_panel.tscn").instantiate()
	_ui_layer.add_child(_setup_panel)

	_unit_picker = preload("res://scenes/ui/minigame_unit_picker.tscn").instantiate()
	_ui_layer.add_child(_unit_picker)

	_turn_hud = preload("res://scenes/ui/turn_hud.tscn").instantiate()
	_ui_layer.add_child(_turn_hud)
	_turn_hud.hide()

	_tile_info_panel = preload("res://scenes/ui/tile_info_panel.tscn").instantiate()
	_ui_layer.add_child(_tile_info_panel)
	_tile_info_panel.hide()

	_action_bar = preload("res://scenes/ui/battle_action_bar.tscn").instantiate()
	_ui_layer.add_child(_action_bar)

	_tooltip_controller = TooltipController.new()
	_ui_layer.add_child(_tooltip_controller)
	if _tile_info_panel.has_method("set_tooltip_controller"):
		_tile_info_panel.set_tooltip_controller(_tooltip_controller)
	if _action_bar.has_method("set_tooltip_controller"):
		_action_bar.set_tooltip_controller(_tooltip_controller)

	_action_log_panel = BattleActionLogPanel.new()
	_ui_layer.add_child(_action_log_panel)
	_action_log_panel.set_tooltip_controller(_tooltip_controller)
	EventBus.battle_log_entry_added.connect(_on_battle_log_entry_added)

	_combat_fx_layer = CanvasLayer.new()
	_combat_fx_layer.name = "CombatFX"
	_combat_fx_layer.layer = 2
	add_child(_combat_fx_layer)
	_action_playback = ActionPlaybackScript.new(
		self,
		func(c: Vector2i) -> TileVisu: return presenter.tile_visu_at(c),
		func(legion: Legion) -> LegionVisu: return presenter.get_legion_visu(legion),
		_combat_fx_layer
	)

	_pass_overlay = PanelContainer.new()
	_pass_overlay.visible = false
	_pass_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pass_vbox := VBoxContainer.new()
	pass_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pass_vbox.set_anchors_preset(Control.PRESET_CENTER)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 36)
	_pass_continue_btn = preload("res://scenes/ui/game_button.tscn").instantiate()
	_pass_continue_btn.text = "Continue"
	_pass_continue_btn.size_preset = GameButton.SizePreset.LARGE
	_pass_continue_btn.preferred_width = 280
	pass_vbox.add_child(_status_label)
	pass_vbox.add_child(_pass_continue_btn)
	_pass_overlay.add_child(pass_vbox)
	_ui_layer.add_child(_pass_overlay)

	_game_over_panel = preload("res://scenes/ui/game_over_panel.tscn").instantiate()
	_overlay_layer.add_child(_game_over_panel)
	_game_over_panel.new_game_pressed.connect(_on_game_over_new_game)
	_game_over_panel.main_menu_pressed.connect(_on_game_over_main_menu)

	_pause_menu = PauseMenu.new()
	_overlay_layer.add_child(_pause_menu)
	_pause_menu.resume_pressed.connect(_on_pause_resume)
	_pause_menu.abandon_pressed.connect(_on_pause_abandon)

func _on_tile_clicked(coords: Vector2i) -> void:
	if session.phase == MinigameSessionScript.Phase.DRAFT:
		if draft.is_blocking_input():
			return
		draft.handle_tile_clicked(coords)

func _on_tile_right_clicked(coords: Vector2i) -> void:
	if session.phase == MinigameSessionScript.Phase.DRAFT:
		if draft.is_blocking_input():
			return
		draft.handle_tile_right_clicked(coords)

func _on_battle_started() -> void:
	EventBus.tile_clicked.disconnect(_on_tile_clicked)
	EventBus.tile_right_clicked.disconnect(_on_tile_right_clicked)
	draft.exit()
	battle.enter()

func _on_battle_log_entry_added(entry: Dictionary) -> void:
	if _action_log_panel and session and session.phase == MinigameSessionScript.Phase.BATTLE:
		_action_log_panel.receive_entry(entry)

func _on_legion_ap_changed(legion: Legion) -> void:
	if presenter and session:
		presenter.sync_spent_visuals(session)
	if not _tile_info_panel or not _tile_info_panel.visible:
		return
	var tile: Tile = session.grid.get(legion.tile_coords)
	if tile and tile.has_legion():
		_tile_info_panel.show_tile(tile)

func _on_game_over_new_game() -> void:
	get_tree().change_scene_to_file(MINIGAME_SCENE)

func _on_game_over_main_menu() -> void:
	GameSettings.clear_match_launch()
	get_tree().change_scene_to_file(MENU_SCENE)
