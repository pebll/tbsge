class_name AiBrainCommand
extends RefCounted

## Apply utility / brain commands including committed move→followup plans.

const AiMatchScore = preload("res://scripts/ai/evolution/ai_match_score.gd")

static func has_followup(cmd: Dictionary) -> bool:
	return not String(cmd.get("followup_action_id", "")).is_empty()

static func apply(
	session,
	cmd: Dictionary,
	coords: Vector2i,
	legion: Legion,
	combat_rng: RandomNumberGenerator,
	tracker
) -> Dictionary:
	match String(cmd.get("type", "")):
		"use_action":
			return _apply_use_action(session, cmd, coords, legion, combat_rng, tracker)
		_:
			session.pass_legion_or_force_wait(coords)
			return {"ok": false, "damage": false}

static func _apply_use_action(
	session,
	cmd: Dictionary,
	coords: Vector2i,
	legion: Legion,
	combat_rng: RandomNumberGenerator,
	tracker
) -> Dictionary:
	var action_id := String(cmd.get("action_id", ""))
	var damage := false
	var ok := false
	if action_id == "move" and cmd.has("path"):
		var path_result := _apply_move_path(session, cmd.get("path", []), tracker)
		ok = bool(path_result.get("ok", false))
		damage = bool(path_result.get("damage", false))
	else:
		var step_result := _record_step(session, _build_apply_cmd(cmd, coords, combat_rng), tracker)
		ok = bool(step_result.get("ok", false))
		damage = bool(step_result.get("damage", false))
	if not ok:
		session.pass_legion_or_force_wait(coords)
		return {"ok": false, "damage": damage}
	if not has_followup(cmd):
		return {"ok": true, "damage": damage}
	if legion == null or not session.can_act_legion(legion):
		return {"ok": true, "damage": damage}
	var follow_cmd := {
		"type": "use_action",
		"action_id": String(cmd.get("followup_action_id", "")),
		"from": legion.tile_coords,
		"to": cmd.get("followup_to", legion.tile_coords),
		"skip_action_log": true,
	}
	if follow_cmd["action_id"] in ["melee_attack", "ranged_attack"]:
		follow_cmd["rng_seed"] = combat_rng.randi()
	var follow_result := _record_step(session, follow_cmd, tracker)
	damage = damage or bool(follow_result.get("damage", false))
	if not bool(follow_result.get("ok", false)):
		session.pass_legion_or_force_wait(legion.tile_coords)
	return {"ok": true, "damage": damage}

static func _apply_move_path(session, path: Array, tracker) -> Dictionary:
	if path.size() < 2:
		return {"ok": false, "damage": false}
	var damage := false
	var any_ok := false
	for i in range(1, path.size()):
		var step_cmd := {
			"type": "use_action",
			"action_id": "move",
			"from": path[i - 1],
			"to": path[i],
			"skip_action_log": true,
		}
		var step_result := _record_step(session, step_cmd, tracker)
		if bool(step_result.get("ok", false)):
			any_ok = true
		damage = damage or bool(step_result.get("damage", false))
		if not bool(step_result.get("ok", false)):
			return {"ok": any_ok, "damage": damage}
	return {"ok": any_ok, "damage": damage}

static func _build_apply_cmd(cmd: Dictionary, coords: Vector2i, combat_rng: RandomNumberGenerator) -> Dictionary:
	var apply_cmd := {
		"type": "use_action",
		"action_id": String(cmd.get("action_id", "")),
		"from": cmd.get("from", coords),
		"to": cmd.get("to", coords),
		"skip_action_log": true,
	}
	if apply_cmd["action_id"] in ["melee_attack", "ranged_attack"]:
		apply_cmd["rng_seed"] = combat_rng.randi()
	return apply_cmd

static func _record_step(session, apply_cmd: Dictionary, tracker) -> Dictionary:
	var step: Dictionary = session.apply(apply_cmd)
	if tracker != null:
		tracker.record_apply(step)
	return {
		"ok": bool(step.get("ok", false)),
		"damage": AiMatchScore.step_dealt_damage(step),
	}

## Play mode helper: apply followup after a successful move command (async callers).
static func apply_followup_if_any(
	session,
	cmd: Dictionary,
	legion: Legion,
	rng_seed: int = 0
) -> Dictionary:
	if legion == null or not has_followup(cmd) or not session.can_act_legion(legion):
		return {"ok": true, "damage": false}
	var follow_cmd := {
		"type": "use_action",
		"action_id": String(cmd.get("followup_action_id", "")),
		"from": legion.tile_coords,
		"to": cmd.get("followup_to", legion.tile_coords),
	}
	if follow_cmd["action_id"] in ["melee_attack", "ranged_attack"]:
		follow_cmd["rng_seed"] = rng_seed
	return _record_step(session, follow_cmd, null)
