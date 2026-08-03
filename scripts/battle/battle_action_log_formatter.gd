class_name BattleActionLogFormatter
extends RefCounted

## Build a structured battle-log entry from a successful session apply result.

static func from_use_action(session: MatchSession, result: Dictionary) -> Dictionary:
	var payload: Dictionary = result.get("payload", {})
	var action_id := String(payload.get("action_id", ""))
	var from: Vector2i = payload.get("from", payload.get("coords", Vector2i.ZERO))
	var to: Vector2i = payload.get("to", from)
	var events: Array = result.get("events", [])

	var caster: Legion = payload.get("caster_legion", null)
	if caster == null:
		caster = payload.get("legion", null)
	# Move leaves legion on `to`; combat/heal_ally keep caster on `from`.
	if caster == null:
		if "legion_moved" in events or "legions_swapped" in events:
			caster = session.get_legion_at(to)
		else:
			caster = session.get_legion_at(from)
	if caster == null:
		caster = session.get_legion_at(to)

	var target_unit_type := ""
	var target_summary := _target_summary_for_action(session, action_id, to, payload, events)
	if action_id == "heal_ally":
		var target_legion: Legion = payload.get("target_legion", session.get_legion_at(to))
		if target_legion:
			target_unit_type = target_legion.unit_type
	elif "combat_resolved" in events:
		target_unit_type = _combat_defender_unit_type(payload.get("combat", {}))
	elif action_id not in ["self_heal", "move"] and "legions_swapped" not in events:
		var at_to: Legion = session.get_legion_at(to)
		if at_to and at_to != caster:
			target_unit_type = at_to.unit_type

	return _entry(
		session,
		action_id,
		from,
		to,
		_legion_summary(caster),
		target_summary,
		_result_summary_for_action(action_id, payload, events),
		payload,
		caster.unit_type if caster else "",
		target_unit_type
	)

static func from_pass_legion(session: MatchSession, coords: Vector2i) -> Dictionary:
	var legion: Legion = session.get_legion_at(coords)
	return _entry(
		session,
		"pass",
		coords,
		coords,
		_legion_summary(legion),
		"",
		"waited",
		{"coords": coords},
		legion.unit_type if legion else "",
		""
	)

static func from_end_turn(
	session: MatchSession,
	ending_team: String,
	ending_turn: int,
	next_team: String
) -> Dictionary:
	return {
		"turn": ending_turn,
		"team": ending_team,
		"action_id": "end_turn",
		"from": Vector2i.ZERO,
		"to": Vector2i.ZERO,
		"caster_summary": _team_label(ending_team),
		"target_summary": "",
		"result_summary": "ended → %s" % _team_label(next_team),
		"caster_unit_type": "",
		"target_unit_type": "",
		"payload": {
			"active_team": next_team,
			"ending_team": ending_team,
			"ending_turn": ending_turn,
		},
	}

static func _entry(
	session: MatchSession,
	action_id: String,
	from: Vector2i,
	to: Vector2i,
	caster_summary: String,
	target_summary: String,
	result_summary: String,
	payload: Dictionary,
	caster_unit_type: String = "",
	target_unit_type: String = ""
) -> Dictionary:
	var turn_index := 1
	if session != null and session.turn_manager != null:
		turn_index = session.turn_manager.turn_index
	var team := ""
	if session != null and session.turn_manager != null:
		team = session.turn_manager.active_team_id
	if payload.has("ending_team"):
		team = String(payload.get("ending_team", team))
	elif payload.has("active_team") and action_id == "end_turn":
		team = String(payload.get("ending_team", team))
	return {
		"turn": turn_index,
		"team": team,
		"action_id": action_id,
		"from": from,
		"to": to,
		"caster_summary": caster_summary,
		"target_summary": target_summary,
		"result_summary": result_summary,
		"caster_unit_type": caster_unit_type,
		"target_unit_type": target_unit_type,
		"payload": payload.duplicate(true),
	}

static func _legion_summary(legion: Legion) -> String:
	if legion == null:
		return ""
	return "%s %s" % [_team_label(legion.team_id), legion.unit_type]

static func _team_label(team_id: String) -> String:
	if team_id.is_empty():
		return "?"
	var team_res: Resource = TeamDefs.get_def(team_id)
	if team_res is TeamDefinition:
		return (team_res as TeamDefinition).display_name
	return team_id

static func _target_summary_for_action(
	session: MatchSession,
	action_id: String,
	to: Vector2i,
	payload: Dictionary,
	events: Array
) -> String:
	if action_id in ["self_heal", "pass", "end_turn"]:
		return ""
	if "combat_resolved" in events:
		var combat: Dictionary = payload.get("combat", {})
		var hits: Array = combat.get("hits", [])
		if not hits.is_empty() and hits[0] is Dictionary:
			var def_legion: Variant = hits[0].get("defender_legion", null)
			if def_legion is Legion:
				return _legion_summary(def_legion as Legion)
		return "enemy"
	if action_id == "heal_ally":
		var target_legion: Legion = payload.get("target_legion", session.get_legion_at(to))
		return _legion_summary(target_legion)
	if action_id == "move" or action_id == "swap" or "legions_swapped" in events:
		return "(%d,%d)" % [to.x, to.y]
	var at_to: Legion = session.get_legion_at(to)
	if at_to:
		return _legion_summary(at_to)
	return "(%d,%d)" % [to.x, to.y]

static func _result_summary_for_action(action_id: String, payload: Dictionary, events: Array) -> String:
	if "legions_swapped" in events:
		return "swapped"
	if "legion_moved" in events:
		return "moved"
	if "legion_healed" in events or action_id in ["self_heal", "heal_ally"]:
		return "healed %d" % int(payload.get("healed_total", 0))
	if "combat_resolved" in events:
		return _combat_result_summary(payload.get("combat", {}))
	if action_id == "pass":
		return "waited"
	if action_id == "end_turn":
		return "turn ended"
	return action_id

static func _combat_defender_unit_type(combat: Dictionary) -> String:
	var hits: Array = combat.get("hits", [])
	if hits.is_empty() or not (hits[0] is Dictionary):
		return ""
	var def_legion: Variant = hits[0].get("defender_legion", null)
	if def_legion is Legion:
		return (def_legion as Legion).unit_type
	return ""

static func _combat_result_summary(combat: Dictionary) -> String:
	if combat.is_empty():
		return "fought"
	var total_damage := 0
	for hit in combat.get("hits", []):
		if hit is Dictionary:
			total_damage += int(hit.get("damage", hit.get("amount", 0)))
	var deaths: Array = combat.get("deaths", [])
	if total_damage > 0 and not deaths.is_empty():
		return "hit for %d (%d fallen)" % [total_damage, deaths.size()]
	if total_damage > 0:
		return "hit for %d" % total_damage
	if not deaths.is_empty():
		return "%d fallen" % deaths.size()
	return "fought"
