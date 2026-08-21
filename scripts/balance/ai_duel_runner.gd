class_name AiDuelRunner
extends RefCounted

## Headless full-match AI vs AI (random draft + pluggable brains).
## With mirror=true, each seed runs twice with brains swapped on the same drafts.

const AiBrainRegistry = preload("res://scripts/ai/ai_brain_registry.gd")
const AiDrafter = preload("res://scripts/ai/ai_drafter.gd")
const AiDuelReport = preload("res://scripts/balance/ai_duel_report.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")
const MatchBattleStats = preload("res://scripts/battle/match_battle_stats.gd")
const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const MinigameRulesScript = preload("res://scripts/minigame/minigame_rules.gd")

const MAX_TEAM_TURNS := 200

static func run_batch(
	pair_count: int,
	map_size: int,
	budget: int,
	verbose: bool = false,
	out_dir: String = "",
	brain_a_id: String = "cascade",
	brain_b_id: String = "cascade",
	mirror: bool = true
) -> Dictionary:
	var prev_ai_debug := AttackNearestEnemyBehavior.debug_enabled
	var prev_combat_quiet := CombatResolver.quiet
	AttackNearestEnemyBehavior.debug_enabled = false
	CombatResolver.quiet = true

	var brain_a: AiBrain = AiBrainRegistry.create(brain_a_id)
	var brain_b: AiBrain = AiBrainRegistry.create(brain_b_id)
	# Fitness / batch eval: cheap MC. In-game UtilityBrain uses play N.
	CombatExpectation.use_train_mode()

	var brain_a_wins := 0
	var brain_b_wins := 0
	var draws := 0
	var green_wins := 0
	var blue_wins := 0
	var color_draws := 0
	var total_turns := 0
	var timeouts := 0
	var match_rows: Array = []
	var legion_rows: Array = []
	var pair_rows: Array = []
	var brain_a_pair_points := 0.0

	var matches_per_pair := 2 if mirror else 1
	var total_matches := pair_count * matches_per_pair
	var game_serial := 0

	var batch_start := Time.get_ticks_msec()
	print(
		"Running %d seed(s) × %d (%s vs %s, map r%d, budget %d)..."
		% [pair_count, matches_per_pair, brain_a.id, brain_b.id, map_size, budget]
	)

	for pair_i in range(pair_count):
		var pair_a_points := 0.0
		var pair_match_winners: Array[String] = []

		for mirror_i in range(matches_per_pair):
			var a_is_green := mirror_i == 0
			var green_brain: AiBrain = brain_a if a_is_green else brain_b
			var blue_brain: AiBrain = brain_b if a_is_green else brain_a
			var t0 := Time.get_ticks_msec()
			var result: Dictionary = run_one(
				pair_i, map_size, budget, green_brain, blue_brain
			)
			result["elapsed_ms"] = Time.get_ticks_msec() - t0
			result["pair_index"] = pair_i
			result["mirror_index"] = mirror_i
			result["a_is_green"] = a_is_green
			result["brain_a"] = brain_a.id
			result["brain_b"] = brain_b.id
			result["green_brain"] = green_brain.id
			result["blue_brain"] = blue_brain.id
			total_turns += int(result.get("team_turns", 0))
			game_serial += 1

			if not result.get("match_row", {}).is_empty():
				var mr: Dictionary = result["match_row"]
				mr["elapsed_ms"] = int(result.get("elapsed_ms", 0))
				mr["game_id"] = game_serial
				mr["pair_index"] = pair_i + 1
				mr["mirror_index"] = mirror_i
				mr["a_is_green"] = a_is_green
				mr["brain_a"] = brain_a.id
				mr["brain_b"] = brain_b.id
				mr["green_brain"] = green_brain.id
				mr["blue_brain"] = blue_brain.id
				match_rows.append(mr)
			for leg_row in result.get("legion_rows", []):
				leg_row["game_id"] = game_serial
				legion_rows.append(leg_row)

			var winner_team := String(result.get("winner", ""))
			var timed_out := bool(result.get("timed_out", false))
			if timed_out:
				timeouts += 1

			var brain_winner := ""
			if timed_out or winner_team.is_empty():
				draws += 1
				color_draws += 1
				pair_a_points += 0.5
				brain_winner = "DRAW"
			elif winner_team == "GREEN":
				green_wins += 1
				if a_is_green:
					brain_a_wins += 1
					pair_a_points += 1.0
					brain_winner = brain_a.id
				else:
					brain_b_wins += 1
					brain_winner = brain_b.id
			elif winner_team == "BLUE":
				blue_wins += 1
				if a_is_green:
					brain_b_wins += 1
					brain_winner = brain_b.id
				else:
					brain_a_wins += 1
					pair_a_points += 1.0
					brain_winner = brain_a.id
			else:
				draws += 1
				color_draws += 1
				pair_a_points += 0.5
				brain_winner = "DRAW"

			pair_match_winners.append(brain_winner)

			if verbose:
				var tag := brain_winner
				if timed_out:
					tag = "TIMEOUT"
				print("  Pair %d mirror %d: %s (A %s) in %d turns [%dms]" % [
					pair_i + 1,
					mirror_i,
					tag,
					"GREEN" if a_is_green else "BLUE",
					int(result.get("team_turns", 0)),
					int(result.get("elapsed_ms", 0)),
				])

		brain_a_pair_points += pair_a_points
		pair_rows.append({
			"pair_index": pair_i + 1,
			"brain_a_points": pair_a_points,
			"match_winners": ",".join(pair_match_winners),
		})

	AttackNearestEnemyBehavior.debug_enabled = prev_ai_debug
	CombatResolver.quiet = prev_combat_quiet
	CombatExpectation.use_play_mode()

	var batch := {
		"games": total_matches,
		"pair_count": pair_count,
		"mirror": mirror,
		"map_size": map_size,
		"budget": budget,
		"brain_a": brain_a.id,
		"brain_b": brain_b.id,
		"brain_a_wins": brain_a_wins,
		"brain_b_wins": brain_b_wins,
		"draws": draws,
		"brain_a_pair_points": brain_a_pair_points,
		"brain_a_pair_score": brain_a_pair_points / float(maxi(pair_count, 1)),
		"green_wins": green_wins,
		"blue_wins": blue_wins,
		"color_draws": color_draws,
		"total_turns": total_turns,
		"timeouts": timeouts,
		"elapsed_ms": Time.get_ticks_msec() - batch_start,
		"match_rows": match_rows,
		"legion_rows": legion_rows,
		"pair_rows": pair_rows,
		"out_dir": out_dir,
	}

	var csv_paths := {}
	if not out_dir.is_empty():
		csv_paths = AiDuelReport.write_csvs(out_dir, batch)
		batch["csv_paths"] = csv_paths

	return batch

static func print_report(batch: Dictionary) -> void:
	AiDuelReport.print_extended_report(batch, batch.get("csv_paths", {}))

static func run_one(
	game_index: int,
	map_size: int,
	budget: int,
	green_brain: AiBrain = null,
	blue_brain: AiBrain = null
) -> Dictionary:
	if green_brain == null:
		green_brain = AiBrainRegistry.create("cascade")
	if blue_brain == null:
		blue_brain = AiBrainRegistry.create("cascade")

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

	var tracker := MatchBattleStats.new()
	tracker.begin(session)
	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = combat_seed

	var team_turns := 0
	var timed_out := false
	while session.phase == MinigameSessionScript.Phase.BATTLE:
		var active_team := session.turn_manager.active_team_id
		var brain: AiBrain = green_brain if active_team == "GREEN" else blue_brain
		var actionable := brain.sort_actionable(session, session.get_actionable_coords())
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

		var cmd: Dictionary = brain.decide(session, legion)
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
				tracker.record_apply(step)
				if not step.get("ok", false):
					session.pass_legion_or_force_wait(coords)
			_:
				session.pass_legion_or_force_wait(coords)

		if session.phase == MinigameSessionScript.Phase.ENDED:
			break

	var winner := session.winner if not timed_out else ""
	var survivors_green := MinigameRulesScript.count_living_units(session.legions, "GREEN")
	var survivors_blue := MinigameRulesScript.count_living_units(session.legions, "BLUE")
	var legion_rows := tracker.legion_rows_for_csv(game_index, winner)

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
			"green_brain": green_brain.id,
			"blue_brain": blue_brain.id,
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
			"green_brain": "",
			"blue_brain": "",
		},
	}

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
