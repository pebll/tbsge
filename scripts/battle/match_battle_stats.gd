class_name MatchBattleStats
extends RefCounted

## Tracks per-legion combat totals for the end-of-battle report (and AI duel CSV).

const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

var tracks: Array = []
var by_legion: Dictionary = {}

func begin(session) -> void:
	tracks.clear()
	by_legion.clear()
	if session == null:
		return
	var seq := 0
	for legion in session.legions:
		seq += 1
		var track := {
			"legion": legion,
			"legion_id": "%s_%d" % [legion.team_id, seq],
			"team": String(legion.team_id),
			"unit_type": String(legion.unit_type),
			"start_coords": legion.tile_coords,
			"start_units": legion.units.size(),
			"damage_dealt": 0.0,
			"damage_received": 0.0,
		}
		tracks.append(track)
		by_legion[legion] = track

func record_apply(result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	var events: Array = result.get("events", [])
	if not ("combat_resolved" in events):
		return
	var combat: Dictionary = result.get("payload", {}).get("combat", {})
	for hit in combat.get("hits", []):
		if not (hit is Dictionary):
			continue
		var hp_lost := float(hit.get("hp_lost", 0.0))
		if hp_lost <= 0.0:
			continue
		var attacker: Legion = hit.get("attacker_legion", null)
		var defender: Legion = hit.get("defender_legion", null)
		if attacker != null and by_legion.has(attacker):
			by_legion[attacker]["damage_dealt"] = float(by_legion[attacker]["damage_dealt"]) + hp_lost
		if defender != null and by_legion.has(defender):
			by_legion[defender]["damage_received"] = float(by_legion[defender]["damage_received"]) + hp_lost

func legion_rows_for_csv(game_index: int, winner: String) -> Array:
	var out: Array = []
	for track in tracks:
		var end_units := _end_units(track)
		var team := String(track.get("team", ""))
		out.append({
			"game_id": game_index + 1,
			"legion_id": track.get("legion_id", ""),
			"team": team,
			"unit_type": track.get("unit_type", ""),
			"start_coords": track.get("start_coords", Vector2i.ZERO),
			"start_units": int(track.get("start_units", 0)),
			"end_units": end_units,
			"damage_dealt": float(track.get("damage_dealt", 0.0)),
			"damage_received": float(track.get("damage_received", 0.0)),
			"team_won": not winner.is_empty() and team == winner,
		})
	return out

## Compact post-battle summary for the game-over UI.
func build_report(winner: String = "") -> Dictionary:
	if tracks.is_empty():
		return {}

	var by_type: Dictionary = {}
	var wiped_green := 0
	var wiped_blue := 0
	var mvp: Dictionary = {}

	for track in tracks:
		var unit_type := String(track.get("unit_type", ""))
		var team := String(track.get("team", ""))
		var start_u := int(track.get("start_units", 0))
		var end_u := _end_units(track)
		var lost := maxi(0, start_u - end_u)
		if end_u <= 0 and start_u > 0:
			if team == "GREEN":
				wiped_green += 1
			elif team == "BLUE":
				wiped_blue += 1

		if not by_type.has(unit_type):
			by_type[unit_type] = {
				"unit_type": unit_type,
				"display_name": _display_name(unit_type),
				"price": MinigameRulesScript.unit_price(unit_type),
				"green_start": 0,
				"green_end": 0,
				"green_lost": 0,
				"blue_start": 0,
				"blue_end": 0,
				"blue_lost": 0,
			}
		var row: Dictionary = by_type[unit_type]
		if team == "GREEN":
			row["green_start"] = int(row["green_start"]) + start_u
			row["green_end"] = int(row["green_end"]) + end_u
			row["green_lost"] = int(row["green_lost"]) + lost
		elif team == "BLUE":
			row["blue_start"] = int(row["blue_start"]) + start_u
			row["blue_end"] = int(row["blue_end"]) + end_u
			row["blue_lost"] = int(row["blue_lost"]) + lost

		var dealt := float(track.get("damage_dealt", 0.0))
		var taken := float(track.get("damage_received", 0.0))
		if mvp.is_empty() or _mvp_better(dealt, taken, mvp):
			mvp = {
				"unit_type": unit_type,
				"display_name": _display_name(unit_type),
				"team": team,
				"damage_dealt": dealt,
				"damage_received": taken,
				"start_units": start_u,
				"end_units": end_u,
			}

	var type_rows: Array = by_type.values()
	type_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("price", 0))
		var pb := int(b.get("price", 0))
		if pa != pb:
			return pa < pb
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)

	var green_gold := 0
	var blue_gold := 0
	for row in type_rows:
		var price := int(row.get("price", 0))
		green_gold += int(row.get("green_lost", 0)) * price
		blue_gold += int(row.get("blue_lost", 0)) * price

	return {
		"by_type": type_rows,
		"green_gold_lost": green_gold,
		"blue_gold_lost": blue_gold,
		"wiped_green": wiped_green,
		"wiped_blue": wiped_blue,
		"mvp": mvp,
		"winner": winner,
	}

func _end_units(track: Dictionary) -> int:
	var legion: Legion = track.get("legion", null)
	if legion != null and legion.units.size() > 0:
		return legion.units.size()
	return 0

func _display_name(unit_type: String) -> String:
	var def: UnitDefinition = UnitDefs.get_def(unit_type)
	if def != null and not def.display_name.is_empty():
		return def.display_name
	return unit_type.capitalize()

static func _mvp_better(dealt: float, taken: float, current: Dictionary) -> bool:
	var cur_dealt := float(current.get("damage_dealt", 0.0))
	if dealt > cur_dealt:
		return true
	if dealt < cur_dealt:
		return false
	var cur_taken := float(current.get("damage_received", 0.0))
	return (dealt - taken) > (cur_dealt - cur_taken)
