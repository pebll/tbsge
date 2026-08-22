extends RefCounted

const AiDuelReport = preload("res://scripts/balance/ai_duel_report.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_aggregate_relative():
		return false
	print("Success: AI duel report aggregation")
	return true

func _test_aggregate_relative() -> bool:
	var legion_rows: Array = [
		{
			"unit_type": "GOBLIN",
			"team_won": true,
			"damage_dealt": 10.0,
			"damage_received": 4.0,
			"start_units": 4,
			"end_units": 2,
		},
		{
			"unit_type": "GOBLIN",
			"team_won": false,
			"damage_dealt": 6.0,
			"damage_received": 12.0,
			"start_units": 4,
			"end_units": 0,
		},
		{
			"unit_type": "MAGE",
			"team_won": true,
			"damage_dealt": 20.0,
			"damage_received": 2.0,
			"start_units": 2,
			"end_units": 2,
		},
	]
	var stats: Array = AiDuelReport.aggregate_unit_stats(legion_rows)
	if stats.size() != 2:
		push_error("Expected 2 unit types in aggregate")
		return false
	var goblin: Dictionary = {}
	for row in stats:
		if String(row["unit_type"]) == "GOBLIN":
			goblin = row
	if goblin.is_empty():
		push_error("Missing GOBLIN aggregate")
		return false
	if int(goblin["appearances"]) != 2:
		push_error("Expected 2 GOBLIN appearances")
		return false
	if not is_equal_approx(float(goblin["team_win_rate"]), 0.5):
		push_error("Expected 50%% GOBLIN team win rate")
		return false
	if not is_equal_approx(float(goblin["avg_damage_dealt"]), 8.0):
		push_error("Expected avg 8 damage dealt for GOBLIN")
		return false
	return true
