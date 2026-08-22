class_name AiEvaluator
extends RefCounted

## Fitness = mirrored rich match scores vs opponent (argmax utility). EA uses train MC N.

const AiBehaviorProbeScript = preload("res://scripts/ai/evolution/ai_behavior_probe.gd")
const AiCurriculumScript = preload("res://scripts/ai/curriculum/ai_curriculum.gd")
const AiGaPopulationScript = preload("res://scripts/ai/evolution/ai_ga_population.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
const AiMatchScore = preload("res://scripts/ai/evolution/ai_match_score.gd")
const CascadeBrainScript = preload("res://scripts/ai/brains/cascade_brain.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const CurriculumScoreScript = preload("res://scripts/ai/curriculum/curriculum_score.gd")
const CurriculumTrackerScript = preload("res://scripts/ai/curriculum/curriculum_tracker.gd")
const DraftScenarioScript = preload("res://scripts/ai/curriculum/draft_scenario.gd")
const UtilityBrainScript = preload("res://scripts/ai/brains/utility_brain.gd")

## Cascade teacher with hysteresis on a rolling draw-rate window.
## Turn teacher ON when draws are elevated; only turn OFF after draws stay low.
const TEACHER_ON_AT := 0.25
const TEACHER_OFF_AT := 0.15
## Need at least this many rolling samples before teacher can turn off.
const TEACHER_MIN_GAMES := 24
const ROLLING_WINDOW := 48
## After teacher phase: fraction of evals vs archive elites (rest stay cascade).
const POST_TEACHER_ELITE_FRAC := 0.35
## If a scout eval would beat its MAP cell, re-score with this many pairs.
const CONFIRM_PAIRS := 4

static func evaluate_genome(
	genome: AiGenome,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	return evaluate_vs_cascade(genome, pair_count, map_size, budget, seed_offset)

## Fitness eval with cascade teacher curriculum.
## When teacher_on: always cascade. When off: mostly cascade, some pop opponents.
static func evaluate_for_evolve(
	genome: AiGenome,
	population,
	rng: RandomNumberGenerator,
	teacher_on: bool,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	if teacher_on or population == null or population.size() < 2:
		var report: Dictionary = evaluate_vs_cascade(
			genome, pair_count, map_size, budget, seed_offset
		)
		report["opponent"] = "cascade"
		report["teacher"] = true
		return report
	if rng.randf() < POST_TEACHER_ELITE_FRAC:
		var opp: AiGenome = population.random_genome(rng, true)
		var vs: Dictionary = evaluate_vs_genome(
			genome, opp, pair_count, map_size, budget, seed_offset, true
		)
		vs["opponent"] = "pop"
		vs["teacher"] = false
		return vs
	var vs_c: Dictionary = evaluate_vs_cascade(genome, pair_count, map_size, budget, seed_offset)
	vs_c["opponent"] = "cascade"
	vs_c["teacher"] = false
	return vs_c

## Scout with `pair_count`, then confirm near-best genomes with CONFIRM_PAIRS.
static func evaluate_for_evolve_with_confirm(
	genome: AiGenome,
	population,
	rng: RandomNumberGenerator,
	teacher_on: bool,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	var scout: Dictionary = evaluate_for_evolve(
		genome, population, rng, teacher_on, pair_count, map_size, budget, seed_offset
	)
	scout["confirmed"] = false
	if population == null:
		return scout
	var fit := float(scout.get("fitness", -INF))
	if not population.would_confirm(fit):
		return scout
	var confirm_pairs := maxi(CONFIRM_PAIRS, pair_count)
	if confirm_pairs <= pair_count:
		scout["confirmed"] = true
		return scout
	var confirm: Dictionary = evaluate_for_evolve(
		genome,
		population,
		rng,
		teacher_on,
		confirm_pairs,
		map_size,
		budget,
		seed_offset + 7771
	)
	return merge_scout_confirm_reports(scout, confirm)

## Curriculum fitness: current stage + rehearsal pairs on failed retention stages.
static func evaluate_for_curriculum(
	genome: AiGenome,
	tracker: CurriculumTrackerScript,
	rng: RandomNumberGenerator,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0,
	collect_probe: bool = false
) -> Dictionary:
	var failed: Array[int] = tracker.rehearsal_stages_worst_first() if tracker != null else []
	if failed.is_empty() or pair_count <= 1:
		var single: Dictionary = evaluate_for_curriculum_stage(
			genome,
			tracker,
			tracker.stage_index,
			rng,
			pair_count,
			map_size,
			budget,
			seed_offset,
			collect_probe
		)
		return _tag_promotion_outcomes(single)
	var rehearsal_n := mini(failed.size(), pair_count - 1)
	var current_pairs := pair_count - rehearsal_n
	var reports: Array = []
	var current: Dictionary = evaluate_for_curriculum_stage(
		genome,
		tracker,
		tracker.stage_index,
		rng,
		current_pairs,
		map_size,
		budget,
		seed_offset,
		collect_probe
	)
	reports.append(current)
	for i in range(rehearsal_n):
		var stage_idx: int = failed[i]
		var rep: Dictionary = evaluate_for_curriculum_stage(
			genome,
			tracker,
			stage_idx,
			rng,
			1,
			map_size,
			budget,
			seed_offset + 12000 + stage_idx * 41 + i * 7,
			false
		)
		reports.append(rep)
	return merge_curriculum_eval_reports(reports, tracker.stage_index)

static func evaluate_for_curriculum_stage(
	genome: AiGenome,
	tracker: CurriculumTrackerScript,
	stage_index: int,
	rng: RandomNumberGenerator,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0,
	collect_probe: bool = false
) -> Dictionary:
	var stage: Dictionary = AiCurriculumScript.stage_at(stage_index)
	var opponent: AiBrain = AiCurriculumScript.create_opponent(stage, tracker, rng)
	var draft: DraftScenarioScript = AiCurriculumScript.draft_for_stage(stage)
	var use_simple := bool(stage.get("simple_fitness", false))
	var stale_idle := AiCurriculumScript.stale_idle_turns_for_stage(stage)
	return _evaluate_vs_brain(
		genome,
		opponent,
		pair_count,
		map_size,
		budget,
		seed_offset,
		collect_probe,
		draft,
		use_simple,
		String(stage.get("id", "")),
		String(stage.get("opponent", "")),
		draft.mode_id(),
		stale_idle
	)

## Pairs needed so trainee duel outcomes reach `min_games` (each pair = 2 outcomes).
static func audit_pairs_for_min_games(min_games: int) -> int:
	return maxi(1, (maxi(1, min_games) + 1) / 2)

static func trainee_outcome_win_rate(report: Dictionary) -> float:
	var wins := int(report.get("trainee_wins", 0))
	var losses := int(report.get("trainee_losses", 0))
	var draws := int(report.get("trainee_draws", 0))
	var games := wins + losses + draws
	if games <= 0:
		return 0.0
	return (float(wins) + 0.5 * float(draws)) / float(games)

static func trainee_outcome_count(report: Dictionary) -> int:
	return (
		int(report.get("trainee_wins", 0))
		+ int(report.get("trainee_losses", 0))
		+ int(report.get("trainee_draws", 0))
	)

static func audit_meets_win_rate(report: Dictionary, need_wr: float, min_games: int) -> bool:
	if trainee_outcome_count(report) < min_games:
		return false
	return trainee_outcome_win_rate(report) >= need_wr

static func _tag_promotion_outcomes(report: Dictionary) -> Dictionary:
	var out: Dictionary = report.duplicate(true)
	out["promotion_trainee_wins"] = int(report.get("trainee_wins", 0))
	out["promotion_trainee_losses"] = int(report.get("trainee_losses", 0))
	out["promotion_trainee_draws"] = int(report.get("trainee_draws", 0))
	out["promotion_trainee_stale_draws"] = int(report.get("trainee_stale_draws", 0))
	out["promotion_trainee_timeouts"] = int(report.get("trainee_timeouts", 0))
	out["promotion_trainee_other_draws"] = int(report.get("trainee_other_draws", 0))
	out["promotion_trainee_draft_failures"] = int(report.get("trainee_draft_failures", 0))
	return out

## Merge stage eval batches; promotion cum counts only the current-stage report.
static func merge_curriculum_eval_reports(reports: Array, current_stage_index: int) -> Dictionary:
	if reports.is_empty():
		return {}
	if reports.size() == 1:
		return _tag_promotion_outcomes(reports[0] as Dictionary)
	var merged: Dictionary = {}
	var pair_points := 0.0
	var pair_count := 0
	var outcome_sum := 0.0
	var trainee_wins := 0
	var trainee_losses := 0
	var trainee_draws := 0
	var promo_w := 0
	var promo_l := 0
	var promo_d := 0
	var promo_stale := 0
	var promo_to := 0
	var promo_other := 0
	var promo_draft := 0
	var rehearsal_ids: PackedStringArray = PackedStringArray()
	var match_stats := empty_match_stats()
	var match_rows: Array = []
	var legion_rows: Array = []
	var current_stage_id := ""
	for rep in reports:
		if typeof(rep) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = rep
		var pc := int(r.get("pair_count", 0))
		pair_points += float(r.get("pair_points", 0.0))
		pair_count += pc
		outcome_sum += float(r.get("win_rate", 0.0)) * float(maxi(pc * 2, 1))
		trainee_wins += int(r.get("trainee_wins", 0))
		trainee_losses += int(r.get("trainee_losses", 0))
		trainee_draws += int(r.get("trainee_draws", 0))
		merge_match_stats(match_stats, r.get("match_stats", {}))
		match_rows.append_array(r.get("match_rows", []))
		legion_rows.append_array(r.get("legion_rows", []))
		var sid := String(r.get("curriculum_stage", ""))
		if sid.is_empty():
			continue
		var stage_idx := AiCurriculumScript.find_stage_index(sid)
		if stage_idx == current_stage_index:
			current_stage_id = sid
			promo_w += int(r.get("trainee_wins", 0))
			promo_l += int(r.get("trainee_losses", 0))
			promo_d += int(r.get("trainee_draws", 0))
			promo_stale += int(r.get("trainee_stale_draws", 0))
			promo_to += int(r.get("trainee_timeouts", 0))
			promo_other += int(r.get("trainee_other_draws", 0))
			promo_draft += int(r.get("trainee_draft_failures", 0))
		else:
			rehearsal_ids.append(sid)
	var fitness := pair_points / float(maxi(pair_count, 1))
	var win_rate := outcome_sum / float(maxi(pair_count * 2, 1))
	merged = (reports[0] as Dictionary).duplicate(true)
	merged["fitness"] = fitness
	merged["pair_points"] = pair_points
	merged["pair_count"] = pair_count
	merged["win_rate"] = win_rate
	merged["trainee_wins"] = trainee_wins
	merged["trainee_losses"] = trainee_losses
	merged["trainee_draws"] = trainee_draws
	merged["promotion_trainee_wins"] = promo_w
	merged["promotion_trainee_losses"] = promo_l
	merged["promotion_trainee_draws"] = promo_d
	merged["promotion_trainee_stale_draws"] = promo_stale
	merged["promotion_trainee_timeouts"] = promo_to
	merged["promotion_trainee_other_draws"] = promo_other
	merged["promotion_trainee_draft_failures"] = promo_draft
	merged["curriculum_stage"] = current_stage_id
	merged["rehearsal_stages"] = rehearsal_ids
	merged["match_stats"] = match_stats
	merged["match_rows"] = match_rows
	merged["legion_rows"] = legion_rows
	return merged

## Prior curriculum stages replayed with each stage's promote_min_games per confirm / promote audit.
static func evaluate_curriculum_retention(
	genome: AiGenome,
	tracker: CurriculumTrackerScript,
	rng: RandomNumberGenerator,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	var stage_results: Array = []
	var all_pass := true
	for i in range(tracker.stage_index):
		var prior_stage: Dictionary = AiCurriculumScript.stage_at(i)
		var need_wr := AiCurriculumScript.retain_win_rate(prior_stage)
		var min_games := int(prior_stage.get("promote_min_games", 12))
		var audit_pairs := audit_pairs_for_min_games(min_games)
		var report: Dictionary = evaluate_for_curriculum_stage(
			genome,
			tracker,
			i,
			rng,
			audit_pairs,
			map_size,
			budget,
			seed_offset + 9000 + i * 31,
			false
		)
		var wr := trainee_outcome_win_rate(report)
		var games := trainee_outcome_count(report)
		var passed := audit_meets_win_rate(report, need_wr, min_games)
		all_pass = all_pass and passed
		stage_results.append({
			"stage_index": i,
			"stage_id": String(prior_stage.get("id", "")),
			"need_win_rate": need_wr,
			"need_games": min_games,
			"audit_games": games,
			"win_rate": wr,
			"passed": passed,
			"trainee_wins": int(report.get("trainee_wins", 0)),
			"trainee_losses": int(report.get("trainee_losses", 0)),
			"trainee_draws": int(report.get("trainee_draws", 0)),
			"report": report,
		})
	return {
		"passed": all_pass,
		"stages": stage_results,
	}

## Promotion gate: current stage from scout/confirm cum stats; retention = fresh audits on prior stages.
static func evaluate_curriculum_promotion_audit(
	genome: AiGenome,
	tracker: CurriculumTrackerScript,
	member_desc: Dictionary,
	rng: RandomNumberGenerator,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	var stage: Dictionary = AiCurriculumScript.stage_at(tracker.stage_index)
	var min_games := int(stage.get("promote_min_games", 12))
	var need_wr := float(stage.get("promote_win_rate", 0.85))
	var wins := int(member_desc.get("cum_wins", 0))
	var losses := int(member_desc.get("cum_losses", 0))
	var draws := int(member_desc.get("cum_draws", 0))
	var cum_games := wins + losses + draws
	var cum_wr := AiGaPopulationScript.cumulative_win_rate(member_desc)
	var current_pass := AiGaPopulationScript.eval_meets_promotion(member_desc, stage)
	var retention: Dictionary = evaluate_curriculum_retention(
		genome, tracker, rng, map_size, budget, seed_offset + 44000
	)
	var retain_pass := bool(retention.get("passed", true))
	return {
		"promotion_passed": current_pass and retain_pass,
		"current_passed": current_pass,
		"retention_passed": retain_pass,
		"from_eval_cum": true,
		"stage_id": String(stage.get("id", "")),
		"need_win_rate": need_wr,
		"need_games": min_games,
		"audit_games": cum_games,
		"audit_win_rate": cum_wr,
		"trainee_wins": wins,
		"trainee_losses": losses,
		"trainee_draws": draws,
		"retention": retention,
	}

static func evaluate_for_curriculum_with_confirm(
	genome: AiGenome,
	tracker: CurriculumTrackerScript,
	rng: RandomNumberGenerator,
	population,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	var scout: Dictionary = evaluate_for_curriculum(
		genome, tracker, rng, pair_count, map_size, budget, seed_offset, population != null
	)
	scout["confirmed"] = false
	if population == null:
		return scout
	var fit := float(scout.get("fitness", -INF))
	if not population.would_confirm(fit):
		return scout
	var confirm_pairs := maxi(CONFIRM_PAIRS, pair_count)
	if confirm_pairs <= pair_count:
		scout["confirmed"] = true
		return scout
	var confirm: Dictionary = evaluate_for_curriculum(
		genome, tracker, rng, confirm_pairs, map_size, budget, seed_offset + 7771, true
	)
	var merged: Dictionary = merge_scout_confirm_reports(scout, confirm)
	return merged

## Merge scout + confirm eval batches into one report (W/L/D, WR, fitness, stats).
static func merge_scout_confirm_reports(scout: Dictionary, confirm: Dictionary) -> Dictionary:
	var scout_pc := int(scout.get("pair_count", 0))
	var confirm_pc := int(confirm.get("pair_count", 0))
	var total_pc := scout_pc + confirm_pc
	var scout_pp := float(scout.get("pair_points", 0.0))
	var confirm_pp := float(confirm.get("pair_points", 0.0))
	var scout_fit := float(scout.get("fitness", 0.0))
	var confirm_fit := float(confirm.get("fitness", 0.0))

	var wins := int(scout.get("trainee_wins", 0)) + int(confirm.get("trainee_wins", 0))
	var losses := int(scout.get("trainee_losses", 0)) + int(confirm.get("trainee_losses", 0))
	var draws := int(scout.get("trainee_draws", 0)) + int(confirm.get("trainee_draws", 0))
	var total_outcomes := wins + losses + draws
	var win_rate := (float(wins) + 0.5 * float(draws)) / float(maxi(total_outcomes, 1))

	var merged: Dictionary = confirm.duplicate(true)
	merged["pair_count"] = total_pc
	merged["pair_points"] = scout_pp + confirm_pp
	if total_pc > 0:
		merged["fitness"] = (scout_fit * float(scout_pc) + confirm_fit * float(confirm_pc)) / float(total_pc)
	merged["trainee_wins"] = wins
	merged["trainee_losses"] = losses
	merged["trainee_draws"] = draws
	merged["win_rate"] = win_rate
	merged["trainee_stale_draws"] = (
		int(scout.get("trainee_stale_draws", 0)) + int(confirm.get("trainee_stale_draws", 0))
	)
	merged["trainee_timeouts"] = (
		int(scout.get("trainee_timeouts", 0)) + int(confirm.get("trainee_timeouts", 0))
	)
	merged["trainee_other_draws"] = (
		int(scout.get("trainee_other_draws", 0)) + int(confirm.get("trainee_other_draws", 0))
	)
	merged["trainee_draft_failures"] = (
		int(scout.get("trainee_draft_failures", 0)) + int(confirm.get("trainee_draft_failures", 0))
	)
	merged["promotion_trainee_wins"] = (
		int(scout.get("promotion_trainee_wins", scout.get("trainee_wins", 0)))
		+ int(confirm.get("promotion_trainee_wins", confirm.get("trainee_wins", 0)))
	)
	merged["promotion_trainee_losses"] = (
		int(scout.get("promotion_trainee_losses", scout.get("trainee_losses", 0)))
		+ int(confirm.get("promotion_trainee_losses", confirm.get("trainee_losses", 0)))
	)
	merged["promotion_trainee_draws"] = (
		int(scout.get("promotion_trainee_draws", scout.get("trainee_draws", 0)))
		+ int(confirm.get("promotion_trainee_draws", confirm.get("trainee_draws", 0)))
	)
	merged["promotion_trainee_stale_draws"] = (
		int(scout.get("promotion_trainee_stale_draws", scout.get("trainee_stale_draws", 0)))
		+ int(confirm.get("promotion_trainee_stale_draws", confirm.get("trainee_stale_draws", 0)))
	)
	merged["promotion_trainee_timeouts"] = (
		int(scout.get("promotion_trainee_timeouts", scout.get("trainee_timeouts", 0)))
		+ int(confirm.get("promotion_trainee_timeouts", confirm.get("trainee_timeouts", 0)))
	)
	merged["promotion_trainee_other_draws"] = (
		int(scout.get("promotion_trainee_other_draws", scout.get("trainee_other_draws", 0)))
		+ int(confirm.get("promotion_trainee_other_draws", confirm.get("trainee_other_draws", 0)))
	)
	merged["promotion_trainee_draft_failures"] = (
		int(scout.get("promotion_trainee_draft_failures", scout.get("trainee_draft_failures", 0)))
		+ int(confirm.get("promotion_trainee_draft_failures", confirm.get("trainee_draft_failures", 0)))
	)
	var rehearsal: PackedStringArray = PackedStringArray()
	for sid in scout.get("rehearsal_stages", []):
		rehearsal.append(String(sid))
	for sid in confirm.get("rehearsal_stages", []):
		var s := String(sid)
		if not rehearsal.has(s):
			rehearsal.append(s)
	if rehearsal.size() > 0:
		merged["rehearsal_stages"] = rehearsal

	var rows: Array = []
	rows.append_array(scout.get("match_rows", []))
	rows.append_array(confirm.get("match_rows", []))
	var legs: Array = []
	legs.append_array(scout.get("legion_rows", []))
	legs.append_array(confirm.get("legion_rows", []))
	var merged_stats: Dictionary = empty_match_stats()
	merge_match_stats(merged_stats, scout.get("match_stats", {}))
	merge_match_stats(merged_stats, confirm.get("match_stats", {}))
	merged["match_rows"] = rows
	merged["legion_rows"] = legs
	merged["match_stats"] = merged_stats
	merged["confirmed"] = true
	merged["scout_fitness"] = scout_fit
	merged["scout_pair_count"] = scout_pc
	return merged

## Append per-batch outcomes into a rolling 0/1 draw flag buffer (mutates `rolling`).
static func append_rolling_outcomes(rolling: Array, stats: Dictionary) -> void:
	if stats.is_empty():
		return
	var games := int(stats.get("games", 0))
	var draws := (
		int(stats.get("stale_draws", 0))
		+ int(stats.get("timeouts", 0))
		+ int(stats.get("other_draws", 0))
	)
	var decided := maxi(0, games - draws)
	for _i in range(maxi(0, draws)):
		rolling.append(1)
	for _i in range(decided):
		rolling.append(0)
	while rolling.size() > ROLLING_WINDOW:
		rolling.pop_front()

static func rolling_draw_rate(rolling: Array) -> float:
	if rolling.is_empty():
		return 1.0
	var draw_n := 0
	for v in rolling:
		draw_n += int(v)
	return float(draw_n) / float(rolling.size())

## Hysteresis: ON when rolling draw-rate high, OFF only after it stays low.
static func next_teacher_state(teacher_on: bool, rolling: Array) -> bool:
	if rolling.size() < TEACHER_MIN_GAMES:
		return true
	var rate := rolling_draw_rate(rolling)
	if teacher_on:
		return rate > TEACHER_OFF_AT
	return rate >= TEACHER_ON_AT

static func draw_rate(stats: Dictionary) -> float:
	var games := int(stats.get("games", 0))
	if games <= 0:
		return 1.0
	var draws := (
		int(stats.get("stale_draws", 0))
		+ int(stats.get("timeouts", 0))
		+ int(stats.get("other_draws", 0))
	)
	return float(draws) / float(games)

static func evaluate_vs_cascade(
	genome: AiGenome,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0
) -> Dictionary:
	var cascade: AiBrain = CascadeBrainScript.new()
	return _evaluate_vs_brain(
		genome, cascade, pair_count, map_size, budget, seed_offset, true, null, false, "", "cascade", "random"
	)

static func evaluate_vs_genome(
	genome: AiGenome,
	opponent: AiGenome,
	pair_count: int = 2,
	map_size: int = 3,
	budget: int = 75,
	seed_offset: int = 0,
	collect_probe: bool = false
) -> Dictionary:
	var opp_brain: UtilityBrain = UtilityBrainScript.new(opponent.to_profile("opp"))
	opp_brain.force_argmax = true
	return _evaluate_vs_brain(
		genome,
		opp_brain,
		pair_count,
		map_size,
		budget,
		seed_offset,
		collect_probe,
		null,
		false,
		"",
		"pop",
		"random"
	)

static func _evaluate_vs_brain(
	genome: AiGenome,
	opponent: AiBrain,
	pair_count: int,
	map_size: int,
	budget: int,
	seed_offset: int,
	collect_probe: bool,
	draft_scenario: DraftScenarioScript = null,
	use_simple_fitness: bool = false,
	curriculum_stage_id: String = "",
	opponent_label: String = "",
	draft_mode_id: String = "random",
	stale_idle_turns: int = 0
) -> Dictionary:
	CombatExpectation.use_train_mode()
	var prev_quiet := CombatResolver.quiet
	CombatResolver.quiet = true
	var probe = null
	if collect_probe:
		probe = AiBehaviorProbeScript.new()
	var utility: UtilityBrain = UtilityBrainScript.new(genome.to_profile("eval"))
	utility.force_argmax = true
	utility.probe = probe
	utility.debug_enabled = false

	var pair_points := 0.0
	var rich_points := 0.0
	var outcome_sum := 0.0
	var trainee_wins := 0
	var trainee_losses := 0
	var trainee_draws := 0
	var trainee_stale_draws := 0
	var trainee_timeouts := 0
	var trainee_other_draws := 0
	var trainee_draft_failures := 0
	var draw_kinds := {
		"stale": 0,
		"timeouts": 0,
		"other": 0,
		"draft_fail": 0,
	}
	var match_stats := empty_match_stats()
	var match_rows: Array = []
	var legion_rows: Array = []
	var local_game := 0
	for i in range(pair_count):
		var game_index := seed_offset * 1000 + i
		var r1: Dictionary = AiDuelRunner.run_one(
			game_index, map_size, budget, utility, opponent, draft_scenario, stale_idle_turns
		)
		var r2: Dictionary = AiDuelRunner.run_one(
			game_index, map_size, budget, opponent, utility, draft_scenario, stale_idle_turns
		)
		pair_points += CurriculumScoreScript.score_for_side(r1, true, use_simple_fitness)
		pair_points += CurriculumScoreScript.score_for_side(r2, false, use_simple_fitness)
		rich_points += AiMatchScore.score_for_side(r1, true)
		rich_points += AiMatchScore.score_for_side(r2, false)
		outcome_sum += AiMatchScore.outcome_rate(r1, true)
		outcome_sum += AiMatchScore.outcome_rate(r2, false)
		var o1: Dictionary = _trainee_outcome(r1, true)
		trainee_wins += int(o1.get("wins", 0))
		trainee_losses += int(o1.get("losses", 0))
		trainee_draws += int(o1.get("draws", 0))
		_apply_trainee_draw_kind(r1, int(o1.get("draws", 0)), draw_kinds)
		var o2: Dictionary = _trainee_outcome(r2, false)
		trainee_wins += int(o2.get("wins", 0))
		trainee_losses += int(o2.get("losses", 0))
		trainee_draws += int(o2.get("draws", 0))
		_apply_trainee_draw_kind(r2, int(o2.get("draws", 0)), draw_kinds)
		accumulate_match_result(match_stats, r1)
		accumulate_match_result(match_stats, r2)
		local_game = _absorb_duel_result(
			match_rows, legion_rows, r1, local_game, utility.id, opponent.id,
			curriculum_stage_id, draft_mode_id
		)
		local_game = _absorb_duel_result(
			match_rows, legion_rows, r2, local_game, opponent.id, utility.id,
			curriculum_stage_id, draft_mode_id
		)

	trainee_stale_draws = int(draw_kinds.get("stale", 0))
	trainee_timeouts = int(draw_kinds.get("timeouts", 0))
	trainee_other_draws = int(draw_kinds.get("other", 0))
	trainee_draft_failures = int(draw_kinds.get("draft_fail", 0))

	var fitness := pair_points / float(maxi(pair_count, 1))
	if not use_simple_fitness:
		fitness = rich_points / float(maxi(pair_count, 1))
	var win_rate := outcome_sum / float(maxi(pair_count * 2, 1))
	var descriptor := {}
	if probe != null:
		descriptor = probe.descriptor()
	CombatResolver.quiet = prev_quiet
	CombatExpectation.use_play_mode()
	var opp_name := opponent_label if not opponent_label.is_empty() else opponent.id
	return {
		"fitness": fitness,
		"descriptor": descriptor,
		"pair_points": pair_points,
		"pair_count": pair_count,
		"win_rate": win_rate,
		"match_stats": match_stats,
		"match_rows": match_rows,
		"legion_rows": legion_rows,
		"opponent": opp_name,
		"curriculum_stage": curriculum_stage_id,
		"draft_mode": draft_mode_id,
		"trainee_wins": trainee_wins,
		"trainee_losses": trainee_losses,
		"trainee_draws": trainee_draws,
		"trainee_stale_draws": trainee_stale_draws,
		"trainee_timeouts": trainee_timeouts,
		"trainee_other_draws": trainee_other_draws,
		"trainee_draft_failures": trainee_draft_failures,
		"simple_fitness": use_simple_fitness,
	}

static func _apply_trainee_draw_kind(
	result: Dictionary,
	trainee_draws_this_game: int,
	draw_kinds: Dictionary
) -> void:
	if trainee_draws_this_game <= 0:
		return
	if bool(result.get("draft_failed", false)):
		draw_kinds["draft_fail"] = int(draw_kinds.get("draft_fail", 0)) + 1
		draw_kinds["other"] = int(draw_kinds.get("other", 0)) + 1
		return
	if bool(result.get("stale_draw", false)):
		draw_kinds["stale"] = int(draw_kinds.get("stale", 0)) + 1
		return
	if bool(result.get("timed_out", false)):
		draw_kinds["timeouts"] = int(draw_kinds.get("timeouts", 0)) + 1
		return
	draw_kinds["other"] = int(draw_kinds.get("other", 0)) + 1

static func _trainee_outcome(result: Dictionary, trainee_is_green: bool) -> Dictionary:
	var rate := AiMatchScore.outcome_rate(result, trainee_is_green)
	if is_equal_approx(rate, 0.5):
		return {"wins": 0, "losses": 0, "draws": 1}
	if rate > 0.5:
		return {"wins": 1, "losses": 0, "draws": 0}
	return {"wins": 0, "losses": 1, "draws": 0}

static func _absorb_duel_result(
	match_rows: Array,
	legion_rows: Array,
	result: Dictionary,
	local_game: int,
	green_brain_id: String,
	blue_brain_id: String,
	curriculum_stage_id: String = "",
	draft_mode_id: String = ""
) -> int:
	local_game += 1
	var mr: Dictionary = result.get("match_row", {}).duplicate(true)
	if mr.is_empty():
		mr = {
			"winner": result.get("winner", ""),
			"timed_out": result.get("timed_out", false),
			"stale_draw": result.get("stale_draw", false),
			"team_turns": result.get("team_turns", 0),
		}
	mr["game_id"] = local_game
	mr["green_brain"] = green_brain_id
	mr["blue_brain"] = blue_brain_id
	if not curriculum_stage_id.is_empty():
		mr["curriculum_stage"] = curriculum_stage_id
	if not draft_mode_id.is_empty():
		mr["draft_mode"] = draft_mode_id
	match_rows.append(mr)
	for leg in result.get("legion_rows", []):
		var row: Dictionary = leg.duplicate(true)
		row["game_id"] = local_game
		legion_rows.append(row)
	return local_game

static func empty_match_stats() -> Dictionary:
	return {
		"games": 0,
		"stale_draws": 0,
		"timeouts": 0,
		"other_draws": 0,
		"team_turns_sum": 0,
		"draft_failures": 0,
	}

static func accumulate_match_result(stats: Dictionary, result: Dictionary) -> void:
	stats["games"] = int(stats.get("games", 0)) + 1
	stats["team_turns_sum"] = int(stats.get("team_turns_sum", 0)) + int(result.get("team_turns", 0))
	if bool(result.get("draft_failed", false)):
		stats["draft_failures"] = int(stats.get("draft_failures", 0)) + 1
		stats["other_draws"] = int(stats.get("other_draws", 0)) + 1
		return
	if bool(result.get("stale_draw", false)):
		stats["stale_draws"] = int(stats.get("stale_draws", 0)) + 1
		return
	if bool(result.get("timed_out", false)):
		stats["timeouts"] = int(stats.get("timeouts", 0)) + 1
		return
	if String(result.get("winner", "")).is_empty():
		stats["other_draws"] = int(stats.get("other_draws", 0)) + 1

static func merge_match_stats(into: Dictionary, from: Dictionary) -> void:
	if from.is_empty():
		return
	for key in ["games", "stale_draws", "timeouts", "other_draws", "team_turns_sum", "draft_failures"]:
		into[key] = int(into.get(key, 0)) + int(from.get(key, 0))

static func format_match_stats(stats: Dictionary) -> String:
	var games := int(stats.get("games", 0))
	var stale := int(stats.get("stale_draws", 0))
	var timeouts := int(stats.get("timeouts", 0))
	var other := int(stats.get("other_draws", 0))
	var draws := stale + timeouts + other
	var avg_turns := 0.0
	if games > 0:
		avg_turns = float(stats.get("team_turns_sum", 0)) / float(games)
	var draft_fail := int(stats.get("draft_failures", 0))
	var decided := games - draws
	return (
		"games=%d decided=%d draws=%d (stale=%d timeout=%d other=%d draft_fail=%d) avg_turns=%.1f"
		% [games, decided, draws, stale, timeouts, other, draft_fail, avg_turns]
	)
