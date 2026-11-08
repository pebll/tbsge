extends RefCounted

## Status effects on legions: apply / query / remove, plus the hooks the rules call.
##
## Effects live on the legion (`Legion.statuses`), so every copy of the board (combat
## Monte Carlo, the AI's turn planner, UI previews) carries them. Damage hooks run inside
## CombatResolver, so the preview and the AI see an effect the moment its behaviour exists.
##
## Event dictionaries (returned by hooks, collected into results and the battle log):
##   {"kind": "applied"|"expired"|"damage"|"heal", "status_id", "legion", "team_id",
##    "unit", "unit_type", "amount", "hp_before", "hp_after", "died", "stacks", "turns_left"}

const StatusDefs = preload("res://scripts/effects/status_defs.gd")

# --- Instances -------------------------------------------------------------------------

static func get_effect(legion: Legion, id: String) -> Dictionary:
	if legion == null:
		return {}
	for e in legion.statuses:
		if String(e["id"]) == id:
			return e
	return {}

static func has_effect(legion: Legion, id: String) -> bool:
	return not get_effect(legion, id).is_empty()

static func stacks_of(legion: Legion, id: String) -> int:
	var e := get_effect(legion, id)
	return int(e.get("stacks", 0))

## Apply (or re-apply, following the type's stacking rule). turns < 0 uses the type's
## default; -1 there means "until removed". Returns an "applied" event.
static func apply(
	legion: Legion, id: String, stacks: int = 1, turns: int = -2, source_team: String = ""
) -> Dictionary:
	if legion == null or stacks <= 0:
		return {}
	var def = StatusDefs.get_def(id)
	var max_stacks := int(def.max_stacks) if def != null else 99
	var t := turns
	if t == -2:
		t = int(def.default_turns) if def != null else 1
	var e := get_effect(legion, id)
	if e.is_empty():
		e = {"id": id, "stacks": mini(stacks, max_stacks), "turns_left": t, "source_team": source_team}
		legion.statuses.append(e)
	else:
		var stacking := String(def.stacking) if def != null else "refresh"
		if stacking == "add":
			e["stacks"] = mini(int(e["stacks"]) + stacks, max_stacks)
		else:
			e["stacks"] = maxi(int(e["stacks"]), mini(stacks, max_stacks))
		e["turns_left"] = -1 if (t < 0 or int(e["turns_left"]) < 0) else maxi(int(e["turns_left"]), t)
		e["source_team"] = source_team
	return _event("applied", id, legion, null, 0.0, {"stacks": e["stacks"], "turns_left": e["turns_left"]})

static func remove(legion: Legion, id: String) -> bool:
	if legion == null:
		return false
	for i in range(legion.statuses.size()):
		if String(legion.statuses[i]["id"]) == id:
			legion.statuses.remove_at(i)
			return true
	return false

static func copy_statuses(from: Legion, to: Legion) -> void:
	to.statuses.clear()
	for e in from.statuses:
		to.statuses.append(e.duplicate(true))

# --- Combat hooks (CombatResolver) -----------------------------------------------------

static func strike_damage(
	attacker: Legion, unit: Unit, defender: Legion, target_unit: Unit, mode: String, base: float
) -> float:
	var dmg := base
	if attacker != null:
		for e in attacker.statuses.duplicate():
			dmg = float(StatusDefs.behavior(e["id"]).outgoing_damage(attacker, e, unit, defender, target_unit, mode, dmg))
	if defender != null:
		for e in defender.statuses.duplicate():
			dmg = float(StatusDefs.behavior(e["id"]).incoming_damage(defender, e, target_unit, attacker, unit, mode, dmg))
	return maxf(0.0, dmg)

static func after_hit(hit: Dictionary) -> Array:
	var out: Array = []
	var attacker: Legion = hit.get("attacker_legion")
	var defender: Legion = hit.get("defender_legion")
	if attacker != null:
		for e in attacker.statuses.duplicate():
			out.append_array(StatusDefs.behavior(e["id"]).on_hit_dealt(attacker, e, hit))
	if defender != null:
		for e in defender.statuses.duplicate():
			out.append_array(StatusDefs.behavior(e["id"]).on_hit_taken(defender, e, hit))
	return out

static func after_death(legion: Legion, unit: Unit) -> Array:
	var out: Array = []
	if legion != null:
		for e in legion.statuses.duplicate():
			out.append_array(StatusDefs.behavior(e["id"]).on_unit_death(legion, e, unit))
	return out

static func any_statuses(a: Legion, b: Legion) -> bool:
	return (a != null and not a.statuses.is_empty()) or (b != null and not b.statuses.is_empty())

# --- Turn hooks (MatchSession.apply_end_turn) ------------------------------------------

## Start of `team`'s turn: tick every effect on its legions.
static func turn_start(legions: Array, team: String) -> Array:
	var out: Array = []
	for L in legions.duplicate():
		if L == null or L.team_id != team or L.units.is_empty():
			continue
		for e in L.statuses.duplicate():
			out.append_array(StatusDefs.behavior(e["id"]).on_turn_start(L, e))
	return out

## End of `team`'s turn: on_turn_end, then durations count down; expired effects go.
static func turn_end(legions: Array, team: String) -> Array:
	var out: Array = []
	for L in legions.duplicate():
		if L == null or L.team_id != team or L.units.is_empty():
			continue
		for e in L.statuses.duplicate():
			out.append_array(StatusDefs.behavior(e["id"]).on_turn_end(L, e))
			if int(e["turns_left"]) < 0:
				continue
			e["turns_left"] = int(e["turns_left"]) - 1
			if int(e["turns_left"]) <= 0:
				L.statuses.erase(e)
				out.append(_event("expired", String(e["id"]), L, null, 0.0, {}))
	return out

# --- Helpers for behaviours ------------------------------------------------------------

## Status damage goes straight to HP (no shield). A unit at 0 HP dies and leaves the legion.
static func damage_unit(legion: Legion, unit: Unit, amount: float, status_id: String) -> Dictionary:
	if legion == null or unit == null or amount <= 0.0:
		return {}
	var before := float(unit.current_health)
	unit.current_health = before - amount
	var died := unit.current_health <= 0.0
	if died:
		legion.units.erase(unit)
	return _event("damage", status_id, legion, unit, minf(amount, before), {
		"hp_before": before, "hp_after": maxf(0.0, float(unit.current_health)), "died": died,
	})

static func heal_unit(legion: Legion, unit: Unit, amount: float, status_id: String) -> Dictionary:
	if legion == null or unit == null or amount <= 0.0:
		return {}
	var before := float(unit.current_health)
	unit.current_health = minf(before + amount, float(unit.max_health))
	var gained := float(unit.current_health) - before
	if gained <= 0.0:
		return {}
	return _event("heal", status_id, legion, unit, gained, {
		"hp_before": before, "hp_after": float(unit.current_health), "died": false,
	})

static func _event(
	kind: String, status_id: String, legion: Legion, unit: Unit, amount: float, extra: Dictionary
) -> Dictionary:
	var ev := {
		"kind": kind,
		"status_id": status_id,
		"legion": legion,
		"team_id": legion.team_id if legion else "",
		"unit": unit,
		"unit_type": unit.unit_type if unit else (legion.unit_type if legion else ""),
		"amount": amount,
		"died": false,
	}
	ev.merge(extra, true)
	return ev

## Player-facing name of a status (falls back to the id).
static func label(id: String) -> String:
	var def = StatusDefs.get_def(id)
	if def != null and not String(def.display_name).is_empty():
		return def.display_name
	return id.capitalize()
