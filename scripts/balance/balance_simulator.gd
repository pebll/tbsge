class_name BalanceSimulator
extends RefCounted

const BalanceArmyPlanner = preload("res://scripts/balance/balance_army_planner.gd")
const BalanceBattleRunner = preload("res://scripts/balance/balance_battle_runner.gd")
const BalanceReport = preload("res://scripts/balance/balance_report.gd")
const MapBuilderScript = preload("res://scripts/minigame/map_builder.gd")
const MinigameConfigScript = preload("res://scripts/minigame/minigame_config.gd")
const MinigameSessionScript = preload("res://scripts/minigame/minigame_session.gd")
const UnitDatabaseScript = preload("res://scripts/resources/unit_database.gd")

const DEFAULT_SEEDS := 5
const UNIT_DB_PATH := "res://data/unit_db.tres"

static func run(seeds_per_matchup: int = DEFAULT_SEEDS) -> Dictionary:
	var unit_ids := _affordable_unit_ids()
	var legion_counts := _legion_counts_for_units(unit_ids)
	var matchups: Array = []
	var matrix: Dictionary = {}

	for unit_a in unit_ids:
		for unit_b in unit_ids:
			if unit_a == unit_b:
				continue
			var key := _matchup_key(unit_a, unit_b)
			var wins_a := 0
			var wins_b := 0
			var draws := 0
			var total_turns := 0
			var timed_out := 0

			print("Simulating %s vs %s..." % [unit_a, unit_b])
			for trial in range(seeds_per_matchup):
				var map_seed := _trial_seed(unit_a, unit_b, trial)
				var combat_seed := _trial_seed(unit_b, unit_a, trial)
				var unit_a_moves_first := trial % 2 == 0
				var result: Dictionary = BalanceBattleRunner.run(
					unit_a, unit_b, map_seed, combat_seed, unit_a_moves_first
				)
				if not result.get("ok", false):
					push_error("Balance sim failed %s vs %s: %s" % [unit_a, unit_b, result.get("error", "?")])
					continue

				total_turns += int(result.get("team_turns", 0))
				if result.get("timed_out", false):
					timed_out += 1
					draws += 1
					continue

				var winner_unit_type: String = String(result.get("winner_unit_type", ""))
				if winner_unit_type == unit_a:
					wins_a += 1
				elif winner_unit_type == unit_b:
					wins_b += 1
				else:
					draws += 1

			var trials_run := wins_a + wins_b + draws
			var summary := {
				"unit_a": unit_a,
				"unit_b": unit_b,
				"count_a": BalanceBattleRunner.army_count_for_budget(unit_a),
				"count_b": BalanceBattleRunner.army_count_for_budget(unit_b),
				"legions_a": int(legion_counts.get(unit_a, 0)),
				"legions_b": int(legion_counts.get(unit_b, 0)),
				"trials": trials_run,
				"wins_a": wins_a,
				"wins_b": wins_b,
				"draws": draws,
				"win_rate_a": float(wins_a) / float(maxi(trials_run, 1)),
				"avg_turns": float(total_turns) / float(maxi(trials_run, 1)),
				"timed_out": timed_out,
			}
			matchups.append(summary)
			matrix[key] = summary

	return {
		"seeds_per_matchup": seeds_per_matchup,
		"unit_ids": unit_ids,
		"legion_counts": legion_counts,
		"matchups": matchups,
		"matrix": matrix,
	}

static func print_report(result: Dictionary) -> void:
	print(BalanceReport.format(result))

static func _legion_counts_for_units(unit_ids: Array[String]) -> Dictionary:
	var config: MinigameConfigScript = load(BalanceBattleRunner.CONFIG_PATH) as MinigameConfigScript
	if config == null:
		return {}
	var session := MinigameSessionScript.new(config)
	session.grid = MapBuilderScript.build_grid(config.map_radius, 42, config.team_ids)
	session.refresh_deploy_slots()
	var slots: Array = session.get_deploy_slots(config.first_team_id())

	var out: Dictionary = {}
	for unit_id in unit_ids:
		out[unit_id] = BalanceArmyPlanner.plan_placements(
			unit_id, slots, BalanceBattleRunner.BALANCE_BUDGET, config.max_legion_fill
		).size()
	return out

static func _affordable_unit_ids() -> Array[String]:
	var db: UnitDatabaseScript = load(UNIT_DB_PATH) as UnitDatabaseScript
	if db == null:
		return []
	var out: Array[String] = []
	for unit_id in db.get_all_ids():
		if BalanceBattleRunner.army_count_for_budget(unit_id) > 0:
			out.append(unit_id)
	out.sort()
	return out

static func _matchup_key(unit_a: String, unit_b: String) -> String:
	return "%s|%s" % [unit_a, unit_b]

static func _trial_seed(unit_a: String, unit_b: String, trial: int) -> int:
	var hash_base := unit_a.hash() ^ unit_b.hash() ^ (trial * 7919)
	return int(hash_base & 0x7FFFFFFF)
