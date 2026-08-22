class_name CurriculumScore
extends RefCounted

## Simpler fitness for early curriculum stages (win/loss focused).

const AiMatchScore = preload("res://scripts/ai/evolution/ai_match_score.gd")

const SIMPLE_DRAW_BASE := 0.5

static func score_for_side(result: Dictionary, side_is_green: bool, use_simple: bool) -> float:
	if not use_simple:
		return AiMatchScore.score_for_side(result, side_is_green)
	var outcome := AiMatchScore.outcome_rate(result, side_is_green)
	if is_equal_approx(outcome, 0.5):
		return simple_draw_score(result, side_is_green)
	return outcome

## Draw fitness: 0.5 - remaining_army_frac (full-army stall ≈ -0.5, bloody draw ≈ +0.5).
static func simple_draw_score(result: Dictionary, side_is_green: bool) -> float:
	var my_key := "green" if side_is_green else "blue"
	var my_start := maxf(1.0, float(result.get("gold_start_%s" % my_key, 1.0)))
	var my_end := maxf(0.0, float(result.get("gold_end_%s" % my_key, 0.0)))
	var remaining := clampf(my_end / my_start, 0.0, 1.0)
	return SIMPLE_DRAW_BASE - remaining

static func batch_fitness(
	pair_points: float,
	pair_count: int,
	use_simple: bool,
	rich_points: float = 0.0
) -> float:
	if use_simple:
		return pair_points / float(maxi(pair_count, 1))
	return rich_points / float(maxi(pair_count, 1))
