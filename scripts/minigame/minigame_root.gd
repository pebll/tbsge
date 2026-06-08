class_name MinigameRoot
extends Node2D

const CONFIG_PATH := "res://data/minigame/duel_r3.tres"
const MINIGAME_SCENE := "res://scenes/runnables/minigame.tscn"
const MENU_SCENE := "res://scenes/runnables/menu.tscn"
const INVALID_COORDS := Vector2i(2147483646, 2147483646)

const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
const ActionPlaybackScript = preload("res://scripts/battle/action_playback.gd")
const BattleContextScript = preload("res://scripts/battle/battle_context.gd")
const BattleUIAdapterScript = preload("res://scripts/ui/battle_ui_adapter.gd")
const BattleActionRunnerScript = preload("res://scripts/battle/battle_action_runner.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigamePresenterScript = preload("res://scripts/minigame/minigame_presenter.gd")

const AI_LEGION_DELAY := 0.5

@export var config_path: String = CONFIG_PATH

var session
var presenter: MinigamePresenterScript
var battle_context: BattleContextScript
var battle_ui: BattleUIAdapterScript
var action_runner: BattleActionRunnerScript
var input_locked: bool = false
var _ai_running: bool = false

var _ui_layer: CanvasLayer
var _setup_panel: MinigameSetupPanel
var _unit_picker: MinigameUnitPicker
var _turn_hud: TurnHud
var _tile_info_panel: TileInfoPanel
var _combat_fx_layer: CanvasLayer
var _action_playback: RefCounted
var _pass_overlay: PanelContainer
var _status_label: Label
var _game_over_panel: GameOverPanel
var _selected_deploy_coords: Vector2i = INVALID_COORDS
var _viewing_team: String = ""
var _picker_for_change_type: bool = false

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	var config: MinigameConfig = load(config_path)
	if config == null:
		push_error("Failed to load minigame config: %s" % config_path)
		return
	session = MinigameSessionScript.new(config)
	presenter = $MinigamePresenter
	_setup_battle_context()
	battle_ui = BattleUIAdapterScript.new(battle_context)
	action_runner = BattleActionRunnerScript.new()
	_setup_ui()
	presenter.build_map(session)
	_viewing_team = session.config.team_ids[0]
	_refresh_draft_view()
	EventBus.tile_clicked.connect(_on_draft_tile_clicked)
	EventBus.tile_right_clicked.connect(_on_tile_right_clicked)
	EventBus.legion_ap_changed.connect(_on_legion_ap_changed)

func _exit_tree() -> void:
	if battle_ui:
		battle_ui.unbind()

func _input(event: InputEvent) -> void:
	if input_locked or _ai_running or _unit_picker.visible:
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

func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	add_child(_ui_layer)

	_setup_panel = preload("res://scenes/ui/minigame_setup_panel.tscn").instantiate()
	_ui_layer.add_child(_setup_panel)
	_setup_panel.ready_pressed.connect(_on_draft_ready)

	_unit_picker = preload("res://scenes/ui/minigame_unit_picker.tscn").instantiate()
	_ui_layer.add_child(_unit_picker)
	_unit_picker.unit_selected.connect(_on_unit_picked)
	_unit_picker.cancelled.connect(_on_picker_cancelled)

	_turn_hud = preload("res://scenes/ui/turn_hud.tscn").instantiate()
	_ui_layer.add_child(_turn_hud)
	_turn_hud.hide()
	_turn_hud.next_turn_pressed.connect(_on_end_turn)

	var action_bar = preload("res://scenes/ui/battle_action_bar.tscn").instantiate()
	_ui_layer.add_child(action_bar)
	battle_ui.attach_action_bar(action_bar)

	_tile_info_panel = preload("res://scenes/ui/tile_info_panel.tscn").instantiate()
	_ui_layer.add_child(_tile_info_panel)
	_tile_info_panel.hide()
	_tile_info_panel.draft_count_increase_pressed.connect(_on_count_increase)
	_tile_info_panel.draft_count_decrease_pressed.connect(_on_count_decrease)
	_tile_info_panel.draft_clear_slot_pressed.connect(_on_clear_slot)
	_tile_info_panel.draft_change_type_pressed.connect(_on_change_type)

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
	var continue_btn: GameButton = preload("res://scenes/ui/game_button.tscn").instantiate()
	continue_btn.text = "Continue"
	continue_btn.size_preset = GameButton.SizePreset.LARGE
	continue_btn.preferred_width = 280
	continue_btn.pressed.connect(_on_pass_continue)
	pass_vbox.add_child(_status_label)
	pass_vbox.add_child(continue_btn)
	_pass_overlay.add_child(pass_vbox)
	_ui_layer.add_child(_pass_overlay)

	_game_over_panel = preload("res://scenes/ui/game_over_panel.tscn").instantiate()
	_ui_layer.add_child(_game_over_panel)
	_game_over_panel.new_game_pressed.connect(_on_game_over_new_game)
	_game_over_panel.main_menu_pressed.connect(_on_game_over_main_menu)

func _refresh_draft_view() -> void:
	var view: Dictionary = session.get_view_state(_viewing_team)
	var draft: Dictionary = view.get("draft", {})
	_setup_panel.show_for_team(_viewing_team, draft)

	var slots: Array = view.get("deploy_slots", [])
	var occupied: Array = []
	for p in draft.get("placements", []):
		occupied.append(p.get("coords", Vector2i.ZERO))

	presenter.paint_deploy_zones(slots, occupied, _selected_deploy_coords)
	presenter.sync_draft_previews(draft.get("placements", []), _viewing_team)

	if _selected_deploy_coords != INVALID_COORDS:
		var placement := _find_placement(draft, _selected_deploy_coords)
		if placement:
			_show_draft_tile_info(_selected_deploy_coords)
		else:
			_tile_info_panel.hide()
	else:
		_tile_info_panel.hide()

func _find_placement(draft: Dictionary, coords: Vector2i) -> Dictionary:
	for p in draft.get("placements", []):
		if p.get("coords", Vector2i.ZERO) == coords:
			return p
	return {}

func _is_deploy_slot(coords: Vector2i) -> bool:
	return coords in session.get_deploy_slots(_viewing_team)

func _slot_is_occupied(coords: Vector2i) -> bool:
	var draft: Dictionary = session.get_view_state(_viewing_team).get("draft", {})
	return not _find_placement(draft, coords).is_empty()

func inspect_tile(coords: Vector2i) -> void:
	if not _tile_info_panel:
		return
	var tile: Tile = session.grid.get(coords)
	if tile and tile.has_legion():
		_tile_info_panel.show_tile(tile)
		return
	if session.phase == MinigameSessionScript.Phase.DRAFT:
		_selected_deploy_coords = coords
		var draft: Dictionary = session.get_view_state(_viewing_team).get("draft", {})
		var placement := _find_placement(draft, coords)
		if not placement.is_empty():
			_show_draft_tile_info(coords)
			presenter.paint_deploy_zones(
				session.get_deploy_slots(_viewing_team),
				_collect_occupied_coords(draft),
				_selected_deploy_coords
			)
			return
	_tile_info_panel.hide()

func _collect_occupied_coords(draft: Dictionary) -> Array:
	var occupied: Array = []
	for p in draft.get("placements", []):
		occupied.append(p.get("coords", Vector2i.ZERO))
	return occupied

func _show_draft_tile_info(coords: Vector2i) -> void:
	var draft: Dictionary = session.get_view_state(_viewing_team).get("draft", {})
	var placement := _find_placement(draft, coords)
	if placement.is_empty():
		_tile_info_panel.hide()
		return
	var unit_count := int(placement.get("unit_count", 1))
	var legion := Legion.new(
		String(placement.get("unit_type", "")),
		unit_count,
		coords,
		_viewing_team
	)
	_tile_info_panel.show_draft_legion(
		legion,
		int(draft.get("remaining_budget", 0)),
		coords,
		unit_count
	)

func clear_inspect() -> void:
	if _tile_info_panel:
		_tile_info_panel.hide()

func _on_legion_ap_changed(legion: Legion) -> void:
	if not _tile_info_panel or not _tile_info_panel.visible:
		return
	var tile: Tile = session.grid.get(legion.tile_coords)
	if tile and tile.has_legion():
		_tile_info_panel.show_tile(tile)

func _on_tile_right_clicked(coords: Vector2i) -> void:
	if session.phase == MinigameSessionScript.Phase.DRAFT:
		if input_locked or _overlay_blocking_input() or _unit_picker.visible:
			return
		if session.active_draft_team != _viewing_team:
			return
		inspect_tile(coords)

func _on_draft_tile_clicked(coords: Vector2i) -> void:
	if session.phase != MinigameSessionScript.Phase.DRAFT:
		return
	if input_locked or _overlay_blocking_input() or _unit_picker.visible:
		return
	if session.active_draft_team != _viewing_team:
		return
	if not _is_deploy_slot(coords):
		return

	_selected_deploy_coords = coords
	if _slot_is_occupied(coords):
		_show_draft_tile_info(coords)
		_refresh_draft_view()
	else:
		_tile_info_panel.hide()
		_picker_for_change_type = false
		_unit_picker.open_for_slot(coords)

func _on_unit_picked(unit_type: String) -> void:
	if _selected_deploy_coords == INVALID_COORDS:
		return
	var count := 1
	if _slot_is_occupied(_selected_deploy_coords):
		var draft: Dictionary = session.get_view_state(_viewing_team).get("draft", {})
		var existing := _find_placement(draft, _selected_deploy_coords)
		count = int(existing.get("unit_count", 1))
	_apply_placement(unit_type, count)

func _on_picker_cancelled() -> void:
	if _picker_for_change_type:
		_refresh_draft_view()
		return
	_selected_deploy_coords = INVALID_COORDS
	_refresh_draft_view()

func _on_change_type() -> void:
	if _selected_deploy_coords == INVALID_COORDS:
		return
	_picker_for_change_type = true
	_unit_picker.open_for_slot(_selected_deploy_coords)

func _on_count_increase() -> void:
	if _selected_deploy_coords == INVALID_COORDS:
		return
	var draft: Dictionary = session.get_view_state(_viewing_team).get("draft", {})
	var placement := _find_placement(draft, _selected_deploy_coords)
	if placement.is_empty():
		return
	var unit_type: String = String(placement.get("unit_type", ""))
	var count: int = int(placement.get("unit_count", 1)) + 1
	_apply_placement(unit_type, count)

func _on_count_decrease() -> void:
	if _selected_deploy_coords == INVALID_COORDS:
		return
	var draft: Dictionary = session.get_view_state(_viewing_team).get("draft", {})
	var placement := _find_placement(draft, _selected_deploy_coords)
	if placement.is_empty():
		return
	var unit_type: String = String(placement.get("unit_type", ""))
	var count: int = maxi(1, int(placement.get("unit_count", 1)) - 1)
	_apply_placement(unit_type, count)

func _apply_placement(unit_type: String, unit_count: int) -> void:
	var result: Dictionary = session.apply({
		"type": "draft_set_legion",
		"team": _viewing_team,
		"coords": _selected_deploy_coords,
		"unit_type": unit_type,
		"unit_count": unit_count,
	})
	if not result["ok"]:
		_status_label.text = result["error"]
		_show_error_toast(result["error"])
	else:
		_refresh_draft_view()

func _on_clear_slot() -> void:
	if _selected_deploy_coords == INVALID_COORDS:
		return
	var result: Dictionary = session.apply({
		"type": "draft_clear_slot",
		"team": _viewing_team,
		"coords": _selected_deploy_coords,
	})
	if result["ok"]:
		_selected_deploy_coords = INVALID_COORDS
		_refresh_draft_view()

func _show_error_toast(message: String) -> void:
	if _tile_info_panel and _tile_info_panel.visible:
		_tile_info_panel.show_draft_message(message)

func _on_draft_ready() -> void:
	var result: Dictionary = session.apply({"type": "draft_ready", "team": _viewing_team})
	if not result["ok"]:
		_show_error_toast(result["error"])
		return
	if session.phase == MinigameSessionScript.Phase.BATTLE:
		_begin_battle()
		_maybe_start_ai_turn()
		return
	if _is_ai_team(session.active_draft_team):
		_apply_ai_draft(session.active_draft_team)
		if session.phase == MinigameSessionScript.Phase.BATTLE:
			_begin_battle()
			_maybe_start_ai_turn()
		return
	_show_pass_overlay()

func _show_pass_overlay() -> void:
	var next_team: String = session.active_draft_team
	var team_res: Resource = TeamDefs.get_def(next_team)
	var name: String = next_team
	if team_res is TeamDefinition:
		name = (team_res as TeamDefinition).display_name
	_status_label.text = "Pass device to %s" % name
	_pass_overlay.show()
	_setup_panel.hide()
	_unit_picker.hide()
	presenter.clear_deploy_overlays()
	presenter.sync_draft_previews([], _viewing_team)

func _on_pass_continue() -> void:
	_pass_overlay.hide()
	_viewing_team = session.active_draft_team
	_selected_deploy_coords = INVALID_COORDS
	_refresh_draft_view()
	_setup_panel.show()

func _begin_battle() -> void:
	EventBus.tile_clicked.disconnect(_on_draft_tile_clicked)
	EventBus.tile_right_clicked.disconnect(_on_tile_right_clicked)
	_setup_panel.hide()
	_tile_info_panel.set_draft_mode(false)
	_tile_info_panel.hide()
	_unit_picker.hide()
	_pass_overlay.hide()
	presenter.clear_deploy_overlays()
	presenter.sync_legions(session)
	_turn_hud.show()
	_turn_hud.show_active_team(session.turn_manager.active_team_id)

func _is_ai_team(team_id: String) -> bool:
	return team_id in session.config.ai_team_ids

func _apply_ai_draft(team_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for cmd in AiDrafter.build_draft_commands(session, team_id, rng):
		var draft_result: Dictionary = session.apply(cmd)
		if not draft_result["ok"]:
			push_error("AI draft failed: %s" % draft_result["error"])
			return

func _maybe_start_ai_turn() -> void:
	if session.phase != MinigameSessionScript.Phase.BATTLE:
		return
	if not _is_ai_team(session.turn_manager.active_team_id):
		return
	if _ai_running:
		return
	_run_ai_turn()

func _run_ai_turn() -> void:
	_run_ai_turn_async()

func _run_ai_turn_async() -> void:
	_ai_running = true
	input_locked = true
	battle_ui.deselect()
	while (
		session.phase == MinigameSessionScript.Phase.BATTLE
		and _is_ai_team(session.turn_manager.active_team_id)
	):
		var actionable := AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(
			session,
			session.get_actionable_coords()
		)
		if actionable.is_empty():
			if AttackNearestEnemyBehavior.debug_enabled:
				print("[AI] %s ending turn (no actionable legions)" % session.turn_manager.active_team_id)
			var end_result: Dictionary = session.apply({"type": "end_turn"})
			if end_result["ok"]:
				_turn_hud.show_active_team(session.turn_manager.active_team_id)
			break

		var coords: Vector2i = actionable[0]
		var legion: Legion = session.get_legion_at(coords)
		if legion == null:
			if AttackNearestEnemyBehavior.debug_enabled:
				print("[AI] stale legion slot @ %s, skipping" % coords)
			session.pass_legion_or_force_wait(coords)
			await get_tree().create_timer(AI_LEGION_DELAY).timeout
			continue

		var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, legion)
		match String(cmd.get("type", "")):
			"use_action":
				var ok := await _perform_use_action(
					String(cmd.get("action_id", "")),
					cmd.get("from", coords),
					cmd.get("to", coords),
					int(cmd.get("rng_seed", randi()))
				)
				if not ok:
					if AttackNearestEnemyBehavior.debug_enabled:
						print("[AI] action failed for %s @ %s, passing legion" % [legion.team_id, coords])
					session.pass_legion_or_force_wait(coords)
			_:
				session.pass_legion_or_force_wait(coords)

		await get_tree().create_timer(AI_LEGION_DELAY).timeout
		if session.phase == MinigameSessionScript.Phase.ENDED:
			break

	_ai_running = false
	input_locked = false
	_check_match_end()
	if session.phase == MinigameSessionScript.Phase.BATTLE and _is_ai_team(session.turn_manager.active_team_id):
		_maybe_start_ai_turn()

func _on_end_turn() -> void:
	if input_locked or _ai_running:
		return
	battle_ui.deselect()
	var result: Dictionary = session.apply({"type": "end_turn"})
	if result["ok"]:
		_turn_hud.show_active_team(session.turn_manager.active_team_id)
		_maybe_start_ai_turn()

func request_use_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if input_locked or _ai_running:
		return
	await _perform_use_action(action_id, from_coords, to_coords, randi())

func _perform_use_action(
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	rng_seed: int = 0
) -> bool:
	var cmd := {
		"type": "use_action",
		"action_id": action_id,
		"from": from_coords,
		"to": to_coords,
	}
	if action_id == "melee_attack":
		cmd["rng_seed"] = rng_seed

	var from_tile: Tile = session.grid.get(from_coords)
	if from_tile == null or not from_tile.has_legion():
		return false

	var result: Dictionary = session.apply(cmd)
	if not result["ok"]:
		if AttackNearestEnemyBehavior.debug_enabled:
			print(
				"[AI] action rejected: %s %s -> %s (%s)"
				% [action_id, from_coords, to_coords, result.get("error", "?")]
			)
		return false

	if not _ai_running:
		input_locked = true

	var played := await action_runner.play_result(
		self,
		session,
		presenter,
		_action_playback,
		result,
		from_coords,
		_battle_action_hooks()
	)
	if not _ai_running:
		input_locked = false
	_check_match_end()
	return played

func _setup_battle_context() -> void:
	battle_context = BattleContextScript.new()
	battle_context.session = session
	battle_context.presenter = presenter
	battle_context.is_locked_fn = func() -> bool: return input_locked or _ai_running
	battle_context.apply_action_fn = func(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
		request_use_action(action_id, from_coords, to_coords)
	battle_context.battle_phase_fn = func() -> bool: return session.phase == MinigameSessionScript.Phase.BATTLE
	battle_context.inspect_fn = func(coords: Vector2i) -> void: inspect_tile(coords)
	battle_context.clear_inspect_fn = func() -> void: clear_inspect()

func _battle_action_hooks() -> Dictionary:
	return {
		"session": session,
		"clear_overlays": battle_ui.clear_overlays,
		"deselect": battle_ui.deselect,
		"deselect_before_combat": true,
		"deselect_after_heal": not _ai_running,
		"on_ap_changed": func(legion: Legion) -> void: EventBus.legion_ap_changed.emit(legion),
		"refresh_after_action": battle_ui.refresh_after_action,
		"on_finished": func() -> void: pass,
	}

func _overlay_blocking_input() -> bool:
	return _pass_overlay.visible or _game_over_panel.visible

func _check_match_end() -> void:
	if session.phase != MinigameSessionScript.Phase.ENDED:
		return
	battle_ui.deselect()
	_turn_hud.hide()
	_setup_panel.hide()
	_unit_picker.hide()
	_tile_info_panel.hide()
	_game_over_panel.show_for_winner(session.winner)

func _on_game_over_new_game() -> void:
	get_tree().change_scene_to_file(MINIGAME_SCENE)

func _on_game_over_main_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
