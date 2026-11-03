class_name AiEvolveRunner
extends RefCounted

## Generational genetic algorithm for utility weights (MAP-Elites retired).

const AiArena = preload("res://scripts/ai/evolution/ai_arena.gd")
const AiArchiveStore = preload("res://scripts/ai/evolution/ai_archive_store.gd")
const AiCurriculumScript = preload("res://scripts/ai/curriculum/ai_curriculum.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiEvolveBalanceLogScript = preload("res://scripts/ai/evolution/ai_evolve_balance_log.gd")
const AiGaPopulationScript = preload("res://scripts/ai/evolution/ai_ga_population.gd")
const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiMatchScore = preload("res://scripts/ai/evolution/ai_match_score.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
const CurriculumTrackerScript = preload("res://scripts/ai/curriculum/curriculum_tracker.gd")
const AiDuelTraceScript = preload("res://scripts/ai/evolution/ai_duel_trace.gd")
const AiEvalParallel = preload("res://scripts/ai/evolution/ai_eval_parallel.gd")
const AiEvolveHistory = preload("res://scripts/ai/evolution/ai_evolve_history.gd")

const PROMOTE_EVERY_DEFAULT := 5

## Measurements only an arena run produces; absent from history rows when the arena was skipped.
const ARENA_METRIC_KEYS := [
	"vs_cascade", "vs_cascade_fitness", "vs_arena", "vs_arena_fitness", "opponents", "arena_ms", "match_stats",
]
const TRAIN_SEED_BASE := 10000
const ARENA_SEED_BASE := 100000000

static func run(
	generations: int = 3,
	population: int = 16,
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
		"arena_every": 10,
		"checkpoint_every": 1,
	})

static func run_session(opts: Dictionary) -> Dictionary:
	var gens := int(opts.get("gens", 3))
	var population_size := int(opts.get("pop", AiGaPopulationScript.DEFAULT_POP))
	var elite_count := _resolve_elite_count(
		population_size, int(opts.get("elites", AiGaPopulationScript.ELITE_COUNT))
	)
	var pairs_per_eval := int(opts.get("pairs", 2))
	var map_size := int(opts.get("map_size", 3))
	var budget := int(opts.get("budget", 75))
	var seed := int(opts.get("seed", 42))
	var verbose := bool(opts.get("verbose", true))
	var run_dir := String(opts.get("run_dir", ""))
	var continue_run := bool(opts.get("continue_run", false))
	var arena_pairs := int(opts.get("arena_pairs", 2))
	var arena_opponents := int(opts.get("arena_opponents", 3))
	var arena_every := maxi(1, int(opts.get("arena_every", 10)))
	var promote_every := maxi(1, int(opts.get("promote_every", PROMOTE_EVERY_DEFAULT)))
	var checkpoint_every := maxi(1, int(opts.get("checkpoint_every", 1)))
	var curriculum_enabled := bool(opts.get("curriculum", true))
	var legacy_teacher := bool(opts.get("legacy_teacher", false))
	var no_promote := bool(opts.get("no_promote", false))
	var force_stage := String(opts.get("force_stage", ""))
	var debug_duel := bool(opts.get("debug_duel", false))
	var cores := maxi(1, int(opts.get("cores", 1)))
	cores = mini(cores, maxi(1, OS.get_processor_count()))

	if debug_duel:
		AiDuelTraceScript.enabled = true
	var rng := RandomNumberGenerator.new()
	var pop = AiGaPopulationScript.new()
	var curriculum = CurriculumTrackerScript.new()
	if no_promote:
		curriculum.promotions_blocked = true
	var generations_completed := 0
	var evals := 0
	var last_metrics := {}
	var stopped := false
	## generation index -> seed offsets of every eval job (elites + children) in that generation.
	var generation_seed_offsets: Dictionary = {}
	var match_stats_total: Dictionary = AiEvaluator.empty_match_stats()
	var rolling_outcomes: Array = []
	var teacher_on := true
	var balance_log = AiEvolveBalanceLogScript.new()
	var config := {
		"algo": "ga",
		"pop": population_size,
		"elites": elite_count,
		"pairs": pairs_per_eval,
		"map_size": map_size,
		"budget": budget,
		"seed": seed,
		"arena_pairs": arena_pairs,
		"arena_opponents": arena_opponents,
		"arena_every": arena_every,
		"promote_every": promote_every,
		"curriculum": curriculum_enabled and not legacy_teacher,
		"cores": cores,
	}

	var use_curriculum := curriculum_enabled and not legacy_teacher

	if continue_run and not run_dir.is_empty() and AiArchiveStore.has_checkpoint(run_dir):
		var loaded := _load_state(run_dir, population_size, rng)
		pop = loaded["population"]
		generations_completed = int(loaded.get("generations_completed", 0))
		evals = int(loaded.get("evaluations", 0))
		last_metrics = loaded.get("last_metrics", {})
		match_stats_total = loaded.get("match_stats", AiEvaluator.empty_match_stats())
		if match_stats_total.is_empty():
			match_stats_total = AiEvaluator.empty_match_stats()
		rolling_outcomes = loaded.get("rolling_outcomes", [])
		if typeof(rolling_outcomes) != TYPE_ARRAY:
			rolling_outcomes = []
		teacher_on = bool(loaded.get("teacher_on", true))
		if loaded.has("curriculum"):
			curriculum = CurriculumTrackerScript.from_dict(loaded.get("curriculum", {}))
		if no_promote:
			curriculum.promotions_blocked = true
		rng.state = int(loaded.get("rng_state", seed))
		var loaded_cfg: Dictionary = loaded.get("config", {})
		var overrides: Dictionary = opts.get("cli_overrides", {})
		population_size = int(overrides.get("pop", loaded_cfg.get("pop", population_size)))
		elite_count = _resolve_elite_count(
			population_size,
			int(overrides.get("elites", loaded_cfg.get("elites", elite_count)))
		)
		pairs_per_eval = int(overrides.get("pairs", loaded_cfg.get("pairs", pairs_per_eval)))
		map_size = int(overrides.get("map_size", loaded_cfg.get("map_size", map_size)))
		budget = int(overrides.get("budget", loaded_cfg.get("budget", budget)))
		arena_pairs = int(overrides.get("arena_pairs", loaded_cfg.get("arena_pairs", arena_pairs)))
		arena_opponents = int(
			overrides.get("arena_opponents", loaded_cfg.get("arena_opponents", arena_opponents))
		)
		arena_every = maxi(1, int(overrides.get("arena_every", loaded_cfg.get("arena_every", arena_every))))
		promote_every = maxi(1, int(overrides.get("promote_every", loaded_cfg.get("promote_every", promote_every))))
		config = loaded_cfg
		config["algo"] = "ga"
		config["pop"] = population_size
		config["pairs"] = pairs_per_eval
		config["map_size"] = map_size
		config["budget"] = budget
		config["arena_pairs"] = arena_pairs
		config["arena_opponents"] = arena_opponents
		config["arena_every"] = arena_every
		config["promote_every"] = promote_every
		config["elites"] = elite_count
		config["curriculum"] = use_curriculum
		cores = maxi(1, int(overrides.get("cores", loaded_cfg.get("cores", cores))))
		cores = mini(cores, maxi(1, OS.get_processor_count()))
		config["cores"] = cores
		use_curriculum = bool(loaded_cfg.get("curriculum", use_curriculum))
		if rolling_outcomes.is_empty() and int(match_stats_total.get("games", 0)) > 0:
			AiEvaluator.append_rolling_outcomes(rolling_outcomes, match_stats_total)
		teacher_on = AiEvaluator.next_teacher_state(teacher_on, rolling_outcomes)
		AiArchiveStore.clear_stop(run_dir)
		balance_log.load_from_dir(run_dir)
		# Re-eval any members that were padded with unknown fitness.
		evals += _ensure_population_evaluated(
			pop, population_size, rng, teacher_on, pairs_per_eval, map_size, budget, seed,
			match_stats_total, rolling_outcomes, balance_log, verbose,
			use_curriculum, curriculum, cores
		)
		teacher_on = AiEvaluator.next_teacher_state(teacher_on, rolling_outcomes)
		if verbose:
			var stage: Dictionary = AiCurriculumScript.stage_at(curriculum.stage_index)
			var override_note := ""
			if not overrides.is_empty():
				override_note = " | overrides: %s" % ", ".join(overrides.keys())
			print(
				"[evolve] CONTINUE %s | gen %d | best %.3f | pairs=%d%s | %s"
				% [
					run_dir,
					generations_completed,
					pop.best_fitness(),
					pairs_per_eval,
					override_note,
					AiCurriculumScript.promotion_progress(stage, curriculum, _champ_member_desc(pop))
					if use_curriculum
					else "teacher=%s draw=%.0f%%"
					% ["on" if teacher_on else "off", 100.0 * AiEvaluator.rolling_draw_rate(rolling_outcomes)],
				]
			)
	else:
		rng.seed = seed
		_apply_force_stage(curriculum, force_stage)
		if not run_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
			AiArchiveStore.clear_stop(run_dir)
		var seed_jobs: Array = []
		for i in range(population_size):
			var g: AiGenome = AiGenomeScript.from_hand_v1()
			if i > 0:
				g = g.mutate(rng, 0.5, 0.5)
			seed_jobs.append(
				_make_eval_job(
					g, {}, generation_seed_offset(seed, -1), seed, pop, rng, teacher_on, pairs_per_eval, map_size, budget,
					use_curriculum, curriculum, true
				)
			)
		var seed_results: Array = AiEvalParallel.run_jobs(seed_jobs, cores)
		for i in range(population_size):
			var g: AiGenome = seed_jobs[i]["genome"]
			var result: Dictionary = seed_results[i]
			var report: Dictionary = result.get("report", {})
			var eval_ms: int = int(result.get("eval_ms", 0))
			AiEvaluator.merge_match_stats(match_stats_total, report.get("match_stats", {}))
			AiEvaluator.append_rolling_outcomes(rolling_outcomes, report.get("match_stats", {}))
			teacher_on = AiEvaluator.next_teacher_state(teacher_on, rolling_outcomes)
			balance_log.ingest_report(report)
			var desc: Dictionary = (report.get("descriptor", {}) as Dictionary).duplicate(true)
			var fit := AiGaPopulationScript.accumulate_eval(desc, report)
			pop.add_member(g, fit, desc)
			evals += 1
			if verbose:
				_log_fitness_eval(
					"seed", i, report, eval_ms, teacher_on, use_curriculum, fit, desc
				)
		pop.sort_desc()
		last_metrics = _measure_and_log(
			pop, arena_pairs, map_size, budget, arena_seed_offset(seed, 0), arena_opponents, 0, evals, verbose,
			not use_curriculum, {},
			arena_every, promote_every, use_curriculum, curriculum, rng
		)
		if use_curriculum:
			_run_curriculum_promotion_check(
				pop, curriculum, rng, arena_pairs, map_size, budget,
				seed + generations_completed * 31, generations_completed, verbose
			)
		AiEvaluator.merge_match_stats(match_stats_total, last_metrics.get("match_stats", {}))
		AiEvaluator.append_rolling_outcomes(rolling_outcomes, last_metrics.get("match_stats", {}))
		teacher_on = AiEvaluator.next_teacher_state(teacher_on, rolling_outcomes)
		balance_log.ingest_report(last_metrics)
		if not run_dir.is_empty():
			balance_log.save(run_dir)
			_save_state(
				run_dir, pop, generations_completed, evals, rng, config, last_metrics, gens,
				match_stats_total, rolling_outcomes, teacher_on, curriculum
			)
			AiArchiveStore.append_history(
				run_dir, _history_row(last_metrics, pop, curriculum, use_curriculum)
			)

	var target_gen := generations_completed + gens
	while generations_completed < target_gen:
		if not run_dir.is_empty() and AiArchiveStore.should_stop(run_dir):
			stopped = true
			if verbose:
				print("[evolve] STOP requested — saving after gen %d" % generations_completed)
			break

		var gen_idx := generations_completed
		if verbose:
			_print_generation_header(
				gen_idx + 1, target_gen, pop, use_curriculum, curriculum, teacher_on, rolling_outcomes
			)

		var next_pop = AiGaPopulationScript.new()
		pop.sort_desc()
		var gen_best_before: float = pop.best_fitness()
		var gen_best_after: float = gen_best_before
		var elite_n := mini(elite_count, pop.size())
		var elite_pairs := _elite_pairs_per_eval(pairs_per_eval)
		var elite_worst_before := -INF
		var elite_best_before := -INF
		if elite_n > 0:
			elite_worst_before = float(pop.members[elite_n - 1].get("fitness", -INF))
			elite_best_before = float(pop.members[0].get("fitness", -INF))
		var elite_jobs: Array = []
		for e in range(elite_n):
			var em: Dictionary = pop.members[e]
			var elite_genome: AiGenome = em["genome"]
			var rehearsal_idx := AiEvaluator.elite_rehearsal_stage_index(curriculum, e, elite_pairs)
			elite_jobs.append(
				_make_eval_job(
					elite_genome,
					(em.get("descriptor", {}) as Dictionary).duplicate(true),
					generation_seed_offset(seed, gen_idx),
					seed,
					pop,
					rng,
					teacher_on,
					elite_pairs,
					map_size,
					budget,
					use_curriculum,
					curriculum,
					false,
					rehearsal_idx
				)
			)
		var elite_results: Array = AiEvalParallel.run_jobs(elite_jobs, cores) if elite_n > 0 else []
		for e in range(elite_n):
			var em: Dictionary = pop.members[e]
			var elite_genome: AiGenome = em["genome"]
			var result: Dictionary = elite_results[e]
			var elite_report: Dictionary = result.get("report", {})
			var elite_ms: int = int(result.get("eval_ms", 0))
			AiEvaluator.merge_match_stats(match_stats_total, elite_report.get("match_stats", {}))
			AiEvaluator.append_rolling_outcomes(rolling_outcomes, elite_report.get("match_stats", {}))
			teacher_on = AiEvaluator.next_teacher_state(teacher_on, rolling_outcomes)
			balance_log.ingest_report(elite_report)
			var elite_desc: Dictionary = (em.get("descriptor", {}) as Dictionary).duplicate(true)
			var prior_fit := float(em.get("fitness", -INF))
			var elite_fit := AiGaPopulationScript.accumulate_eval(
				elite_desc, elite_report, prior_fit
			)
			next_pop.add_member(elite_genome, elite_fit, elite_desc)
			evals += 1
			if verbose:
				if elite_fit > gen_best_after:
					gen_best_after = elite_fit
				_log_fitness_eval(
					"elite", e, elite_report, elite_ms, teacher_on,
					use_curriculum, elite_fit, elite_desc,
					elite_worst_before, elite_best_before
				)
		var elite_worst_after := -INF
		var elite_best_after := -INF
		if elite_n > 0:
			var elite_bounds_after := _elite_fitness_bounds(next_pop.members, elite_n)
			elite_worst_after = elite_bounds_after.x
			elite_best_after = elite_bounds_after.y
		if verbose and elite_n > 0:
			print(
				"  reeval %d elite @ %d pairs (child %d) | pop best %.3f"
				% [elite_n, elite_pairs, pairs_per_eval, next_pop.best_fitness()]
			)

		var child_i := 0
		var child_evals := 0
		var child_beat_worst := 0
		var child_beat_best := 0
		var child_specs: Array = []
		while next_pop.size() + child_specs.size() < population_size:
			if not run_dir.is_empty() and AiArchiveStore.should_stop(run_dir):
				stopped = true
				break
			var parent: AiGenome = pop.tournament_select(rng)
			var child: AiGenome
			if pop.size() >= 2 and rng.randf() < 0.35:
				var parent2: AiGenome = pop.tournament_select(rng)
				child = AiGenomeScript.crossover(parent, parent2, rng).mutate(rng)
			else:
				child = parent.mutate(rng)
			child_specs.append({
				"genome": child,
				"seed_offset": generation_seed_offset(seed, gen_idx),
				"index": child_i,
			})
			child_i += 1

		var child_jobs: Array = []
		for spec in child_specs:
			child_jobs.append(
				_make_eval_job(
					spec["genome"],
					{},
					int(spec["seed_offset"]),
					seed,
					pop,
					rng,
					teacher_on,
					pairs_per_eval,
					map_size,
					budget,
					use_curriculum,
					curriculum,
					true
				)
			)
		var gen_offsets: Array = []
		for job in elite_jobs + child_jobs:
			gen_offsets.append(int(job["seed_offset"]))
		generation_seed_offsets[gen_idx] = gen_offsets
		var child_results: Array = AiEvalParallel.run_jobs(child_jobs, cores)
		for i in range(child_specs.size()):
			var spec: Dictionary = child_specs[i]
			var result: Dictionary = child_results[i]
			var report: Dictionary = result.get("report", {})
			var eval_ms: int = int(result.get("eval_ms", 0))
			var child: AiGenome = spec["genome"]
			AiEvaluator.merge_match_stats(match_stats_total, report.get("match_stats", {}))
			AiEvaluator.append_rolling_outcomes(rolling_outcomes, report.get("match_stats", {}))
			teacher_on = AiEvaluator.next_teacher_state(teacher_on, rolling_outcomes)
			balance_log.ingest_report(report)
			var child_desc: Dictionary = (report.get("descriptor", {}) as Dictionary).duplicate(true)
			var child_fit := AiGaPopulationScript.accumulate_eval(child_desc, report)
			next_pop.add_member(child, child_fit, child_desc)
			evals += 1
			child_evals += 1
			if child_fit > elite_best_after:
				child_beat_best += 1
			elif child_fit > elite_worst_after:
				child_beat_worst += 1
			if child_fit > gen_best_after:
				gen_best_after = child_fit
			if verbose:
				_log_fitness_eval(
					"child", int(spec["index"]), report, eval_ms, teacher_on, use_curriculum, child_fit,
					child_desc, elite_worst_after, elite_best_after
				)

		if verbose and child_evals > 0:
			next_pop.sort_desc()
			print(
				"  %d children (+%d !!%d) | pop best %.3f"
				% [child_evals, child_beat_worst, child_beat_best, next_pop.best_fitness()]
			)

		if stopped:
			break

		pop = next_pop
		pop.sort_desc()
		generations_completed += 1
		var run_arena := _should_run_arena(
			generations_completed, arena_every, generations_completed >= target_gen, use_curriculum
		)
		last_metrics = _measure_and_log(
			pop, arena_pairs, map_size, budget, arena_seed_offset(seed, generations_completed),
			arena_opponents, generations_completed, evals, verbose, run_arena, last_metrics,
			arena_every, promote_every, use_curriculum, curriculum, rng
		)
		if use_curriculum and _should_run_promotion_check(
			generations_completed, promote_every, generations_completed >= target_gen
		):
			_run_curriculum_promotion_check(
				pop, curriculum, rng, arena_pairs, map_size, budget,
				seed + generations_completed * 31 + 7000, generations_completed, verbose
			)
		if run_arena:
			AiEvaluator.merge_match_stats(match_stats_total, last_metrics.get("match_stats", {}))
			AiEvaluator.append_rolling_outcomes(rolling_outcomes, last_metrics.get("match_stats", {}))
			teacher_on = AiEvaluator.next_teacher_state(teacher_on, rolling_outcomes)
			balance_log.ingest_report(last_metrics)
			if not run_dir.is_empty():
				balance_log.save(run_dir)
		if AiEvolveBalanceLogScript.should_print_summary(generations_completed):
			_print_decade_summary(
				generations_completed, pop, evals, teacher_on, rolling_outcomes,
				match_stats_total, last_metrics, balance_log, use_curriculum, curriculum
			)
		if not run_dir.is_empty() and (
			generations_completed % checkpoint_every == 0
			or generations_completed >= target_gen
		):
			_save_state(
				run_dir, pop, generations_completed, evals, rng, config, last_metrics, target_gen,
				match_stats_total, rolling_outcomes, teacher_on, curriculum
			)
			balance_log.save(run_dir)
			AiArchiveStore.append_history(
				run_dir, _history_row(last_metrics, pop, curriculum, use_curriculum)
			)

	if not run_dir.is_empty():
		balance_log.save(run_dir)
		_save_state(
			run_dir, pop, generations_completed, evals, rng, config, last_metrics, target_gen,
			match_stats_total, rolling_outcomes, teacher_on, curriculum
		)
		if stopped:
			AiArchiveStore.clear_stop(run_dir)

	return {
		"generations": generations_completed,
		"generations_added": gens,
		"target_gen": target_gen,
		"population": population_size,
		"evaluations": evals,
		"archive_size": pop.size(),
		"best_fitness": pop.best_fitness(),
		"summary": pop.to_summary(),
		"population_obj": pop,
		"last_metrics": last_metrics,
		"run_dir": run_dir,
		"stopped": stopped,
		"generation_seed_offsets": generation_seed_offsets,
		"vs_cascade": float(last_metrics.get("vs_cascade", 0.0)),
		"vs_arena": float(last_metrics.get("vs_arena", 0.0)),
		"vs_arena_fitness": float(last_metrics.get("vs_arena_fitness", 0.0)),
		"match_stats": match_stats_total,
		"teacher_on": teacher_on,
		"rolling_draw_rate": AiEvaluator.rolling_draw_rate(rolling_outcomes),
		"balance_log": balance_log,
		"curriculum": curriculum.to_dict(),
		"curriculum_stage": AiCurriculumScript.stage_at(curriculum.stage_index).get("id", ""),
	}

static func print_status(run_dir: String) -> void:
	if not AiArchiveStore.has_checkpoint(run_dir):
		print("No checkpoint at %s" % run_dir)
		return
	var state := AiArchiveStore.load_checkpoint(run_dir)
	var m: Dictionary = state.get("last_metrics", {})
	print("=== Evolve status (GA): %s ===" % run_dir)
	print(
		"Gen completed: %d | Evals: %d | Pop: %d | Elites: %d | Best fitness: %.3f"
		% [
			int(state.get("generations_completed", 0)),
			int(state.get("evaluations", 0)),
			int(state.get("population_size", state.get("archive_size", 0))),
			int(state.get("config", {}).get("elites", AiGaPopulationScript.ELITE_COUNT)),
			float(state.get("best_fitness", 0.0)),
		]
	)
	var cfg: Dictionary = state.get("config", {})
	if int(cfg.get("cores", 1)) > 1:
		print("Parallel eval cores: %d" % int(cfg.get("cores", 1)))
	print(
		"vs stage/cascade: %.1f%% win | vs pop fitness: %.3f | opponents: %d"
		% [
			100.0 * float(m.get("vs_cascade", 0.0)),
			float(m.get("vs_arena_fitness", m.get("vs_arena", 0.0))),
			int(m.get("opponents", 0)),
		]
	)
	var cur: Dictionary = state.get("curriculum", {})
	if not cur.is_empty():
		var tracker = CurriculumTrackerScript.from_dict(cur)
		var stage: Dictionary = AiCurriculumScript.stage_at(tracker.stage_index)
		print(
			"Curriculum: stage %d/%d (%s) hof=%d"
			% [
				tracker.stage_index + 1,
				AiCurriculumScript.stage_count(),
				String(stage.get("id", "?")),
				tracker.hall_of_fame.size(),
			]
		)
		if not tracker.last_promote_audit.is_empty():
			print("  last %s" % AiCurriculumScript.format_promotion_audit(tracker.last_promote_audit))
		print("  %s" % AiCurriculumScript.promotion_progress(stage, tracker))
	var run_stats: Dictionary = state.get("match_stats", {})
	if not run_stats.is_empty():
		print("Run matches: %s" % AiEvaluator.format_match_stats(run_stats))
	var bal = AiEvolveBalanceLogScript.new()
	bal.load_from_dir(run_dir)
	if bal.match_rows.size() > 0:
		print("Balance log: %d matches" % bal.match_rows.size())
		bal.print_interim_balance_insights()
	if AiArchiveStore.should_stop(run_dir):
		print("STOP file present")

static func print_balance(run_dir: String) -> void:
	var bal = AiEvolveBalanceLogScript.new()
	bal.load_from_dir(run_dir)
	if bal.match_rows.is_empty():
		print("No balance CSVs at %s" % bal.balance_dir(run_dir))
		return
	bal.print_full_balance_report(run_dir)

static func print_report(batch: Dictionary) -> void:
	print("")
	print("=== GA Evolve Report ===")
	if not String(batch.get("run_dir", "")).is_empty():
		print("Run dir: %s" % batch.get("run_dir", ""))
	print(
		"Gens done: %d | Pop: %d | Evals: %d | Best fitness: %.3f"
		% [
			int(batch.get("generations", 0)),
			int(batch.get("population", 0)),
			int(batch.get("evaluations", 0)),
			float(batch.get("best_fitness", 0.0)),
		]
	)
	print(
		"Champion vs stage/cascade: %.1f%% | vs pop fitness: %.3f%s"
		% [
			100.0 * float(batch.get("vs_cascade", 0.0)),
			float(batch.get("vs_arena_fitness", batch.get("vs_arena", 0.0))),
			" | STOPPED" if bool(batch.get("stopped", false)) else "",
		]
	)
	if batch.has("curriculum_stage") and not String(batch.get("curriculum_stage", "")).is_empty():
		print("Curriculum stage: %s" % batch.get("curriculum_stage", ""))
	var run_stats: Dictionary = batch.get("match_stats", {})
	if not run_stats.is_empty():
		var games := int(run_stats.get("games", 0))
		var draws := (
			int(run_stats.get("stale_draws", 0))
			+ int(run_stats.get("timeouts", 0))
			+ int(run_stats.get("other_draws", 0))
		)
		print("Matches: %d games, %.0f%% draws" % [games, 100.0 * float(draws) / float(maxi(games, 1))])
	var summary: Array = batch.get("summary", [])
	for i in range(mini(5, summary.size())):
		var row: Dictionary = summary[i]
		print("  #%d fitness=%.3f" % [int(row.get("rank", i + 1)), float(row.get("fitness", 0.0))])
	var bal = batch.get("balance_log", null)
	var has_curriculum := batch.has("curriculum_stage") and not String(batch.get("curriculum_stage", "")).is_empty()
	if not has_curriculum:
		if bal == null and not String(batch.get("run_dir", "")).is_empty():
			bal = AiEvolveBalanceLogScript.new()
			bal.load_from_dir(String(batch.get("run_dir", "")))
		if bal != null and bal.match_rows.size() > 0:
			bal.print_interim_balance_insights()
			print("Balance CSVs: %s" % bal.balance_dir(String(batch.get("run_dir", ""))))

static func _evaluate_member(
	genome: AiGenome,
	pop,
	rng: RandomNumberGenerator,
	teacher_on: bool,
	pairs_per_eval: int,
	map_size: int,
	budget: int,
	seed_offset: int,
	use_curriculum: bool,
	curriculum: CurriculumTrackerScript,
	allow_confirm: bool = true
) -> Dictionary:
	var pop_for_confirm = pop if allow_confirm else null
	if use_curriculum:
		return AiEvaluator.evaluate_for_curriculum_with_confirm(
			genome, curriculum, rng, pop_for_confirm, pairs_per_eval, map_size, budget, seed_offset
		)
	return AiEvaluator.evaluate_for_evolve_with_confirm(
		genome, pop_for_confirm, rng, teacher_on, pairs_per_eval, map_size, budget, seed_offset
	)

## Training seed offset shared by every genome evaluated in generation `gen` (-1 = initial
## population / re-evaluation), so all of them play the same games (common random numbers).
## Game indices are offset * 1000 + pair, so a stride of 1000 keeps generations disjoint.
static func generation_seed_offset(seed: int, gen: int) -> int:
	return seed + TRAIN_SEED_BASE + gen * 1000

## Arena (vs cascade / vs population) seed offset: a range far above any training offset.
static func arena_seed_offset(seed: int, gen: int) -> int:
	return seed + ARENA_SEED_BASE + gen * 97

static func _confirm_threshold(pop) -> float:
	if pop == null or pop.size() == 0:
		return NAN
	return pop.best_fitness() - 0.05

static func _make_eval_job(
	genome: AiGenome,
	_descriptor: Dictionary,
	seed_offset: int,
	base_seed: int,
	pop,
	rng: RandomNumberGenerator,
	teacher_on: bool,
	pairs_per_eval: int,
	map_size: int,
	budget: int,
	use_curriculum: bool,
	curriculum: CurriculumTrackerScript,
	allow_confirm: bool,
	rehearsal_stage_index: int = -1
) -> Dictionary:
	var job := {
		"genome": genome.duplicate_genome(),
		"rng_seed": base_seed + seed_offset * 9973,
		"seed_offset": seed_offset,
		"pairs": pairs_per_eval,
		"map_size": map_size,
		"budget": budget,
		"use_curriculum": use_curriculum,
		"collect_probe": allow_confirm and use_curriculum,
		"rehearsal_stage_index": rehearsal_stage_index,
	}
	if use_curriculum:
		job["curriculum"] = curriculum.to_dict()
	else:
		job["teacher_on"] = teacher_on
		if not teacher_on and pop != null and pop.size() >= 2:
			if rng.randf() < AiEvaluator.POST_TEACHER_ELITE_FRAC:
				job["forced_opponent"] = pop.random_genome(rng, true)
	if allow_confirm and pop != null and pop.size() > 0:
		job["confirm_min_fitness"] = _confirm_threshold(pop)
	return job

static func _apply_force_stage(curriculum: CurriculumTrackerScript, force_stage: String) -> void:
	if force_stage.is_empty():
		return
	var idx := AiCurriculumScript.find_stage_index(force_stage)
	if idx < 0:
		push_warning("Unknown curriculum stage '%s'; starting at 0" % force_stage)
		return
	curriculum.stage_index = idx
	curriculum.last_promote_audit = {}

static func _champ_member_desc(pop) -> Dictionary:
	if pop == null or pop.members.is_empty():
		return {}
	pop.sort_desc()
	return (pop.members[0].get("descriptor", {}) as Dictionary).duplicate(true)

static func _reset_pop_stage_eval_cum(pop) -> void:
	if pop == null:
		return
	for m in pop.members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var desc: Dictionary = (m as Dictionary).get("descriptor", {})
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		AiGaPopulationScript.reset_stage_eval_cum(desc)

static func _should_run_promotion_check(gen: int, promote_every: int, is_session_end: bool) -> bool:
	if gen <= 0:
		return true
	if is_session_end:
		return true
	return gen % maxi(1, promote_every) == 0

static func _run_curriculum_promotion_check(
	pop,
	curriculum: CurriculumTrackerScript,
	rng: RandomNumberGenerator,
	_arena_pairs: int,
	map_size: int,
	budget: int,
	seed_offset: int,
	gen: int,
	verbose: bool
) -> void:
	if curriculum == null or curriculum.promotions_blocked:
		return
	pop.sort_desc()
	var champ: AiGenome = pop.members[0]["genome"]
	var desc: Dictionary = _champ_member_desc(pop)
	var audit: Dictionary = AiEvaluator.evaluate_curriculum_promotion_audit(
		champ, curriculum, desc, rng, map_size, budget, seed_offset
	)
	curriculum.set_last_promote_audit(audit)
	if verbose:
		_log_promote_check(pop, curriculum, audit, gen)
	_maybe_promote_curriculum(curriculum, pop, gen, verbose)

static func _champ_pop_label(pop) -> String:
	if pop == null or pop.members.is_empty():
		return "p0"
	pop.sort_desc()
	var desc: Dictionary = (pop.members[0].get("descriptor", {}) as Dictionary)
	var label := String(desc.get("pop_label", ""))
	if not label.is_empty():
		return label
	return "p0"

static func _log_promote_check(
	pop,
	curriculum: CurriculumTrackerScript,
	audit: Dictionary,
	gen: int
) -> void:
	var label := _champ_pop_label(pop)
	var fit: float = pop.best_fitness() if pop != null else 0.0
	var wins := int(audit.get("trainee_wins", 0))
	var losses := int(audit.get("trainee_losses", 0))
	var draws := int(audit.get("trainee_draws", 0))
	var cum_wr := 100.0 * float(audit.get("audit_win_rate", 0.0))
	var wld_report := {
		"trainee_stale_draws": 0,
		"trainee_timeouts": 0,
		"trainee_other_draws": 0,
		"trainee_draft_failures": 0,
	}
	var cum_wld := _format_wld(wins, losses, draws, wld_report)
	var need_games := int(audit.get("need_games", 0))
	var need_wr := 100.0 * float(audit.get("need_win_rate", 0.0))
	var stage_id := String(audit.get("stage_id", "?"))
	var verdict := "PROMOTE" if bool(audit.get("promotion_passed", false)) else "HOLD"
	var reasons: PackedStringArray = []
	if not bool(audit.get("current_passed", false)):
		if wins + losses + draws < need_games:
			reasons.append("eval cum %d/%d games" % [wins + losses + draws, need_games])
		else:
			reasons.append("eval cum wr %.1f%% < %.0f%%" % [cum_wr, need_wr])
	if not bool(audit.get("retention_passed", true)):
		reasons.append("retention")
	var tail := (" — %s" % ", ".join(reasons)) if not reasons.is_empty() else ""
	print(
		"  [promote-check gen %d] %s %s fit=%.3f wr=%.0f%% (%s) eval-cum %s%s"
		% [gen, verdict, label, fit, cum_wr, cum_wld, stage_id, tail]
	)
	var retention: Dictionary = audit.get("retention", {})
	for row in retention.get("stages", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var sid := String(d.get("stage_id", "?"))
		var mark := "✓" if bool(d.get("passed", false)) else "✗"
		var rw := int(d.get("trainee_wins", 0))
		var rl := int(d.get("trainee_losses", 0))
		var rd := int(d.get("trainee_draws", 0))
		var rwr := 100.0 * float(d.get("win_rate", 0.0))
		var rneed := 100.0 * float(d.get("need_win_rate", 0.0))
		var rneed_g := int(d.get("need_games", 0))
		print(
			"    retain %s %s wr=%.0f%% (%s) %d/%d (≥%.0f%%)"
			% [sid, mark, rwr, _format_wld(rw, rl, rd, d.get("report", {})), rw + rl + rd, rneed_g, rneed]
		)

static func _maybe_promote_curriculum(
	curriculum: CurriculumTrackerScript,
	pop,
	at_gen: int,
	verbose: bool
) -> void:
	var stage: Dictionary = AiCurriculumScript.stage_at(curriculum.stage_index)
	if curriculum.stage_index >= AiCurriculumScript.stage_count() - 1:
		return
	if not curriculum.should_promote(stage):
		return
	if bool(stage.get("save_hof_on_promote", false)):
		curriculum.add_hall_of_fame(pop.best_genome(), String(stage.get("id", "")), at_gen)
	var wr := float(curriculum.last_promote_audit.get("audit_win_rate", 0.0))
	var games := int(curriculum.last_promote_audit.get("audit_games", 0))
	var stage_id := String(stage.get("id", ""))
	var audit_copy: Dictionary = curriculum.last_promote_audit.duplicate(true)
	curriculum.promote(stage_id, at_gen, wr)
	_reset_pop_stage_eval_cum(pop)
	var next: Dictionary = AiCurriculumScript.stage_at(curriculum.stage_index)
	if verbose:
		print(
			"[curriculum] PROMOTED gen=%d %s -> %s | champ %s audit wr=%.0f%% over %d games"
			% [
				at_gen,
				stage_id,
				String(next.get("id", "?")),
				_champ_pop_label(pop),
				100.0 * wr,
				games,
			]
		)
		print("    %s" % AiCurriculumScript.format_promotion_audit(audit_copy))

static func _ensure_population_evaluated(
	pop,
	population_size: int,
	rng: RandomNumberGenerator,
	teacher_on: bool,
	pairs_per_eval: int,
	map_size: int,
	budget: int,
	seed: int,
	match_stats_total: Dictionary,
	rolling_outcomes: Array,
	balance_log,
	verbose: bool,
	use_curriculum: bool = false,
	curriculum: CurriculumTrackerScript = null,
	cores: int = 1
) -> int:
	var added := 0
	# Pad size.
	while pop.size() < population_size:
		var g: AiGenome = pop.best_genome().mutate(rng, 0.5, 0.5)
		pop.add_member(g, -INF, {})
	var migrate_jobs: Array = []
	var migrate_indices: Array = []
	for i in range(pop.members.size()):
		var m: Dictionary = pop.members[i]
		if float(m.get("fitness", -INF)) > -1.0e8:
			continue
		migrate_indices.append(i)
		migrate_jobs.append(
			_make_eval_job(
				m["genome"],
				(m.get("descriptor", {}) as Dictionary).duplicate(true),
				generation_seed_offset(seed, -1),
				seed,
				pop,
				rng,
				teacher_on,
				pairs_per_eval,
				map_size,
				budget,
				use_curriculum,
				curriculum,
				true
			)
		)
	var migrate_results: Array = AiEvalParallel.run_jobs(migrate_jobs, cores)
	for j in range(migrate_indices.size()):
		var i: int = int(migrate_indices[j])
		var report: Dictionary = migrate_results[j].get("report", {})
		AiEvaluator.merge_match_stats(match_stats_total, report.get("match_stats", {}))
		AiEvaluator.append_rolling_outcomes(rolling_outcomes, report.get("match_stats", {}))
		balance_log.ingest_report(report)
		var desc: Dictionary = (report.get("descriptor", {}) as Dictionary).duplicate(true)
		var fit := AiGaPopulationScript.accumulate_eval(desc, report)
		pop.members[i]["fitness"] = fit
		pop.members[i]["descriptor"] = desc
		added += 1
		if verbose:
			print("  [migrate] evaluated padded member fit=%.3f" % float(report.get("fitness", fit)))
	pop.sort_desc()
	return added

static func _print_generation_header(
	gen_num: int,
	target_gen: int,
	pop,
	use_curriculum: bool,
	curriculum: CurriculumTrackerScript,
	teacher_on: bool,
	rolling_outcomes: Array
) -> void:
	if use_curriculum and curriculum != null:
		var stage: Dictionary = AiCurriculumScript.stage_at(curriculum.stage_index)
		print("")
		print(
			"── Gen %d/%d │ stage %s │ best %.3f median %.3f"
			% [gen_num, target_gen, AiCurriculumScript.stage_header(stage), pop.best_fitness(), pop.median_fitness()]
		)
		if not curriculum.last_promote_audit.is_empty():
			print("   last %s" % AiCurriculumScript.format_promotion_audit(curriculum.last_promote_audit))
		print("   %s" % AiCurriculumScript.promotion_progress(stage, curriculum, _champ_member_desc(pop)))
	else:
		print(
			"── Gen %d/%d │ best %.3f median %.3f │ teacher %s │ draw %.0f%%"
			% [
				gen_num,
				target_gen,
				pop.best_fitness(),
				pop.median_fitness(),
				"on" if teacher_on else "off",
				100.0 * AiEvaluator.rolling_draw_rate(rolling_outcomes),
			]
		)

static func _print_decade_summary(
	gen: int,
	pop,
	evals: int,
	teacher_on: bool,
	rolling_outcomes: Array,
	match_stats_total: Dictionary,
	last_metrics: Dictionary,
	balance_log,
	use_curriculum: bool = false,
	curriculum: CurriculumTrackerScript = null
) -> void:
	print("")
	print("========== Checkpoint @ gen %d ==========" % gen)
	if use_curriculum and curriculum != null:
		var stage: Dictionary = AiCurriculumScript.stage_at(curriculum.stage_index)
		print("Stage: %s" % AiCurriculumScript.stage_header(stage))
		if not curriculum.last_promote_audit.is_empty():
			print("  last %s" % AiCurriculumScript.format_promotion_audit(curriculum.last_promote_audit))
		print("  %s" % AiCurriculumScript.promotion_progress(stage, curriculum, _champ_member_desc(pop)))
	else:
		print(
			"Teacher: %s | rolling draw %.0f%%"
			% ["on" if teacher_on else "off", 100.0 * AiEvaluator.rolling_draw_rate(rolling_outcomes)]
		)
	print(
		"Pop best %.3f median %.3f | evals %d | arena wr %.0f%%"
		% [
			pop.best_fitness(),
			pop.median_fitness(),
			evals,
			100.0 * float(last_metrics.get("vs_cascade", 0.0)),
		]
	)
	var run_games := int(match_stats_total.get("games", 0))
	var run_draws := (
		int(match_stats_total.get("stale_draws", 0))
		+ int(match_stats_total.get("timeouts", 0))
		+ int(match_stats_total.get("other_draws", 0))
	)
	if run_games > 0:
		var draw_pct := 100.0 * float(run_draws) / float(run_games)
		var draw_flag := " ⚠ high draws" if draw_pct >= 50.0 else ""
		print(
			"Run totals: %d games, %.0f%% draws%s"
			% [run_games, draw_pct, draw_flag]
		)
	for row in pop.to_summary(3):
		print("  #%d fit=%.3f" % [int(row.get("rank", 0)), float(row.get("fitness", 0.0))])
	if not use_curriculum:
		balance_log.print_interim_balance_insights()
	print("============================================")
	print("")

static func _resolve_elite_count(population_size: int, requested: int) -> int:
	return clampi(requested, 1, maxi(1, population_size))

## Elite re-eval uses half the child pair budget (rounded down), at least 1 pair.
static func _elite_pairs_per_eval(child_pairs: int) -> int:
	return maxi(1, int(child_pairs) / 2)

## Arena measurement cadence. Curriculum runs measure too (against the current stage opponent),
## otherwise history would only ever carry stale numbers.
static func _should_run_arena(gen: int, arena_every: int, is_session_end: bool, _use_curriculum: bool = false) -> bool:
	if gen <= 0:
		return true
	if is_session_end:
		return true
	return gen % maxi(1, arena_every) == 0

static func _elite_fitness_bounds(members: Array, elite_n: int) -> Vector2:
	if elite_n <= 0 or members.is_empty():
		return Vector2(-INF, -INF)
	var worst := INF
	var best := -INF
	for i in range(mini(elite_n, members.size())):
		var f := float((members[i] as Dictionary).get("fitness", -INF))
		worst = minf(worst, f)
		best = maxf(best, f)
	if worst == INF:
		return Vector2(-INF, -INF)
	return Vector2(worst, best)

## Rank mark: !! beats best elite, + beats worst elite, · otherwise.
static func eval_rank_mark(fit: float, elite_worst: float, elite_best: float) -> String:
	if elite_best > -INF and fit > elite_best:
		return "!!"
	if elite_worst > -INF and fit > elite_worst:
		return "+"
	return "·"

static func _log_fitness_eval(
	kind: String,
	index: int,
	report: Dictionary,
	eval_ms: int,
	teacher_on: bool,
	use_curriculum: bool = false,
	display_fit: float = -INF,
	member_desc: Dictionary = {},
	elite_worst: float = -INF,
	elite_best: float = -INF
) -> void:
	var fit := display_fit if display_fit > -INF else float(report.get("fitness", 0.0))
	var wins := int(report.get("trainee_wins", 0))
	var losses := int(report.get("trainee_losses", 0))
	var draws := int(report.get("trainee_draws", 0))
	var wr := 100.0 * float(report.get("win_rate", 0.0))
	var wld_report: Dictionary = report
	var cum_total := 0
	if not member_desc.is_empty():
		cum_total = (
			int(member_desc.get("cum_wins", 0))
			+ int(member_desc.get("cum_losses", 0))
			+ int(member_desc.get("cum_draws", 0))
		)
		if cum_total > 0:
			wins = int(member_desc.get("cum_wins", 0))
			losses = int(member_desc.get("cum_losses", 0))
			draws = int(member_desc.get("cum_draws", 0))
			wr = 100.0 * AiGaPopulationScript.cumulative_win_rate(member_desc)
			wld_report = {
				"trainee_stale_draws": int(member_desc.get("cum_stale_draws", 0)),
				"trainee_timeouts": int(member_desc.get("cum_timeouts", 0)),
				"trainee_other_draws": int(member_desc.get("cum_other_draws", 0)),
				"trainee_draft_failures": int(member_desc.get("cum_draft_failures", 0)),
			}
	var mark := eval_rank_mark(fit, elite_worst, elite_best)
	var label := "%s%s%d" % [mark, kind.substr(0, 1), index]
	if not member_desc.is_empty():
		member_desc["pop_label"] = label
	var wld := _format_wld(wins, losses, draws, wld_report)
	var draw_warn := " ⚠" if draws > 0 and wins + losses == 0 else ""
	var cum_pairs := int(member_desc.get("cum_pair_count", 0))
	var cum_note := ""
	if cum_pairs > int(report.get("pair_count", 0)):
		cum_note = " cum=%d pairs" % cum_pairs
	var batch_note := ""
	var batch_total := (
		int(report.get("trainee_wins", 0))
		+ int(report.get("trainee_losses", 0))
		+ int(report.get("trainee_draws", 0))
	)
	if cum_total > batch_total and batch_total > 0:
		batch_note = " +batch %dW-%dL-%dD" % [
			int(report.get("trainee_wins", 0)),
			int(report.get("trainee_losses", 0)),
			int(report.get("trainee_draws", 0)),
		]
	var confirm_note := ""
	if bool(report.get("confirmed", false)):
		var scout_pc := int(report.get("scout_pair_count", 0))
		var total_pc := int(report.get("pair_count", 0))
		if scout_pc > 0 and total_pc > scout_pc:
			confirm_note = " [confirmed %d→%d pairs]" % [scout_pc, total_pc]
		else:
			confirm_note = " [confirmed]"
	var rehearsal_note := ""
	var rehearsal: Variant = report.get("rehearsal_stages", [])
	if typeof(rehearsal) == TYPE_PACKED_STRING_ARRAY and (rehearsal as PackedStringArray).size() > 0:
		rehearsal_note = " +rehearsal %s" % ", ".join(rehearsal)
	elif typeof(rehearsal) == TYPE_ARRAY and (rehearsal as Array).size() > 0:
		rehearsal_note = " +rehearsal %s" % ", ".join(rehearsal)
	if use_curriculum:
		print(
			"  %s fit=%.3f wr=%.0f%% (%s)%s%s%s%s%s"
			% [label, fit, wr, wld, draw_warn, cum_note, batch_note, confirm_note, rehearsal_note]
		)
	else:
		var d: Dictionary = report.get("descriptor", {})
		print(
			"  %s fit=%.3f wr=%.0f%% opp=%s agg=%.2f (%s)%s"
			% [
				label,
				fit,
				wr,
				String(report.get("opponent", "?")),
				float(d.get("aggression", 0.0)),
				wld,
				" teacher" if teacher_on and String(report.get("opponent", "")) == "cascade" else "",
			]
		)

static func _format_wld(wins: int, losses: int, draws: int, report: Dictionary) -> String:
	var base := "%dW-%dL-%dD" % [wins, losses, draws]
	if draws <= 4:
		return base
	var stale := int(report.get("trainee_stale_draws", -1))
	var timeouts := int(report.get("trainee_timeouts", -1))
	var other := int(report.get("trainee_other_draws", -1))
	var draft_fail := int(report.get("trainee_draft_failures", -1))
	if stale < 0:
		var ms: Dictionary = report.get("match_stats", {})
		stale = int(ms.get("stale_draws", 0))
		timeouts = int(ms.get("timeouts", 0))
		other = int(ms.get("other_draws", 0))
		draft_fail = int(ms.get("draft_failures", 0))
	var parts: PackedStringArray = PackedStringArray()
	if stale > 0:
		parts.append("%d stale" % stale)
	if timeouts > 0:
		parts.append("%d to" % timeouts)
	if other > 0:
		parts.append("%d other" % other)
	if draft_fail > 0:
		parts.append("%d draft_fail" % draft_fail)
	if parts.is_empty():
		return base
	return "%s; %s" % [base, ", ".join(parts)]

static func _history_metrics(metrics: Dictionary) -> Dictionary:
	var slim: Dictionary = metrics.duplicate(true)
	slim.erase("match_rows")
	slim.erase("legion_rows")
	slim.erase("best_weights")
	return slim

static func _history_row(
	metrics: Dictionary,
	pop,
	curriculum: CurriculumTrackerScript,
	use_curriculum: bool
) -> Dictionary:
	var row: Dictionary = _history_metrics(metrics)
	if bool(metrics.get("arena_skipped", false)):
		# Skipped rows carry the previous measurement forward in memory; never record it as new data.
		for stale_key in ARENA_METRIC_KEYS:
			row.erase(stale_key)
	if use_curriculum and curriculum != null:
		row["curriculum_stage"] = AiCurriculumScript.stage_at(curriculum.stage_index).get("id", "")
	var desc: Dictionary = _champ_member_desc(pop)
	if not desc.is_empty():
		row["champ_cum_wr"] = AiGaPopulationScript.cumulative_win_rate(desc)
		row["champ_cum_games"] = AiGaPopulationScript.eval_cum_games(desc)
	if pop != null and pop.size() > 0:
		row["best_weights"] = (pop.best_genome().weights as Dictionary).duplicate(true)
	return row

static func _measure_and_log(
	pop,
	arena_pairs: int,
	map_size: int,
	budget: int,
	seed_offset: int,
	arena_opponents: int,
	gen: int,
	evals: int,
	verbose: bool,
	run_arena: bool = true,
	prev_metrics: Dictionary = {},
	arena_every: int = 10,
	promote_every: int = PROMOTE_EVERY_DEFAULT,
	use_curriculum: bool = false,
	curriculum: CurriculumTrackerScript = null,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	if not run_arena:
		var skipped := prev_metrics.duplicate(true)
		skipped["gen"] = gen
		skipped["evaluations"] = evals
		skipped["archive_size"] = pop.size()
		skipped["best_fitness"] = pop.best_fitness()
		skipped["arena_skipped"] = true
		skipped["match_rows"] = []
		skipped["legion_rows"] = []
		skipped["time"] = Time.get_datetime_string_from_system()
		if use_curriculum and curriculum != null:
			skipped["curriculum_stage"] = AiCurriculumScript.stage_at(curriculum.stage_index).get("id", "")
		if verbose:
			if use_curriculum:
				var next_arena := ((gen / maxi(1, arena_every)) + 1) * arena_every
				if next_arena <= gen:
					next_arena = gen + arena_every
				var next_promote := ((gen / maxi(1, promote_every)) + 1) * promote_every
				if next_promote <= gen:
					next_promote = gen + promote_every
				print(
					"  [arena] skipped | promote-check @ gen %d | arena @ gen %d | best fit %.3f"
					% [next_promote, next_arena, float(skipped["best_fitness"])]
				)
			else:
				print(
					"  [arena] skipped (every %d gens) | best fit %.3f | pop %d"
					% [arena_every, float(skipped["best_fitness"]), int(skipped["archive_size"])]
				)
		return skipped

	var champ: AiGenome = pop.best_genome()
	var opps: Array = []
	pop.sort_desc()
	for i in range(1, mini(pop.size(), arena_opponents + 1)):
		opps.append((pop.members[i]["genome"] as AiGenome).duplicate_genome())
	var t0 := Time.get_ticks_msec()
	var arena: Dictionary = AiArena.evaluate_champion(
		champ,
		opps,
		arena_pairs,
		map_size,
		budget,
		seed_offset,
		pop.best_fitness(),
		pop.size(),
		curriculum if use_curriculum else null,
		rng
	)
	var elapsed := Time.get_ticks_msec() - t0
	var arena_stats: Dictionary = arena.get("match_stats", AiEvaluator.empty_match_stats())
	var metrics := {
		"gen": gen,
		"evaluations": evals,
		"archive_size": pop.size(),
		"best_fitness": pop.best_fitness(),
		"vs_cascade": float(arena.get("vs_cascade", 0.0)),
		"vs_cascade_fitness": float(arena.get("vs_cascade_fitness", 0.0)),
		"vs_arena": float(arena.get("vs_arena", 0.0)),
		"vs_arena_fitness": float(arena.get("vs_arena_fitness", 0.0)),
		"opponents": int(arena.get("opponents", 0)),
		"arena_ms": elapsed,
		"arena_skipped": false,
		"match_stats": arena_stats,
		"match_rows": arena.get("match_rows", []),
		"legion_rows": arena.get("legion_rows", []),
		"time": Time.get_datetime_string_from_system(),
	}
	if use_curriculum and curriculum != null:
		metrics["curriculum_stage"] = AiCurriculumScript.stage_at(curriculum.stage_index).get("id", "")
	if verbose:
		if use_curriculum and curriculum != null:
			var stage: Dictionary = AiCurriculumScript.stage_at(curriculum.stage_index)
			var arena_wr := 100.0 * float(metrics["vs_cascade"])
			print(
				"  [arena] champ wr %.0f%% vs %s | fit %.3f | %dms"
				% [arena_wr, String(stage.get("id", "?")), float(metrics["best_fitness"]), elapsed]
			)
			print("          %s" % AiCurriculumScript.promotion_progress(stage, curriculum, _champ_member_desc(pop)))
		else:
			print(
				"  [arena] vs cascade %.0f%% | vs pop fit %.3f | best %.3f | %dms"
				% [
					100.0 * float(metrics["vs_cascade"]),
					float(metrics["vs_arena_fitness"]),
					float(metrics["best_fitness"]),
					elapsed,
				]
			)
			print("          %s" % AiEvaluator.format_match_stats(arena_stats))
	return metrics

static func _save_state(
	run_dir: String,
	pop,
	generations_completed: int,
	evals: int,
	rng: RandomNumberGenerator,
	config: Dictionary,
	last_metrics: Dictionary,
	target_gen: int,
	match_stats: Dictionary = {},
	rolling_outcomes: Array = [],
	teacher_on: bool = true,
	curriculum: CurriculumTrackerScript = null
) -> void:
	var best: AiGenome = pop.best_genome()
	var state := {
		"version": 4,
		"algo": "ga",
		"config": config,
		"generations_completed": generations_completed,
		"target_gen": target_gen,
		"evaluations": evals,
		"rng_state": rng.state,
		"population": pop.to_dict(),
		"population_size": pop.size(),
		"archive_size": pop.size(),
		"best_fitness": pop.best_fitness(),
		"best_weights": best.weights.duplicate(true),
		"last_metrics": last_metrics,
		"match_stats": match_stats,
		"rolling_outcomes": rolling_outcomes,
		"teacher_on": teacher_on,
	}
	if curriculum != null:
		state["curriculum"] = curriculum.to_dict()
	AiArchiveStore.save_checkpoint(run_dir, state)

static func _load_state(run_dir: String, population_size: int, rng: RandomNumberGenerator) -> Dictionary:
	var state := AiArchiveStore.load_checkpoint(run_dir)
	var pop = AiGaPopulationScript.new()
	if state.has("population"):
		pop = AiGaPopulationScript.from_dict(state.get("population", {}))
	elif state.has("archive"):
		# Migrate old MAP-Elites checkpoint → GA population.
		print("[evolve] migrating MAP archive → GA population")
		pop = AiGaPopulationScript.from_map_archive_dict(
			state.get("archive", {}), population_size, rng
		)
	return {
		"population": pop,
		"generations_completed": int(state.get("generations_completed", 0)),
		"evaluations": int(state.get("evaluations", 0)),
		"rng_state": int(state.get("rng_state", 0)),
		"config": state.get("config", {}),
		"last_metrics": state.get("last_metrics", {}),
		"match_stats": state.get("match_stats", {}),
		"rolling_outcomes": state.get("rolling_outcomes", []),
		"teacher_on": bool(state.get("teacher_on", true)),
		"curriculum": state.get("curriculum", {}),
	}
