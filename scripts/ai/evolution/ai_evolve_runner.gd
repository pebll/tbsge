class_name AiEvolveRunner
extends RefCounted

## Single-process MAP-Elites loop (fan-out shell can spawn many of these later).

const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiMapElitesArchiveScript = preload("res://scripts/ai/evolution/ai_map_elites_archive.gd")

static func run(
	generations: int = 3,
	population: int = 8,
	pairs_per_eval: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed: int = 42,
	verbose: bool = true
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var archive = AiMapElitesArchiveScript.new(5, 5)

	# Seed archive with hand_v1 and a few mutants.
	var seeds: Array = [AiGenomeScript.from_hand_v1()]
	for _i in range(maxi(0, population - 1)):
		seeds.append(AiGenomeScript.from_hand_v1().mutate(rng, 0.5, 0.5))

	var evals := 0
	for i in range(seeds.size()):
		var report: Dictionary = AiEvaluator.evaluate_genome(
			seeds[i], pairs_per_eval, map_size, budget, seed + i
		)
		archive.try_insert(seeds[i], float(report["fitness"]), report["descriptor"])
		evals += 1
		if verbose:
			print(
				"  seed %d fitness=%.3f cell=%s agg=%.2f risk=%.2f"
				% [
					i,
					float(report["fitness"]),
					archive.cell_key(report["descriptor"]),
					float(report["descriptor"].get("aggression", 0.0)),
					float(report["descriptor"].get("risk", 0.0)),
				]
			)

	for gen in range(generations):
		if verbose:
			print("Generation %d (archive=%d best=%.3f)" % [
				gen + 1, archive.size(), archive.best_fitness()
			])
		for i in range(population):
			var parent: AiGenome = archive.random_elite(rng)
			var child: AiGenome
			if archive.size() >= 2 and rng.randf() < 0.3:
				var parent2: AiGenome = archive.random_elite(rng)
				child = AiGenomeScript.crossover(parent, parent2, rng).mutate(rng)
			else:
				child = parent.mutate(rng)
			var report: Dictionary = AiEvaluator.evaluate_genome(
				child, pairs_per_eval, map_size, budget, seed + 10000 + gen * 100 + i
			)
			var inserted := archive.try_insert(child, float(report["fitness"]), report["descriptor"])
			evals += 1
			if verbose and inserted:
				print(
					"    + cell %s fitness=%.3f"
					% [archive.cell_key(report["descriptor"]), float(report["fitness"])]
				)

	return {
		"generations": generations,
		"population": population,
		"evaluations": evals,
		"archive_size": archive.size(),
		"best_fitness": archive.best_fitness(),
		"summary": archive.to_summary(),
		"archive": archive,
	}

static func print_report(batch: Dictionary) -> void:
	print("")
	print("=== MAP-Elites Evolve Report ===")
	print(
		"Gens: %d | Pop: %d | Evals: %d | Archive: %d | Best fitness: %.3f / 2.0"
		% [
			int(batch.get("generations", 0)),
			int(batch.get("population", 0)),
			int(batch.get("evaluations", 0)),
			int(batch.get("archive_size", 0)),
			float(batch.get("best_fitness", 0.0)),
		]
	)
	var summary: Array = batch.get("summary", [])
	var shown := mini(8, summary.size())
	for i in range(shown):
		var row: Dictionary = summary[i]
		var d: Dictionary = row.get("descriptor", {})
		print(
			"  %s fitness=%.3f agg=%.2f risk=%.2f"
			% [
				String(row.get("cell", "?")),
				float(row.get("fitness", 0.0)),
				float(d.get("aggression", 0.0)),
				float(d.get("risk", 0.0)),
			]
		)
