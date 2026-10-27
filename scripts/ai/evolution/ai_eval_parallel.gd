class_name AiEvalParallel
extends RefCounted

## Run independent fitness eval jobs on WorkerThreadPool (headless duels only).

const AiCurriculumScript = preload("res://scripts/ai/curriculum/ai_curriculum.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CurriculumTrackerScript = preload("res://scripts/ai/curriculum/curriculum_tracker.gd")

## jobs: Array[Dictionary] from AiEvolveRunner._make_eval_job
static func run_jobs(jobs: Array, cores: int) -> Array:
	if jobs.is_empty():
		return []
	if cores <= 1 or jobs.size() <= 1:
		var sequential: Array = []
		for job in jobs:
			sequential.append(_run_job(job))
		return sequential
	var results: Array = []
	results.resize(jobs.size())
	var task_id := WorkerThreadPool.add_group_task(
		func(task_index: int) -> void:
			results[task_index] = _run_job(jobs[task_index]),
		jobs.size(),
		cores,
		true
	)
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	return results

static func _run_job(job: Dictionary) -> Dictionary:
	CombatExpectation.use_train_mode()
	CombatResolver.quiet = true
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
