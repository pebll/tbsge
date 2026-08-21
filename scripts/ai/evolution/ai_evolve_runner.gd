class_name AiEvolveRunner
extends RefCounted

## MAP-Elites evolve with checkpoint persistence, stop/continue, and arena debug.

const AiArena = preload("res://scripts/ai/evolution/ai_arena.gd")
const AiArchiveStore = preload("res://scripts/ai/evolution/ai_archive_store.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiMapElitesArchiveScript = preload("res://scripts/ai/evolution/ai_map_elites_archive.gd")

## Backward-compatible quick run (no persistence).
static func run(
	generations: int = 3,
	population: int = 8,
	pairs_per_eval: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed: int = 42,
	verbose: bool = true
) -> Dictionary:
	return run_session({
		"gens": generations,
		"pop": population,
		"pairs": pairs_per_eval,
		"map_size": map_size,
		"budget": budget,
		"seed": seed,
		"verbose": verbose,
		"run_dir": "",
		"continue_run": false,
		"arena_pairs": 1,
		"arena_opponents": 2,
		"checkpoint_every": 1,
	})

## Options:
##   gens, pop, pairs, map_size, budget, seed, verbose
##   run_dir (empty = ephemeral), continue_run, arena_pairs, arena_opponents
##   checkpoint_every (gens between saves; always saves on stop)
static func run_session(opts: Dictionary) -> Dictionary:
	var gens := int(opts.get("gens", 3))
	var population := int(opts.get("pop", 8))
	var pairs_per_eval := int(opts.get("pairs", 2))
	var map_size := int(opts.get("map_size", 3))
	var budget := int(opts.get("budget", 75))
	var seed := int(opts.get("seed", 42))
	var verbose := bool(opts.get("verbose", true))
	var run_dir := String(opts.get("run_dir", ""))
	var continue_run := bool(opts.get("continue_run", false))
	var arena_pairs := int(opts.get("arena_pairs", 2))
	var arena_opponents := int(opts.get("arena_opponents", 3))
	var checkpoint_every := maxi(1, int(opts.get("checkpoint_every", 1)))

	var rng := RandomNumberGenerator.new()
	var archive = AiMapElitesArchiveScript.new(5, 5)
	var generations_completed := 0
	var evals := 0
	var last_metrics := {}
	var stopped := false
	var config := {
		"pop": population,
		"pairs": pairs_per_eval,
		"map_size": map_size,
		"budget": budget,
		"seed": seed,
		"arena_pairs": arena_pairs,
		"arena_opponents": arena_opponents,
	}

	if continue_run and not run_dir.is_empty() and AiArchiveStore.has_checkpoint(run_dir):
		var loaded := _load_state(run_dir)
		archive = loaded["archive"]
		generations_completed = int(loaded.get("generations_completed", 0))
		evals = int(loaded.get("evaluations", 0))
		last_metrics = loaded.get("last_metrics", {})
		rng.state = int(loaded.get("rng_state", seed))
		var loaded_cfg: Dictionary = loaded.get("config", {})
		# Keep eval hyperparameters from checkpoint unless overridden intentionally.
		population = int(loaded_cfg.get("pop", population))
		pairs_per_eval = int(loaded_cfg.get("pairs", pairs_per_eval))
		map_size = int(loaded_cfg.get("map_size", map_size))
		budget = int(loaded_cfg.get("budget", budget))
		arena_pairs = int(loaded_cfg.get("arena_pairs", arena_pairs))
		arena_opponents = int(loaded_cfg.get("arena_opponents", arena_opponents))
		config = loaded_cfg
		AiArchiveStore.clear_stop(run_dir)
		if verbose:
			print(
				"[evolve] CONTINUE %s gen=%d archive=%d best=%.3f"
				% [run_dir, generations_completed, archive.size(), archive.best_fitness()]
			)
	else:
		rng.seed = seed
		if not run_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
			AiArchiveStore.clear_stop(run_dir)
		# Seed archive.
		var seeds: Array = [AiGenomeScript.from_hand_v1()]
		for _i in range(maxi(0, population - 1)):
			seeds.append(AiGenomeScript.from_hand_v1().mutate(rng, 0.5, 0.5))
		for i in range(seeds.size()):
			var report: Dictionary = AiEvaluator.evaluate_genome(
				seeds[i], pairs_per_eval, map_size, budget, seed + i
			)
			archive.try_insert(seeds[i], float(report["fitness"]), report["descriptor"])
			evals += 1
			if verbose:
				print(
					"  seed %d fitness=%.3f cell=%s"
					% [i, float(report["fitness"]), archive.cell_key(report["descriptor"])]
				)
		last_metrics = _measure_and_log(
			archive, arena_pairs, map_size, budget, seed, arena_opponents, 0, evals, verbose
		)
		if not run_dir.is_empty():
			_save_state(
				run_dir, archive, generations_completed, evals, rng, config, last_metrics, gens
			)
			AiArchiveStore.append_history(run_dir, last_metrics)

	var target_gen := generations_completed + gens
	while generations_completed < target_gen:
		if not run_dir.is_empty() and AiArchiveStore.should_stop(run_dir):
			stopped = true
			if verbose:
				print("[evolve] STOP requested — saving and exiting after gen %d" % generations_completed)
			break

		var gen_idx := generations_completed
		if verbose:
			print(
				"Generation %d/%d (archive=%d best=%.3f)"
				% [gen_idx + 1, target_gen, archive.size(), archive.best_fitness()]
			)

		for i in range(population):
			if not run_dir.is_empty() and AiArchiveStore.should_stop(run_dir):
				stopped = true
				break
			var parent: AiGenome = archive.random_elite(rng)
			var child: AiGenome
			if archive.size() >= 2 and rng.randf() < 0.3:
				var parent2: AiGenome = archive.random_elite(rng)
				child = AiGenomeScript.crossover(parent, parent2, rng).mutate(rng)
			else:
				child = parent.mutate(rng)
			var report: Dictionary = AiEvaluator.evaluate_genome(
				child,
				pairs_per_eval,
				map_size,
				budget,
				seed + 10000 + gen_idx * 100 + i
			)
			var inserted: bool = archive.try_insert(child, float(report["fitness"]), report["descriptor"])
			evals += 1
			if verbose and inserted:
				print(
					"    + cell %s fitness=%.3f"
					% [archive.cell_key(report["descriptor"]), float(report["fitness"])]
				)

		if stopped:
			break

		generations_completed += 1
		last_metrics = _measure_and_log(
			archive,
			arena_pairs,
			map_size,
			budget,
			seed + generations_completed * 97,
			arena_opponents,
			generations_completed,
			evals,
			verbose
		)
		if not run_dir.is_empty() and (
			generations_completed % checkpoint_every == 0
			or generations_completed >= target_gen
		):
			_save_state(
				run_dir, archive, generations_completed, evals, rng, config, last_metrics, target_gen
			)
			if not run_dir.is_empty():
				AiArchiveStore.append_history(run_dir, last_metrics)

	if not run_dir.is_empty():
		_save_state(
			run_dir, archive, generations_completed, evals, rng, config, last_metrics, target_gen
		)
		if stopped:
			AiArchiveStore.clear_stop(run_dir)

	return {
		"generations": generations_completed,
		"generations_added": gens,
		"target_gen": target_gen,
		"population": population,
		"evaluations": evals,
		"archive_size": archive.size(),
		"best_fitness": archive.best_fitness(),
		"summary": archive.to_summary(),
		"archive": archive,
		"last_metrics": last_metrics,
		"run_dir": run_dir,
		"stopped": stopped,
		"vs_cascade": float(last_metrics.get("vs_cascade", 0.0)),
		"vs_arena": float(last_metrics.get("vs_arena", 0.0)),
	}

static func print_status(run_dir: String) -> void:
	if not AiArchiveStore.has_checkpoint(run_dir):
		print("No checkpoint at %s" % run_dir)
		return
	var state := AiArchiveStore.load_checkpoint(run_dir)
	var m: Dictionary = state.get("last_metrics", {})
	print("=== Evolve status: %s ===" % run_dir)
	print(
		"Gen completed: %d | Evals: %d | Archive: %d | Best fitness: %.3f"
		% [
			int(state.get("generations_completed", 0)),
			int(state.get("evaluations", 0)),
			int(state.get("archive_size", 0)),
			float(state.get("best_fitness", 0.0)),
		]
	)
	print(
		"vs cascade: %.1f%% win | vs arena: %.1f%% win | opponents: %d"
		% [
			100.0 * float(m.get("vs_cascade", 0.0)),
			100.0 * float(m.get("vs_arena", 0.0)),
			int(m.get("opponents", 0)),
		]
	)
	if AiArchiveStore.should_stop(run_dir):
		print("STOP file present")

static func print_report(batch: Dictionary) -> void:
	print("")
	print("=== MAP-Elites Evolve Report ===")
	if not String(batch.get("run_dir", "")).is_empty():
		print("Run dir: %s" % batch.get("run_dir", ""))
	print(
		"Gens done: %d | Pop: %d | Evals: %d | Archive: %d | Best fitness: %.3f"
		% [
			int(batch.get("generations", 0)),
			int(batch.get("population", 0)),
			int(batch.get("evaluations", 0)),
			int(batch.get("archive_size", 0)),
			float(batch.get("best_fitness", 0.0)),
		]
	)
	print(
		"Champion vs cascade: %.1f%% | vs arena: %.1f%%%s"
		% [
			100.0 * float(batch.get("vs_cascade", 0.0)),
			100.0 * float(batch.get("vs_arena", 0.0)),
			" | STOPPED" if bool(batch.get("stopped", false)) else "",
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

static func _measure_and_log(
	archive,
	arena_pairs: int,
	map_size: int,
	budget: int,
	seed_offset: int,
	arena_opponents: int,
	gen: int,
	evals: int,
	verbose: bool
) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var arena: Dictionary = AiArena.evaluate_champion(
		archive, arena_pairs, map_size, budget, seed_offset, arena_opponents
	)
	var elapsed := Time.get_ticks_msec() - t0
	var metrics := {
		"gen": gen,
		"evaluations": evals,
		"archive_size": archive.size(),
		"best_fitness": archive.best_fitness(),
		"vs_cascade": float(arena.get("vs_cascade", 0.0)),
		"vs_cascade_fitness": float(arena.get("vs_cascade_fitness", 0.0)),
		"vs_arena": float(arena.get("vs_arena", 0.0)),
		"vs_arena_fitness": float(arena.get("vs_arena_fitness", 0.0)),
		"opponents": int(arena.get("opponents", 0)),
		"arena_ms": elapsed,
		"time": Time.get_datetime_string_from_system(),
	}
	if verbose:
		print(
			"  [arena] vs cascade %.1f%% | vs arena %.1f%% (n=%d) | best fit %.3f | archive %d | %dms"
			% [
				100.0 * float(metrics["vs_cascade"]),
				100.0 * float(metrics["vs_arena"]),
				int(metrics["opponents"]),
				float(metrics["best_fitness"]),
				int(metrics["archive_size"]),
				elapsed,
			]
		)
	return metrics

static func _save_state(
	run_dir: String,
	archive,
	generations_completed: int,
	evals: int,
	rng: RandomNumberGenerator,
	config: Dictionary,
	last_metrics: Dictionary,
	target_gen: int
) -> void:
	var best: AiGenome = archive.best_genome()
	var state := {
		"version": 1,
		"config": config,
		"generations_completed": generations_completed,
		"target_gen": target_gen,
		"evaluations": evals,
		"rng_state": rng.state,
		"archive": archive.to_dict(),
		"archive_size": archive.size(),
		"best_fitness": archive.best_fitness(),
		"best_weights": best.weights.duplicate(true),
		"last_metrics": last_metrics,
	}
	AiArchiveStore.save_checkpoint(run_dir, state)

static func _load_state(run_dir: String) -> Dictionary:
	var state := AiArchiveStore.load_checkpoint(run_dir)
	var archive = AiMapElitesArchiveScript.from_dict(state.get("archive", {}))
	return {
		"archive": archive,
		"generations_completed": int(state.get("generations_completed", 0)),
		"evaluations": int(state.get("evaluations", 0)),
		"rng_state": int(state.get("rng_state", 0)),
		"config": state.get("config", {}),
		"last_metrics": state.get("last_metrics", {}),
	}
