class_name AiArena
extends RefCounted

## Benchmark champion genome vs cascade and vs other archive elites.

const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")

## Returns scores in win-rate [0,1] plus raw fitness [0,2].
static func evaluate_champion(
	archive: AiMapElitesArchive,
	arena_pairs: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0,
	arena_opponents: int = 3
) -> Dictionary:
	if archive == null or archive.size() == 0:
		return {
			"vs_cascade": 0.5,
			"vs_cascade_fitness": 1.0,
			"vs_arena": 0.5,
			"vs_arena_fitness": 1.0,
			"best_fitness": 0.0,
			"archive_size": 0,
			"opponents": 0,
		}

	var champ: AiGenome = archive.best_genome()
	var vs_c: Dictionary = AiEvaluator.evaluate_vs_cascade(
		champ, arena_pairs, map_size, budget, seed_offset
	)
	var elites: Array = archive.top_elites(arena_opponents + 1)
	var arena_points := 0.0
	var opp_n := 0
	for i in range(elites.size()):
		var row: Dictionary = elites[i]
		var opp: AiGenome = row["genome"]
		# Skip identical champion slot (first is usually best).
		if i == 0:
			continue
		var vs: Dictionary = AiEvaluator.evaluate_vs_genome(
			champ, opp, arena_pairs, map_size, budget, seed_offset + 17 * (i + 1), false
		)
		arena_points += float(vs.get("fitness", 1.0))
		opp_n += 1

	var vs_arena_fit := 1.0
	if opp_n > 0:
		vs_arena_fit = arena_points / float(opp_n)
	else:
		# Solo archive: treat as even.
		vs_arena_fit = 1.0

	return {
		"vs_cascade": float(vs_c.get("win_rate", 0.5)),
		"vs_cascade_fitness": float(vs_c.get("fitness", 1.0)),
		"vs_arena": vs_arena_fit / 2.0,
		"vs_arena_fitness": vs_arena_fit,
		"best_fitness": archive.best_fitness(),
		"archive_size": archive.size(),
		"opponents": opp_n,
	}
