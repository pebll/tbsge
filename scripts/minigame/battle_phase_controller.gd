class_name BattlePhaseController
extends RefCounted

const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const BattleInputLockScript = preload("res://scripts/battle/battle_input_lock.gd")
const BattleHostWiringScript = preload("res://scripts/battle/battle_host_wiring.gd")

const AI_LEGION_DELAY := 0.5

signal ai_turn_finished

var deps: MinigamePhaseDeps
var ai_running: bool = false
var _lock: BattleInputLockScript = BattleInputLockScript.new()

func _init(phase_deps: MinigamePhaseDeps) -> void:
	deps = phase_deps

func enter() -> void:
	deps.tile_info_panel.set_draft_mode(false)
	deps.tile_info_panel.hide()
	deps.presenter.sync_legions(deps.session)
	deps.turn_hud.show()
	deps.turn_hud.show_active_team(deps.session.turn_manager.active_team_id)
	if deps.action_log_panel:
		deps.action_log_panel.enter_battle(deps.session.action_log)
	maybe_start_ai_turn()

func exit() -> void:
	deps.turn_hud.hide()
	if deps.action_log_panel:
		deps.action_log_panel.exit_battle()

func is_input_locked() -> bool:
	return (
		_lock.is_locked()
		or ai_running
		or (deps.pause_menu != null and deps.pause_menu.is_open())
		or (deps.pass_overlay != null and deps.pass_overlay.visible)
	)

func is_blocking_input() -> bool:
	return (
		deps.game_over_panel.visible
		or (deps.pause_menu != null and deps.pause_menu.is_open())
		or (deps.pass_overlay != null and deps.pass_overlay.visible)
	)

func handle_end_turn() -> void:
	if is_input_locked():
		return
	deps.battle_ui.deselect()
	var result: Dictionary = deps.session.apply({"type": "end_turn"})
	if result["ok"]:
		deps.turn_hud.show_active_team(deps.session.turn_manager.active_team_id)
		deps.presenter.sync_spent_visuals(deps.session)
		if _maybe_show_hotseat_pass():
			return
		maybe_start_ai_turn()

func handle_pass_continue() -> void:
	if deps.pass_overlay:
		deps.pass_overlay.hide()
	deps.turn_hud.show_active_team(deps.session.turn_manager.active_team_id)
	maybe_start_ai_turn()

func request_use_action(action_id: String, from_coords: Vector2i, to_coords: Vector2i) -> void:
	if is_input_locked():
		return
	await perform_use_action(action_id, from_coords, to_coords, randi())

func request_move_path(path: Array) -> void:
	if is_input_locked():
		return
	if path.size() < 2:
		return
	deps.battle_ui.deselect()
	deps.battle_ui.clear_overlays()
	var start: Vector2i = path[0]
	var last_ok_to: Vector2i = start
	var steps_ok := 0
	var last_was_swap := false
	for i in range(1, path.size()):
		var from_c: Vector2i = path[i - 1]
		var to_c: Vector2i = path[i]
		# Suppress per-step log; one coalesced card covers the whole path.
		var step: Dictionary = await perform_use_action("move", from_c, to_c, 0, true)
		if not step.get("ok", false):
			break
		steps_ok += 1
		last_ok_to = to_c
		last_was_swap = "legions_swapped" in step.get("events", [])
	if steps_ok > 0:
		deps.session.log_move_relocation(
			start,
			last_ok_to,
			steps_ok == 1 and last_was_swap
		)
	var end_coords: Vector2i = last_ok_to if steps_ok > 0 else path[path.size() - 1]
	# Use last successfully intended end; if mid-fail, legion may be elsewhere.
	var tile: Tile = deps.session.grid.get(end_coords)
	if tile and tile.has_legion() and deps.session.can_act_legion(tile.legion):
		deps.battle_ui.select_tile(end_coords)
	maybe_start_ai_turn()

func perform_use_action(
	action_id: String,
	from_coords: Vector2i,
	to_coords: Vector2i,
	rng_seed: int = 0,
	skip_action_log: bool = false
) -> Dictionary:
	if _lock.is_locked():
		return {"ok": false, "error": "Input locked", "events": [], "payload": {}}
	_lock.begin()
	if ai_running:
		deps.battle_ui.deselect()
		deps.battle_ui.clear_overlays()

	var cmd := {
		"type": "use_action",
		"action_id": action_id,
		"from": from_coords,
		"to": to_coords,
		"skip_action_log": skip_action_log,
	}
	if action_id == "melee_attack" or action_id == "ranged_attack":
		cmd["rng_seed"] = rng_seed

	var from_tile: Tile = deps.session.grid.get(from_coords)
	if from_tile == null or not from_tile.has_legion():
		_lock.end()
		return {"ok": false, "error": "No legion", "events": [], "payload": {}}

	var result: Dictionary = deps.session.apply(cmd)
	if not result["ok"]:
		if AttackNearestEnemyBehavior.debug_enabled:
			print(
				"[AI] action rejected: %s %s -> %s (%s)"
				% [action_id, from_coords, to_coords, result.get("error", "?")]
			)
		_lock.end()
		return result

	await deps.action_runner.play_result(
		deps.host,
		deps.session,
		deps.presenter,
		deps.action_playback,
		result,
		from_coords,
		_battle_action_hooks()
	)
	if deps.action_log_panel:
		deps.action_log_panel.reveal_pending()
	_lock.end()
	check_match_end()
	return result

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
	if deps.pass_overlay:
		deps.pass_overlay.hide()
	if deps.action_bar:
		deps.action_bar.hide()
	if deps.action_log_panel:
		deps.action_log_panel.exit_battle()
	deps.game_over_panel.show_for_winner(deps.session.winner)

func inspect_tile(coords: Vector2i) -> void:
	if not deps.tile_info_panel:
		return
	var tile: Tile = deps.session.grid.get(coords)
	if tile and tile.has_legion():
		deps.tile_info_panel.show_tile(tile)
	else:
		deps.tile_info_panel.hide()

## Hotseat: after a human ends turn, pause so the other player can take the device.
func _maybe_show_hotseat_pass() -> bool:
	if deps.session.phase != MinigameSessionScript.Phase.BATTLE:
		return false
	var cfg = deps.config()
	if cfg == null or not cfg.ai_team_ids.is_empty():
		return false
	var active: String = deps.session.turn_manager.active_team_id
	if deps.is_ai_team(active):
		return false
	deps.battle_ui.deselect()
	deps.battle_ui.clear_overlays()
	deps.status_label.text = "Pass device to %s" % GameSettings.display_name_for_team(active)
	deps.pass_overlay.show()
	return true

func _run_ai_turn_async() -> void:
	ai_running = true
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
				deps.presenter.sync_spent_visuals(deps.session)
			break

		var coords: Vector2i = actionable[0]
		var legion: Legion = deps.session.get_legion_at(coords)
		if legion == null:
			if AttackNearestEnemyBehavior.debug_enabled:
				print("[AI] stale legion slot @ %s, skipping" % coords)
			deps.session.pass_legion_or_force_wait(coords)
			deps.presenter.sync_spent_visuals(deps.session)
			await deps.host.get_tree().create_timer(AI_LEGION_DELAY).timeout
			continue

		var cmd: Dictionary = AttackNearestEnemyBehavior.decide(deps.session, legion)
		match String(cmd.get("type", "")):
			"use_action":
				var action_id := String(cmd.get("action_id", ""))
				var path: Array = cmd.get("path", [])
				var ok := false
				if action_id == "move" and path.size() >= 2:
					ok = await _ai_walk_move_path(path)
				else:
					var step: Dictionary = await perform_use_action(
						action_id,
						cmd.get("from", coords),
						cmd.get("to", coords),
						int(cmd.get("rng_seed", randi()))
					)
					ok = step.get("ok", false)
				if not ok:
					if AttackNearestEnemyBehavior.debug_enabled:
						print("[AI] action failed for %s @ %s, passing legion" % [legion.team_id, coords])
					deps.session.pass_legion_or_force_wait(legion.tile_coords)
					deps.presenter.sync_spent_visuals(deps.session)
			_:
				deps.session.pass_legion_or_force_wait(coords)
				deps.presenter.sync_spent_visuals(deps.session)

		await deps.host.get_tree().create_timer(AI_LEGION_DELAY).timeout
		if deps.session.phase == MinigameSessionScript.Phase.ENDED:
			break

	ai_running = false
	check_match_end()
	ai_turn_finished.emit()
	if deps.session.phase == MinigameSessionScript.Phase.BATTLE and deps.is_ai_team(deps.session.turn_manager.active_team_id):
		maybe_start_ai_turn()

## Walk a planned path in one AI activation (skip per-step log; one coalesced card).
func _ai_walk_move_path(path: Array) -> bool:
	if path.size() < 2:
		return false
	var start: Vector2i = path[0]
	var last_ok: Vector2i = start
	var steps_ok := 0
	for i in range(1, path.size()):
		var from_c: Vector2i = path[i - 1]
		var to_c: Vector2i = path[i]
		var step: Dictionary = await perform_use_action("move", from_c, to_c, 0, true)
		if not step.get("ok", false):
			break
		steps_ok += 1
		last_ok = to_c
	if steps_ok > 0:
		deps.session.log_move_relocation(start, last_ok, false)
		return true
	return false

func _battle_action_hooks() -> Dictionary:
	var hooks := BattleHostWiringScript.action_hooks(deps.session, deps.battle_ui, {
		"deselect_before_combat": true,
		"deselect_after_heal": true,
		"on_finished": func() -> void:
			deps.presenter.sync_spent_visuals(deps.session),
	})
	# AI turns must not re-select / paint move-attack highlights after resolving.
	if ai_running:
		hooks["refresh_after_action"] = func(_coords: Vector2i) -> void:
			deps.battle_ui.deselect()
			deps.battle_ui.clear_overlays()
			deps.presenter.sync_spent_visuals(deps.session)
		hooks["deselect_after_combat"] = true
	return hooks
