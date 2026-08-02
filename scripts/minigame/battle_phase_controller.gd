class_name BattlePhaseController
extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")

const AI_LEGION_DELAY := 0.5

signal ai_turn_finished

var deps: MinigamePhaseDeps
var input_locked: bool = false
var ai_running: bool = false
var _action_in_flight: bool = false

func _init(phase_deps: MinigamePhaseDeps) -> void:
	deps = phase_deps

func enter() -> void:
	deps.tile_info_panel.set_draft_mode(false)
	deps.tile_info_panel.hide()
	deps.presenter.sync_legions(deps.session)
	deps.turn_hud.show()
	deps.turn_hud.show_active_team(deps.session.turn_manager.active_team_id)
	maybe_start_ai_turn()

func exit() -> void:
	deps.turn_hud.hide()

func is_input_locked() -> bool:
	return input_locked or ai_running or _action_in_flight

func is_blocking_input() -> bool:
	return deps.game_over_panel.visible

func handle_end_turn() -> void:
	if is_input_locked():
		return
	deps.battle_ui.deselect()
	var result: Dictionary = deps.session.apply({"type": "end_turn"})
	if result["ok"]:
		deps.turn_hud.show_active_team(deps.session.turn_manager.active_team_id)
		maybe_start_ai_turn()

func request_use_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if is_input_locked():
		return
	await perform_use_action(action_id, from_coords, to_coords, randi())

func perform_use_action(
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	rng_seed: int = 0
) -> bool:
	if _action_in_flight:
		return false
	_action_in_flight = true

	var cmd := {
		"type": "use_action",
		"action_id": action_id,
		"from": from_coords,
		"to": to_coords,
	}
	if action_id == "melee_attack" or action_id == "ranged_attack":
		cmd["rng_seed"] = rng_seed

	var from_tile: Tile = deps.session.grid.get(from_coords)
	if from_tile == null or not from_tile.has_legion():
		_action_in_flight = false
		return false

	var result: Dictionary = deps.session.apply(cmd)
	if not result["ok"]:
		if AttackNearestEnemyBehavior.debug_enabled:
			print(
				"[AI] action rejected: %s %s -> %s (%s)"
				% [action_id, from_coords, to_coords, result.get("error", "?")]
			)
		_action_in_flight = false
		return false

	if not ai_running:
		input_locked = true

	# Model already committed — treat as success even if visuals cannot play.
	await deps.action_runner.play_result(
		deps.host,
		deps.session,
		deps.presenter,
		deps.action_playback,
		result,
		from_coords,
		_battle_action_hooks()
	)
	if not ai_running:
		input_locked = false
		# Ensure selection/overlays never stick after a resolved action.
		deps.battle_ui.deselect()
		deps.battle_ui.clear_overlays()
	check_match_end()
	_action_in_flight = false
	return true

func maybe_start_ai_turn() -> void:
	if deps.session.phase != MinigameSessionScript.Phase.BATTLE:
		return
	if not deps.is_ai_team(deps.session.turn_manager.active_team_id):
		return
	if ai_running:
		return
	_run_ai_turn_async()

func check_match_end() -> void:
	if deps.session.phase != MinigameSessionScript.Phase.ENDED:
		return
	deps.action_playback.dismiss_fx_tail()
	deps.battle_ui.deselect()
	deps.battle_ui.clear_overlays()
	deps.turn_hud.hide()
	deps.setup_panel.hide()
	deps.unit_picker.hide()
	deps.tile_info_panel.hide()
	if deps.action_bar:
		deps.action_bar.hide()
	deps.game_over_panel.show_for_winner(deps.session.winner)

func inspect_tile(coords: Vector2i) -> void:
	if not deps.tile_info_panel:
		return
	var tile: Tile = deps.session.grid.get(coords)
	if tile and tile.has_legion():
		deps.tile_info_panel.show_tile(tile)
	else:
		deps.tile_info_panel.hide()

func _run_ai_turn_async() -> void:
	ai_running = true
	input_locked = true
	deps.battle_ui.deselect()
	while (
		deps.session.phase == MinigameSessionScript.Phase.BATTLE
		and deps.is_ai_team(deps.session.turn_manager.active_team_id)
	):
		var actionable := AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(
			deps.session,
			deps.session.get_actionable_coords()
		)
		if actionable.is_empty():
			if AttackNearestEnemyBehavior.debug_enabled:
				print(
					"[AI] %s ending turn (no actionable legions)"
					% deps.session.turn_manager.active_team_id
				)
			var end_result: Dictionary = deps.session.apply({"type": "end_turn"})
			if end_result["ok"]:
				deps.turn_hud.show_active_team(deps.session.turn_manager.active_team_id)
			break

		var coords: Vector2i = actionable[0]
		var legion: Legion = deps.session.get_legion_at(coords)
		if legion == null:
			if AttackNearestEnemyBehavior.debug_enabled:
				print("[AI] stale legion slot @ %s, skipping" % coords)
			deps.session.pass_legion_or_force_wait(coords)
			await deps.host.get_tree().create_timer(AI_LEGION_DELAY).timeout
			continue

		var cmd: Dictionary = AttackNearestEnemyBehavior.decide(deps.session, legion)
		match String(cmd.get("type", "")):
			"use_action":
				var ok := await perform_use_action(
					String(cmd.get("action_id", "")),
					cmd.get("from", coords),
					cmd.get("to", coords),
					int(cmd.get("rng_seed", randi()))
				)
				if not ok:
					if AttackNearestEnemyBehavior.debug_enabled:
						print("[AI] action failed for %s @ %s, passing legion" % [legion.team_id, coords])
					deps.session.pass_legion_or_force_wait(coords)
			_:
				deps.session.pass_legion_or_force_wait(coords)

		await deps.host.get_tree().create_timer(AI_LEGION_DELAY).timeout
		if deps.session.phase == MinigameSessionScript.Phase.ENDED:
			break

	ai_running = false
	input_locked = false
	check_match_end()
	ai_turn_finished.emit()
	if deps.session.phase == MinigameSessionScript.Phase.BATTLE and deps.is_ai_team(deps.session.turn_manager.active_team_id):
		maybe_start_ai_turn()

func _battle_action_hooks() -> Dictionary:
	return {
		"session": deps.session,
		"clear_overlays": deps.battle_ui.clear_overlays,
		"deselect": deps.battle_ui.deselect,
		"deselect_before_combat": true,
		"deselect_after_heal": not ai_running,
		"on_ap_changed": func(legion: Legion) -> void: EventBus.legion_ap_changed.emit(legion),
		"refresh_after_action": deps.battle_ui.refresh_after_action,
		"on_finished": func() -> void: pass,
	}
