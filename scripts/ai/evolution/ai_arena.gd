class_name AiArena
extends RefCounted

## Benchmark champion genome vs cascade and vs other population members.

const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")

## `opponents` = other AiGenome instances from the GA population.
static func evaluate_champion(
	champ: AiGenome,
	opponents: Array = [],
	arena_pairs: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0,
	best_fitness: float = 0.0,
	pop_size: int = 0,
	curriculum_tracker = null,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var match_stats: Dictionary = AiEvaluator.empty_match_stats()
	var match_rows: Array = []
	var legion_rows: Array = []
	if champ == null:
		return {
			"vs_cascade": 0.5,
			"vs_cascade_fitness": 1.0,
			"vs_arena": 1.0,
			"vs_arena_fitness": 1.0,
			"best_fitness": best_fitness,
			"archive_size": pop_size,
			"opponents": 0,
			"match_stats": match_stats,
			"match_rows": match_rows,
			"legion_rows": legion_rows,
		}

	var vs_c: Dictionary
	if curriculum_tracker != null and rng != null:
		vs_c = AiEvaluator.evaluate_for_curriculum(
			champ, curriculum_tracker, rng, arena_pairs, map_size, budget, seed_offset, false
		)
	else:
		vs_c = AiEvaluator.evaluate_vs_cascade(
			champ, arena_pairs, map_size, budget, seed_offset
		)
	AiEvaluator.merge_match_stats(match_stats, vs_c.get("match_stats", {}))
	match_rows.append_array(vs_c.get("match_rows", []))
	legion_rows.append_array(vs_c.get("legion_rows", []))

	var arena_points := 0.0
	var opp_n := 0
	for i in range(opponents.size()):
		var opp: AiGenome = opponents[i]
		if opp == null:
			continue
		var vs: Dictionary = AiEvaluator.evaluate_vs_genome(
			champ, opp, arena_pairs, map_size, budget, seed_offset + 17 * (i + 1), false
		)
		arena_points += float(vs.get("fitness", 1.0))
		AiEvaluator.merge_match_stats(match_stats, vs.get("match_stats", {}))
		match_rows.append_array(vs.get("match_rows", []))
		legion_rows.append_array(vs.get("legion_rows", []))
		opp_n += 1

	var vs_arena_fit := 1.0
	if opp_n > 0:
		vs_arena_fit = arena_points / float(opp_n)

	return {
		"vs_cascade": float(vs_c.get("win_rate", 0.5)),
		"vs_cascade_fitness": float(vs_c.get("fitness", 1.0)),
		"vs_arena": vs_arena_fit,
		"vs_arena_fitness": vs_arena_fit,
		"best_fitness": best_fitness,
		"archive_size": pop_size,
		"opponents": opp_n,
		"match_stats": match_stats,
		"match_rows": match_rows,
		"legion_rows": legion_rows,
		"curriculum_report": vs_c,
	}
