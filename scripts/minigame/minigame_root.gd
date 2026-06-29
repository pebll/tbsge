class_name MinigameRoot
extends Node2D

const CONFIG_PATH := "res://data/minigame/duel_r3.tres"
const MINIGAME_SCENE := "res://scenes/runnables/minigame.tscn"
const MENU_SCENE := "res://scenes/runnables/menu.tscn"

const ActionPlaybackScript = preload("res://scripts/battle/action_playback.gd")
const BattleContextScript = preload("res://scripts/battle/battle_context.gd")
const BattleUIAdapterScript = preload("res://scripts/ui/battle_ui_adapter.gd")
const BattleActionRunnerScript = preload("res://scripts/battle/battle_action_runner.gd")
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

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	var config: MinigameConfig = load(config_path)
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
	if battle.is_input_locked() or _unit_picker.visible:
		return
	if session.phase != MinigameSessionScript.Phase.BATTLE:
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

	draft = DraftPhaseControllerScript.new(deps)
	battle = BattlePhaseControllerScript.new(deps)
	draft.battle_started.connect(_on_battle_started)

func _setup_battle_context() -> void:
	battle_context = BattleContextScript.new()
	battle_context.session = session
	battle_context.presenter = presenter
	battle_context.is_locked_fn = func() -> bool: return battle.is_input_locked()
	battle_context.apply_action_fn = func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
		request_use_action(action_id, from_coords, to_coords)
	battle_context.battle_phase_fn = func() -> bool: return session.phase == MinigameSessionScript.Phase.BATTLE
	battle_context.inspect_fn = func(coords: Vector2i) -> void: inspect_tile(coords)
	battle_context.clear_inspect_fn = func() -> void: clear_inspect()

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
	_pass_continue_btn.pressed.connect(func() -> void: draft.handle_pass_continue())
	battle_ui.attach_action_bar(_action_bar)

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

func _on_legion_ap_changed(legion: Legion) -> void:
	if not _tile_info_panel or not _tile_info_panel.visible:
		return
	var tile: Tile = session.grid.get(legion.tile_coords)
	if tile and tile.has_legion():
		_tile_info_panel.show_tile(tile)

func _on_game_over_new_game() -> void:
	get_tree().change_scene_to_file(MINIGAME_SCENE)

func _on_game_over_main_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
