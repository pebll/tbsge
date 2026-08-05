class_name AiDuelRunner
extends RefCounted

## Headless full-match AI vs AI (random draft + attack-nearest battle).

const AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
const AiDuelReport = preload("res://scripts/balance/ai_duel_report.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")
const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

const MAX_TEAM_TURNS := 200

static func run_batch(
	games: int,
	map_size: int,
	budget: int,
	verbose: bool = false,
	out_dir: String = ""
) -> Dictionary:
	var prev_ai_debug := AttackNearestEnemyBehavior.debug_enabled
	var prev_combat_quiet := CombatResolver.quiet
	AttackNearestEnemyBehavior.debug_enabled = false
	CombatResolver.quiet = true

	var green_wins := 0
	var blue_wins := 0
	var draws := 0
	var total_turns := 0
	var timeouts := 0
	var match_rows: Array = []
	var legion_rows: Array = []

	var batch_start := Time.get_ticks_msec()
	print("Running %d AI vs AI games (map r%d, budget %d)..." % [games, map_size, budget])

	for i in range(games):
		var t0 := Time.get_ticks_msec()
		var result: Dictionary = run_one(i, map_size, budget)
		result["elapsed_ms"] = Time.get_ticks_msec() - t0
		total_turns += int(result.get("team_turns", 0))

		if not result.get("match_row", {}).is_empty():
			var mr: Dictionary = result["match_row"]
			mr["elapsed_ms"] = int(result.get("elapsed_ms", 0))
			match_rows.append(mr)
		for leg_row in result.get("legion_rows", []):
			legion_rows.append(leg_row)

		if result.get("timed_out", false):
			timeouts += 1
			draws += 1
		elif String(result.get("winner", "")) == "GREEN":
			green_wins += 1
		elif String(result.get("winner", "")) == "BLUE":
			blue_wins += 1
		else:
			draws += 1
		if verbose:
			var tag := String(result.get("winner", ""))
			if tag.is_empty():
				tag = "DRAW"
			if result.get("timed_out", false):
				tag = "TIMEOUT"
			print("  Game %d: %s in %d turns (G:%d B:%d) [%dms]" % [
				i + 1, tag, int(result.get("team_turns", 0)),
				int(result.get("survivors_green", 0)), int(result.get("survivors_blue", 0)),
				int(result.get("elapsed_ms", 0)),
			])

	AttackNearestEnemyBehavior.debug_enabled = prev_ai_debug
	CombatResolver.quiet = prev_combat_quiet

	var batch := {
		"games": games,
		"map_size": map_size,
		"budget": budget,
		"green_wins": green_wins,
		"blue_wins": blue_wins,
		"draws": draws,
		"total_turns": total_turns,
		"timeouts": timeouts,
		"elapsed_ms": Time.get_ticks_msec() - batch_start,
		"match_rows": match_rows,
		"legion_rows": legion_rows,
		"out_dir": out_dir,
	}

	var csv_paths := {}
	if not out_dir.is_empty():
		csv_paths = AiDuelReport.write_csvs(out_dir, batch)
		batch["csv_paths"] = csv_paths

	return batch

static func print_report(batch: Dictionary) -> void:
	AiDuelReport.print_extended_report(batch, batch.get("csv_paths", {}))

static func run_one(game_index: int, map_size: int, budget: int) -> Dictionary:
	var empty := _empty_result(game_index, map_size, budget)
	var config: MinigameConfigScript = MinigameConfigScript.new()
	config.map_radius = map_size
	config.budget = budget
	config.deploy_slot_count = 7
	config.team_ids = ["GREEN", "BLUE"] as Array[String]
	config.ai_team_ids = ["GREEN", "BLUE"] as Array[String]
	config.ai_budget_mult = 1.0
	config.max_legion_fill = 12.0

	var map_seed := game_index * 7919 + 42
	var combat_seed := map_seed ^ 0xDEAD
	var session: MinigameSessionScript = MinigameSessionScript.new(config)
	session.grid = MapBuilderScript.build_grid(config.map_radius, map_seed, config.team_ids)
	session.refresh_deploy_slots()

	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed

	for team_id in config.team_ids:
		for cmd in AiDrafter.build_draft_commands(session, team_id, rng):
			var r: Dictionary = session.apply(cmd)
			if not r.get("ok", false):
				return empty

	if session.phase != MinigameSessionScript.Phase.BATTLE:
		return empty

	var tracker := _begin_legion_tracker(session)
	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = combat_seed

	var team_turns := 0
	var timed_out := false
	while session.phase == MinigameSessionScript.Phase.BATTLE:
		var actionable := AttackNearestEnemyBehavior.sort_actionable_by_enemy_distance(
			session, session.get_actionable_coords()
		)
		if actionable.is_empty():
			var end_result: Dictionary = session.apply({"type": "end_turn"})
			if not end_result.get("ok", false):
				break
			team_turns += 1
			if team_turns > MAX_TEAM_TURNS:
				timed_out = true
				break
			continue

		var coords: Vector2i = actionable[0]
		var legion = session.get_legion_at(coords)
		if legion == null:
			session.pass_legion_or_force_wait(coords)
			continue

		var cmd: Dictionary = AttackNearestEnemyBehavior.decide(session, legion)
		match String(cmd.get("type", "")):
			"use_action":
				var apply_cmd := {
					"type": "use_action",
					"action_id": String(cmd.get("action_id", "")),
					"from": cmd.get("from", coords),
					"to": cmd.get("to", coords),
					"skip_action_log": true,
				}
				if apply_cmd["action_id"] in ["melee_attack", "ranged_attack"]:
					apply_cmd["rng_seed"] = combat_rng.randi()
				var step: Dictionary = session.apply(apply_cmd)
				_record_combat_from_result(tracker, step)
				if not step.get("ok", false):
					session.pass_legion_or_force_wait(coords)
			_:
				session.pass_legion_or_force_wait(coords)

		if session.phase == MinigameSessionScript.Phase.ENDED:
			break

	var winner := session.winner if not timed_out else ""
	var survivors_green := MinigameRulesScript.count_living_units(session.legions, "GREEN")
	var survivors_blue := MinigameRulesScript.count_living_units(session.legions, "BLUE")
	var legion_rows := _finalize_legion_rows(tracker, game_index, winner)

	return {
		"winner": winner,
		"team_turns": team_turns,
		"timed_out": timed_out,
		"survivors_green": survivors_green,
		"survivors_blue": survivors_blue,
		"legion_rows": legion_rows,
		"match_row": {
			"game_id": game_index + 1,
			"map_size": map_size,
			"budget": budget,
			"map_seed": map_seed,
			"combat_seed": combat_seed,
			"team_turns": team_turns,
			"elapsed_ms": 0,
			"winner": winner,
			"timed_out": timed_out,
			"survivors_green": survivors_green,
			"survivors_blue": survivors_blue,
			"green_legions": _legion_count_for_team(session, "GREEN"),
			"blue_legions": _legion_count_for_team(session, "BLUE"),
			"green_draft": _draft_summary(session, "GREEN"),
			"blue_draft": _draft_summary(session, "BLUE"),
		},
	}

static func _empty_result(game_index: int, map_size: int, budget: int) -> Dictionary:
	return {
		"winner": "",
		"team_turns": 0,
		"timed_out": false,
		"survivors_green": 0,
		"survivors_blue": 0,
		"legion_rows": [],
		"match_row": {
			"game_id": game_index + 1,
			"map_size": map_size,
			"budget": budget,
			"map_seed": game_index * 7919 + 42,
			"combat_seed": 0,
			"team_turns": 0,
			"elapsed_ms": 0,
			"winner": "",
			"timed_out": false,
			"survivors_green": 0,
			"survivors_blue": 0,
			"green_legions": 0,
			"blue_legions": 0,
			"green_draft": "",
			"blue_draft": "",
		},
	}

static func _begin_legion_tracker(session: MinigameSessionScript) -> Dictionary:
	var tracks: Array = []
	var by_legion: Dictionary = {}
	var seq := 0
	for legion in session.legions:
		seq += 1
		var track := {
			"legion": legion,
			"legion_id": "%s_%d" % [legion.team_id, seq],
			"team": legion.team_id,
			"unit_type": legion.unit_type,
			"start_coords": legion.tile_coords,
			"start_units": legion.units.size(),
			"damage_dealt": 0.0,
			"damage_received": 0.0,
		}
		tracks.append(track)
		by_legion[legion] = track
	return {"tracks": tracks, "by_legion": by_legion}

static func _record_combat_from_result(tracker: Dictionary, result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	var events: Array = result.get("events", [])
	if not ("combat_resolved" in events):
		return
	var combat: Dictionary = result.get("payload", {}).get("combat", {})
	var by_legion: Dictionary = tracker.get("by_legion", {})
	for hit in combat.get("hits", []):
		if not (hit is Dictionary):
			continue
		var hp_lost := float(hit.get("hp_lost", 0.0))
		var attacker: Legion = hit.get("attacker_legion", null)
		var defender: Legion = hit.get("defender_legion", null)
		if attacker != null and by_legion.has(attacker):
			by_legion[attacker]["damage_dealt"] = float(by_legion[attacker]["damage_dealt"]) + hp_lost
		if defender != null and by_legion.has(defender):
			by_legion[defender]["damage_received"] = float(by_legion[defender]["damage_received"]) + hp_lost

static func _finalize_legion_rows(tracker: Dictionary, game_index: int, winner: String) -> Array:
	var out: Array = []
	for track in tracker.get("tracks", []):
		var legion: Legion = track.get("legion", null)
		var end_units := 0
		if legion != null and legion.units.size() > 0:
			end_units = legion.units.size()
		var team: String = String(track.get("team", ""))
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

static func _draft_summary(session: MinigameSessionScript, team_id: String) -> String:
	var draft = session.drafts.get(team_id)
	if draft == null:
		return ""
	var counts: Dictionary = {}
	for placement in draft.placements:
		var ut := String(placement.unit_type)
		counts[ut] = int(counts.get(ut, 0)) + int(placement.unit_count)
	var keys: Array = counts.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for ut in keys:
		parts.append("%s:%d" % [ut, int(counts[ut])])
	return ";".join(parts)

static func _legion_count_for_team(session: MinigameSessionScript, team_id: String) -> int:
	var draft = session.drafts.get(team_id)
	if draft == null:
		return 0
	return draft.placements.size()
