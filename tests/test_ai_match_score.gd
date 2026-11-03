extends RefCounted

const AiMatchScore = preload("res://scripts/ai/evolution/ai_match_score.gd")

func run(_tree: SceneTree) -> bool:
	if not _test_win_prefers_fast_and_rich():
		return false
	if not _test_draw_better_than_loss_and_gold_diff():
		return false
	if not _test_loss_is_zero():
		return false
	print("Success: AI match score tests")
	return true

func _base_result() -> Dictionary:
	return {
		"winner": "GREEN",
		"timed_out": false,
		"stale_draw": false,
		"team_turns": 10,
		"gold_start_green": 100.0,
		"gold_start_blue": 100.0,
		"gold_end_green": 80.0,
		"gold_end_blue": 0.0,
	}

func _test_win_prefers_fast_and_rich() -> bool:
	var fast_rich := _base_result()
	fast_rich["team_turns"] = 5
	fast_rich["gold_end_green"] = 90.0
	var slow_poor := _base_result()
	slow_poor["team_turns"] = 80
	slow_poor["gold_end_green"] = 10.0
	var s_fast := AiMatchScore.score_for_side(fast_rich, true)
	var s_slow := AiMatchScore.score_for_side(slow_poor, true)
	if s_fast <= s_slow:
		push_error("Fast rich win (%.3f) should beat slow poor (%.3f)" % [s_fast, s_slow])
		return false
	if s_fast <= AiMatchScore.WIN_BASE:
		push_error("Winning score should exceed WIN_BASE")
		return false
	return true

func _test_draw_better_than_loss_and_gold_diff() -> bool:
	var behind := {
		"winner": "",
		"stale_draw": true,
		"timed_out": false,
		"team_turns": 12,
		"gold_start_green": 100.0,
		"gold_start_blue": 100.0,
		"gold_end_green": 20.0,
		"gold_end_blue": 80.0,
	}
	var ahead := behind.duplicate(true)
	ahead["gold_end_green"] = 80.0
	ahead["gold_end_blue"] = 20.0
	var s_behind := AiMatchScore.score_for_side(behind, true)
	var s_ahead := AiMatchScore.score_for_side(ahead, true)
	if s_behind <= AiMatchScore.LOSS_SCORE or s_ahead <= AiMatchScore.LOSS_SCORE:
		push_error("Draw should beat loss (got behind=%.3f ahead=%.3f)" % [s_behind, s_ahead])
		return false
	if s_ahead <= s_behind:
		push_error(
			"Gold advantage on draw should score higher (%.3f vs %.3f)" % [s_ahead, s_behind]
		)
		return false
	var expected_even := AiMatchScore.DRAW_BASE
	var even := behind.duplicate(true)
	even["gold_end_green"] = 50.0
	even["gold_end_blue"] = 50.0
	var s_even := AiMatchScore.score_for_side(even, true)
	if not is_equal_approx(s_even, expected_even):
		push_error("Even draw should be DRAW_BASE (%.3f got %.3f)" % [expected_even, s_even])
		return false
	return true

func _test_loss_is_zero() -> bool:
	var r := _base_result()
	r["winner"] = "BLUE"
	var s := AiMatchScore.score_for_side(r, true)
	if not is_equal_approx(s, AiMatchScore.LOSS_SCORE):
		push_error("Loss should be LOSS_SCORE")
		return false
	return true
