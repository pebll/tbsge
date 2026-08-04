class_name BattleActionLogFormatter
extends RefCounted

## Build a structured battle-log entry from a successful session apply result.
## UI is icon/number-first; keep summaries mainly for tooltips/tests.

static func from_use_action(session: MatchSession, result: Dictionary) -> Dictionary:
	var payload: Dictionary = result.get("payload", {})
	var action_id := String(payload.get("action_id", ""))
	var from: Vector2i = payload.get("from", payload.get("coords", Vector2i.ZERO))
	var to: Vector2i = payload.get("to", from)
	var events: Array = result.get("events", [])

	var caster: Legion = payload.get("caster_legion", null)
	if caster == null:
		caster = payload.get("legion", null)
	if caster == null:
		if "legion_moved" in events or "legions_swapped" in events or "legion_teleported" in events:
			caster = session.get_legion_at(to)
		else:
			caster = session.get_legion_at(from)
	if caster == null:
		caster = session.get_legion_at(to)

	var target_unit_type := ""
	var target_legion: Legion = null
	if action_id == "heal_ally":
		target_legion = payload.get("target_legion", session.get_legion_at(to))
		if target_legion:
			target_unit_type = target_legion.unit_type
	elif "combat_resolved" in events:
		target_legion = _combat_defender_legion(payload.get("combat", {}), caster)
		if target_legion:
			target_unit_type = target_legion.unit_type
		else:
			target_unit_type = _combat_defender_unit_type(payload.get("combat", {}))

	var entry := _entry(
		session,
		action_id,
		from,
		to,
		_legion_summary(caster),
		_target_summary_for_action(session, action_id, to, payload, events),
		_result_summary_for_action(action_id, payload, events),
		payload,
		caster.unit_type if caster else "",
		target_unit_type,
		caster.team_id if caster else "",
		target_legion.team_id if target_legion else ""
	)
	_fill_numeric_fields(entry, action_id, events, payload, caster, target_legion)
	return entry

static func from_pass_legion(session: MatchSession, coords: Vector2i) -> Dictionary:
	var legion: Legion = session.get_legion_at(coords)
	var entry := _entry(
		session,
		"pass",
		coords,
		coords,
		_legion_summary(legion),
		"",
		"waited",
		{"coords": coords},
		legion.unit_type if legion else "",
		"",
		legion.team_id if legion else "",
		""
	)
	_fill_numeric_fields(entry, "pass", ["legion_passed"], {}, legion, null)
	return entry

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
		"caster_team_id": ending_team,
		"target_team_id": "",
		"caster_hp_lost": 0,
		"caster_deaths": 0,
		"target_hp_lost": 0,
		"target_deaths": 0,
		"caster_wiped": false,
		"target_wiped": false,
		"healed_total": 0,
		"show_coords": false,
		"coord_text": "",
		"payload": {
			"active_team": next_team,
			"ending_team": ending_team,
			"ending_turn": ending_turn,
		},
	}

static func _fill_numeric_fields(
	entry: Dictionary,
	action_id: String,
	events: Array,
	payload: Dictionary,
	caster: Legion,
	target_legion: Legion
) -> void:
	entry["caster_hp_lost"] = 0
	entry["caster_deaths"] = 0
	entry["target_hp_lost"] = 0
	entry["target_deaths"] = 0
	entry["caster_wiped"] = false
	entry["target_wiped"] = false
	entry["healed_total"] = int(payload.get("healed_total", 0))
	entry["show_coords"] = false
	entry["coord_text"] = ""

	if "combat_resolved" in events:
		var combat: Dictionary = payload.get("combat", {})
		var caster_stats := _side_combat_stats(combat, caster)
		var target_stats := _side_combat_stats(combat, target_legion)
		entry["caster_hp_lost"] = caster_stats["hp_lost"]
		entry["caster_deaths"] = caster_stats["deaths"]
		entry["target_hp_lost"] = target_stats["hp_lost"]
		entry["target_deaths"] = target_stats["deaths"]
		# Empty roster after resolve = legion wiped (red X on portrait).
		entry["caster_wiped"] = caster != null and caster.units.is_empty()
		entry["target_wiped"] = target_legion != null and target_legion.units.is_empty()

	if (
		action_id in ["move", "teleport"]
		or "legion_moved" in events
		or "legion_teleported" in events
		or "legions_swapped" in events
	):
		var to: Vector2i = entry.get("to", Vector2i.ZERO)
		entry["show_coords"] = true
		entry["coord_text"] = "%d,%d" % [to.x, to.y]

static func _side_combat_stats(combat: Dictionary, side: Legion) -> Dictionary:
	var out := {"hp_lost": 0, "deaths": 0}
	if side == null or combat.is_empty():
		return out
	for hit in combat.get("hits", []):
		if not (hit is Dictionary):
			continue
		if hit.get("defender_legion") == side:
			out["hp_lost"] = int(out["hp_lost"]) + int(round(float(hit.get("hp_lost", 0.0))))
	for death in combat.get("deaths", []):
		if not (death is Dictionary):
			continue
		if death.get("legion") == side:
			out["deaths"] = int(out["deaths"]) + 1
	return out

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
	target_unit_type: String = "",
	caster_team_id: String = "",
	target_team_id: String = ""
) -> Dictionary:
	var turn_index := 1
	if session != null and session.turn_manager != null:
		turn_index = session.turn_manager.turn_index
	var team := ""
	if session != null and session.turn_manager != null:
		team = session.turn_manager.active_team_id
	if payload.has("ending_team"):
		team = String(payload.get("ending_team", team))
	if caster_team_id.is_empty():
		caster_team_id = team
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
		"caster_team_id": caster_team_id,
		"target_team_id": target_team_id,
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
	if (
		action_id == "move"
		or action_id == "teleport"
		or action_id == "swap"
		or "legions_swapped" in events
		or "legion_teleported" in events
	):
		return "%d,%d" % [to.x, to.y]
	var at_to: Legion = session.get_legion_at(to)
	if at_to:
		return _legion_summary(at_to)
	return "%d,%d" % [to.x, to.y]

static func _result_summary_for_action(action_id: String, payload: Dictionary, events: Array) -> String:
	if "legions_swapped" in events:
		return "swapped"
	if "legion_moved" in events:
		return "moved"
	if "legion_healed" in events or action_id in ["self_heal", "heal_ally"]:
		return "healed %d" % int(payload.get("healed_total", 0))
	if "legion_teleported" in events or action_id == "teleport":
		return "teleported"
	if "combat_resolved" in events:
		return _combat_result_summary(payload.get("combat", {}))
	if action_id == "pass":
		return "waited"
	if action_id == "end_turn":
		return "turn ended"
	return action_id

static func _combat_defender_legion(combat: Dictionary, caster: Legion) -> Legion:
	var hits: Array = combat.get("hits", [])
	if hits.is_empty() or not (hits[0] is Dictionary):
		return null
	# Prefer the first hit's defender if it isn't the caster.
	var first_def: Variant = hits[0].get("defender_legion", null)
	if first_def is Legion and first_def != caster:
		return first_def as Legion
	for hit in hits:
		if not (hit is Dictionary):
			continue
		var def_legion: Variant = hit.get("defender_legion", null)
		if def_legion is Legion and def_legion != caster:
			return def_legion as Legion
	return first_def as Legion if first_def is Legion else null

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
