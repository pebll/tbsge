class_name AiEvalParallel
extends RefCounted

## Run independent fitness eval jobs on WorkerThreadPool (headless duels only).

const AiCurriculumScript = preload("res://scripts/ai/curriculum/ai_curriculum.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
const CurriculumTrackerScript = preload("res://scripts/ai/curriculum/curriculum_tracker.gd")

## jobs: Array[Dictionary] from AiEvolveRunner._make_eval_job
static func run_jobs(jobs: Array, cores: int) -> Array:
	if jobs.is_empty():
		return []
	# Process-wide log flags are written once here on the calling (main) thread, never by jobs.
	var headless: Dictionary = AiDuelRunner.begin_headless()
	var results: Array = []
	results.resize(jobs.size())
	if cores <= 1 or jobs.size() <= 1:
		for i in range(jobs.size()):
			results[i] = _run_job(jobs[i])
	else:
		var task_id := WorkerThreadPool.add_group_task(
			func(task_index: int) -> void:
				results[task_index] = _run_job(jobs[task_index]),
			jobs.size(),
			cores,
			true
		)
		WorkerThreadPool.wait_for_group_task_completion(task_id)
	AiDuelRunner.end_headless(headless)
	for i in range(results.size()):
		results[i] = result_or_error(results[i], i)
	return results

## A worker that died before storing its result leaves null; callers always .get on results, so
## hand them an empty report plus an error they can surface instead.
static func result_or_error(result, job_index: int = -1) -> Dictionary:
	if result is Dictionary and (result as Dictionary).get("report") is Dictionary:
		return result
	var message := "eval job %d returned no result (worker error)" % job_index
	push_error(message)
	return {
		"report": {
			"error": message,
			"pair_count": 0,
			"pair_points": 0.0,
			"match_stats": AiEvaluator.empty_match_stats(),
		},
		"eval_ms": 0,
		"error": message,
	}

static func _run_job(job: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(job.get("rng_seed", 1))
	var t0 := Time.get_ticks_msec()
	var genome = job.get("genome")
	if genome == null:
		genome = AiGenomeScript.from_hand_v1()
	var report: Dictionary
	if bool(job.get("use_curriculum", false)):
		var tracker = CurriculumTrackerScript.from_dict(job.get("curriculum", {}))
		var rehearsal_idx := int(job.get("rehearsal_stage_index", -1))
		if rehearsal_idx >= 0:
			report = AiEvaluator.evaluate_for_curriculum_rehearsal_substitute(
				genome,
				tracker,
				rehearsal_idx,
				rng,
				int(job.get("pairs", 2)),
				int(job.get("map_size", 3)),
				int(job.get("budget", 75)),
				int(job.get("seed_offset", 0))
			)
		else:
			report = AiEvaluator.evaluate_for_curriculum_with_confirm(
				genome,
				tracker,
				rng,
				null,
				int(job.get("pairs", 2)),
				int(job.get("map_size", 3)),
				int(job.get("budget", 75)),
				int(job.get("seed_offset", 0)),
				float(job.get("confirm_min_fitness", NAN)),
				bool(job.get("collect_probe", false))
			)
	else:
		report = AiEvaluator.evaluate_for_evolve_with_confirm(
			genome,
			null,
			rng,
			bool(job.get("teacher_on", true)),
			int(job.get("pairs", 2)),
			int(job.get("map_size", 3)),
			int(job.get("budget", 75)),
			int(job.get("seed_offset", 0)),
			float(job.get("confirm_min_fitness", NAN)),
			job.get("forced_opponent", null)
		)
	return {
		"report": report,
		"eval_ms": Time.get_ticks_msec() - t0,
	}
