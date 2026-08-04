class_name DraftPhaseController
extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")
const AiDrafter = preload("res://scripts/ai/ai_drafter.gd")

const INVALID_COORDS := Vector2i(2147483646, 2147483646)

signal battle_started

var deps: MinigamePhaseDeps
var viewing_team: String = ""
var selected_coords: Vector2i = INVALID_COORDS
var picker_for_change_type: bool = false

func _init(phase_deps: MinigamePhaseDeps) -> void:
	deps = phase_deps

func enter(first_team_id: String) -> void:
	viewing_team = first_team_id
	selected_coords = INVALID_COORDS
	deps.tile_info_panel.set_draft_mode(true)
	if deps.action_log_panel:
		deps.action_log_panel.exit_battle()
	refresh_view()

func exit() -> void:
	deps.pass_overlay.hide()
	deps.setup_panel.hide()
	deps.unit_picker.hide()
	deps.tile_info_panel.hide()
	deps.presenter.clear_deploy_overlays()
	deps.presenter.sync_draft_previews([], viewing_team)

func is_blocking_input() -> bool:
	return deps.pass_overlay.visible or deps.game_over_panel.visible

func handle_tile_clicked(coords: Vector2i) -> void:
	if deps.session.phase != MinigameSessionScript.Phase.DRAFT:
		return
	if is_blocking_input() or deps.unit_picker.visible:
		return
	if deps.session.active_draft_team != viewing_team:
		return
	if not _is_deploy_slot(coords):
		return
	_play_draft_click_sound(coords)

	selected_coords = coords
	if _slot_is_occupied(coords):
		_show_draft_tile_info(coords)
		refresh_view()
	else:
		deps.tile_info_panel.hide()
		picker_for_change_type = false
		deps.unit_picker.open_for_slot(coords)

func handle_tile_right_clicked(coords: Vector2i) -> void:
	if deps.session.phase != MinigameSessionScript.Phase.DRAFT:
		return
	if is_blocking_input() or deps.unit_picker.visible:
		return
	if deps.session.active_draft_team != viewing_team:
		return
	inspect_tile(coords)

func inspect_tile(coords: Vector2i) -> void:
	if not deps.tile_info_panel:
		return
	var tile: Tile = deps.session.grid.get(coords)
	if tile and tile.has_legion():
		deps.tile_info_panel.show_tile(tile)
		return
	if deps.session.phase != MinigameSessionScript.Phase.DRAFT:
		return
	selected_coords = coords
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	var placement := _find_placement(draft, coords)
	if not placement.is_empty():
		_show_draft_tile_info(coords)
		deps.presenter.paint_deploy_zones(
			deps.session.get_deploy_slots(viewing_team),
			_collect_occupied_coords(draft),
			selected_coords
		)
		return
	deps.tile_info_panel.hide()

func handle_ready() -> void:
	var result: Dictionary = deps.session.apply({"type": "draft_ready", "team": viewing_team})
	if not result["ok"]:
		_show_error_toast(result["error"])
		return
	if deps.session.phase == MinigameSessionScript.Phase.BATTLE:
		battle_started.emit()
		return
	if deps.is_ai_team(deps.session.active_draft_team):
		_apply_ai_draft(deps.session.active_draft_team)
		if deps.session.phase == MinigameSessionScript.Phase.BATTLE:
			battle_started.emit()
		return
	_show_pass_overlay()

func handle_pass_continue() -> void:
	deps.pass_overlay.hide()
	viewing_team = deps.session.active_draft_team
	selected_coords = INVALID_COORDS
	refresh_view()
	deps.setup_panel.show()

func handle_unit_picked(unit_type: String) -> void:
	if selected_coords == INVALID_COORDS:
		return
	var count := 1
	if _slot_is_occupied(selected_coords):
		var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
		var existing := _find_placement(draft, selected_coords)
		count = int(existing.get("unit_count", 1))
	_apply_placement(unit_type, count)

func handle_picker_cancelled() -> void:
	if picker_for_change_type:
		refresh_view()
		return
	selected_coords = INVALID_COORDS
	refresh_view()

func handle_change_type() -> void:
	if selected_coords == INVALID_COORDS:
		return
	picker_for_change_type = true
	deps.unit_picker.open_for_slot(selected_coords)

func handle_count_increase() -> void:
	if selected_coords == INVALID_COORDS:
		return
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	var placement := _find_placement(draft, selected_coords)
	if placement.is_empty():
		return
	var unit_type: String = String(placement.get("unit_type", ""))
	var count: int = int(placement.get("unit_count", 1)) + 1
	_apply_placement(unit_type, count)

func handle_count_decrease() -> void:
	if selected_coords == INVALID_COORDS:
		return
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	var placement := _find_placement(draft, selected_coords)
	if placement.is_empty():
		return
	var unit_type: String = String(placement.get("unit_type", ""))
	var count: int = maxi(1, int(placement.get("unit_count", 1)) - 1)
	_apply_placement(unit_type, count)

func handle_count_min() -> void:
	if selected_coords == INVALID_COORDS:
		return
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	var placement := _find_placement(draft, selected_coords)
	if placement.is_empty():
		return
	_apply_placement(String(placement.get("unit_type", "")), 1)

func handle_count_max() -> void:
	if selected_coords == INVALID_COORDS:
		return
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	var placement := _find_placement(draft, selected_coords)
	if placement.is_empty():
		return
	var unit_type: String = String(placement.get("unit_type", ""))
	var current: int = int(placement.get("unit_count", 1))
	var remaining: int = int(draft.get("remaining_budget", 0))
	var count := MinigameRulesScript.max_affordable_unit_count(unit_type, current, remaining)
	_apply_placement(unit_type, count)

func handle_clear_slot() -> void:
	if selected_coords == INVALID_COORDS:
		return
	var result: Dictionary = deps.session.apply({
		"type": "draft_clear_slot",
		"team": viewing_team,
		"coords": selected_coords,
	})
	if result["ok"]:
		selected_coords = INVALID_COORDS
		refresh_view()

func refresh_view() -> void:
	var view: Dictionary = deps.session.get_view_state(viewing_team)
	var draft: Dictionary = view.get("draft", {})
	deps.setup_panel.show_for_team(viewing_team, draft)

	var slots: Array = view.get("deploy_slots", [])
	var occupied: Array = []
	for p in draft.get("placements", []):
		occupied.append(p.get("coords", Vector2i.ZERO))

	deps.presenter.paint_deploy_zones(slots, occupied, selected_coords)
	deps.presenter.sync_draft_previews(draft.get("placements", []), viewing_team)

	if selected_coords != INVALID_COORDS:
		var placement := _find_placement(draft, selected_coords)
		if placement:
			_show_draft_tile_info(selected_coords)
		else:
			deps.tile_info_panel.hide()
	else:
		deps.tile_info_panel.hide()

func _apply_placement(unit_type: String, unit_count: int) -> void:
	var result: Dictionary = deps.session.apply({
		"type": "draft_set_legion",
		"team": viewing_team,
		"coords": selected_coords,
		"unit_type": unit_type,
		"unit_count": unit_count,
	})
	if not result["ok"]:
		deps.status_label.text = result["error"]
		_show_error_toast(result["error"])
	else:
		refresh_view()

func _show_pass_overlay() -> void:
	var next_team: String = deps.session.active_draft_team
	var team_res: Resource = TeamDefs.get_def(next_team)
	var display_name: String = next_team
	if team_res is TeamDefinition:
		display_name = (team_res as TeamDefinition).display_name
	deps.status_label.text = "Pass device to %s" % display_name
	deps.pass_overlay.show()
	deps.setup_panel.hide()
	deps.unit_picker.hide()
	deps.presenter.clear_deploy_overlays()
	deps.presenter.sync_draft_previews([], viewing_team)

func _apply_ai_draft(team_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for cmd in AiDrafter.build_draft_commands(deps.session, team_id, rng):
		var draft_result: Dictionary = deps.session.apply(cmd)
		if not draft_result["ok"]:
			push_error("AI draft failed: %s" % draft_result["error"])
			return

func _show_draft_tile_info(coords: Vector2i) -> void:
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	var placement := _find_placement(draft, coords)
	if placement.is_empty():
		deps.tile_info_panel.hide()
		return
	var unit_count := int(placement.get("unit_count", 1))
	var legion := Legion.new(
		String(placement.get("unit_type", "")),
		unit_count,
		coords,
		viewing_team
	)
	deps.tile_info_panel.show_draft_legion(
		legion,
		int(draft.get("remaining_budget", 0)),
		coords,
		unit_count
	)

func _show_error_toast(message: String) -> void:
	if deps.tile_info_panel and deps.tile_info_panel.visible:
		deps.tile_info_panel.show_draft_message(message)

func _play_draft_click_sound(coords: Vector2i) -> void:
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	var placement := _find_placement(draft, coords)
	if placement.is_empty():
		AudioManager.play_sfx("tile_click")
		return
	AudioManager.play_unit_click(String(placement.get("unit_type", "")))

func _find_placement(draft: Dictionary, coords: Vector2i) -> Dictionary:
	for p in draft.get("placements", []):
		if p.get("coords", Vector2i.ZERO) == coords:
			return p
	return {}

func _is_deploy_slot(coords: Vector2i) -> bool:
	return coords in deps.session.get_deploy_slots(viewing_team)

func _slot_is_occupied(coords: Vector2i) -> bool:
	var draft: Dictionary = deps.session.get_view_state(viewing_team).get("draft", {})
	return not _find_placement(draft, coords).is_empty()

func _collect_occupied_coords(draft: Dictionary) -> Array:
	var occupied: Array = []
	for p in draft.get("placements", []):
		occupied.append(p.get("coords", Vector2i.ZERO))
	return occupied
