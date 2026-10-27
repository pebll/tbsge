extends RefCounted

const AiDuelReport = preload("res://scripts/balance/ai_duel_report.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_aggregate_relative():
		return false
	if not _test_wilson_interval():
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

func _test_wilson_interval() -> bool:
	var ci: Vector2 = AiDuelReport.wilson_interval(60.0, 100)
	# Reference values for p=0.6, n=100, z=1.96: [0.502, 0.691].
	if absf(ci.x - 0.502) > 0.002 or absf(ci.y - 0.691) > 0.002:
		push_error("Wilson CI for 60/100 expected ~[0.502, 0.691], got %s" % ci)
		return false
	var empty: Vector2 = AiDuelReport.wilson_interval(0.0, 0)
	if empty != Vector2(0.0, 1.0):
		push_error("Wilson CI with n=0 should be [0, 1], got %s" % empty)
		return false
	var all_wins: Vector2 = AiDuelReport.wilson_interval(20.0, 20)
	if all_wins.y < 0.999 or all_wins.x < 0.8 or all_wins.x > 0.9:
		push_error("Wilson CI for 20/20 expected lower ~0.84, got %s" % all_wins)
		return false
	return true
