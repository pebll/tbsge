extends RefCounted

const AiGenomeScript = preload("res://scripts/ai/evolution/ai_genome.gd")
const AiGaPopulationScript = preload("res://scripts/ai/evolution/ai_ga_population.gd")
const AiEvaluator = preload("res://scripts/ai/evolution/ai_evaluator.gd")
const AiFeatureNames = preload("res://scripts/ai/utility/ai_feature_names.gd")
const AiEvolveRunner = preload("res://scripts/ai/evolution/ai_evolve_runner.gd")
const AiArchiveStore = preload("res://scripts/ai/evolution/ai_archive_store.gd")
const AiDuelRunner = preload("res://scripts/balance/ai_duel_runner.gd")
const AiEvalParallel = preload("res://scripts/ai/evolution/ai_eval_parallel.gd")
const AttackNearestEnemyBehavior = preload("res://scripts/ai/behaviors/attack_nearest_enemy.gd")
const CombatExpectation = preload("res://scripts/ai/expectation/combat_expectation.gd")
const CombatResolver = preload("res://scripts/core/combat_resolver.gd")
const CurriculumScore = preload("res://scripts/ai/curriculum/curriculum_score.gd")
const MinigameTestHelpersScript = preload("res://tests/minigame_test_helpers.gd")

## Records the headless flags visible while a duel is being played.
class FlagProbeBrain extends AiBrain:
	var seen: Array = []

	func _init() -> void:
		id = "flag_probe"

	func decide(_session, legion: Legion) -> Dictionary:
		seen.append([
			CombatResolver.quiet,
			AttackNearestEnemyBehavior.debug_enabled,
			GameSettings.battle_expectation_log_timing,
		])
		return {"type": "pass", "coords": legion.tile_coords if legion else Vector2i.ZERO, "reason": "probe"}

func run(_tree: SceneTree) -> bool:
	if not _test_genome_roundtrip():
		return false
	if not _test_old_profile_missing_new_features_defaults_zero():
		return false
	if not _test_mutate_changes_some_weights():
		return false
	if not _test_ga_population_basics():
		return false
	if not _test_cumulative_fitness():
		return false
	if not _test_elite_pairs_budget():
		return false
	if not _test_eval_rank_mark():
		return false
	if not _test_confirm_report_merge():
		return false
	if not _test_evaluator_smoke():
		return false
	if not _test_evolve_one_generation_smoke():
		return false
	if not _test_checkpoint_roundtrip_and_continue():
		return false
	if not _test_continue_pairs_override():
		return false
	if not _test_history_stage_inference():
		return false
	if not _test_stop_file():
		return false
	if not _test_evaluation_leaves_global_sim_count_alone():
		return false
	if not _test_worker_run_one_does_not_write_globals():
		return false
	if not _test_headless_flags_set_and_restored():
		return false
	if not _test_headless_duel_emits_no_event_bus_signals():
		return false
	if not _test_session_still_emits_by_default():
		return false
	if not _test_legion_shield_refill_emit_is_suppressible():
		return false
	if not _test_null_job_result_becomes_error():
		return false
	if not _test_generation_seeds_shared_and_collision_free():
		return false
	if not _test_session_children_share_generation_seed():
		return false
	if not _test_reinforce_engage_only_floors_pass_penalty():
		return false
	if not _test_simple_draw_never_below_loss():
		return false
	if not _test_arena_cadence_and_disjoint_seeds():
		return false
	if not _test_history_row_omits_skipped_arena_numbers():
		return false
	print("Success: GA evolution tests")
	return true

func _test_genome_roundtrip() -> bool:
	var g = AiGenomeScript.from_hand_v1()
	var p = g.to_profile("t")
	if not is_equal_approx(p.weight_for(AiFeatureNames.PASS_PENALTY), g.weights[AiFeatureNames.PASS_PENALTY]):
		push_error("Profile roundtrip mismatch")
		return false
	return true

func _test_old_profile_missing_new_features_defaults_zero() -> bool:
	var names := AiFeatureNames.all_names()
	if not names.has("trade_value") or not names.has("wipe_prob"):
		push_error("Genome names must include trade_value / wipe_prob")
		return false
	var old := {"weights": {"pass_penalty": -10.0, "enemy_loss_frac": 2.0}}
	var g = AiGenomeScript.from_dict(old)
	if not g.weights.has("trade_value") or float(g.weights["trade_value"]) != 0.0 or float(g.weights["wipe_prob"]) != 0.0:
		push_error("Old checkpoints must default new weights to 0")
		return false
	var p = g.to_profile("old")
	if p.weight_for("wipe_prob") != 0.0 or p.weight_for("trade_value") != 0.0:
		push_error("Profile weight_for must default to 0")
		return false
	var bare := AiProfile.new()
	bare.weights = {"enemy_loss_frac": 1.0}
	if bare.weight_for("trade_value") != 0.0:
		push_error("Missing profile key must read as 0")
		return false
	var hand = AiGenomeScript.from_hand_v1()
	if float(hand.weights["trade_value"]) != 6.0 or float(hand.weights["wipe_prob"]) != 3.0:
		push_error("from_hand_v1 must carry the new weights")
		return false
	return true

func _test_mutate_changes_some_weights() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var g = AiGenomeScript.from_hand_v1()
	var child = g.mutate(rng, 1.0, 1.0)
	var changed := 0
	for name in AiFeatureNames.all_names():
		if not is_equal_approx(float(g.weights[name]), float(child.weights[name])):
			changed += 1
	if changed == 0:
		push_error("Expected mutate(gene_chance=1) to change weights")
		return false
	return true

func _test_ga_population_basics() -> bool:
	var pop = AiGaPopulationScript.new()
	var g1 = AiGenomeScript.from_hand_v1()
	var g2 = g1.duplicate_genome()
	pop.add_member(g1, 1.5, {"aggression": 0.2, "risk": 0.2})
	pop.add_member(g2, 2.2, {"aggression": 0.5, "risk": 0.5})
	if not is_equal_approx(pop.best_fitness(), 2.2):
		push_error("Best fitness should be 2.2")
		return false
	if not pop.would_confirm(2.3):
		push_error("Should confirm above best")
		return false
	if pop.would_confirm(1.0):
		push_error("Should not confirm far below best")
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var picked = pop.tournament_select(rng)
	if picked == null:
		push_error("Tournament should return a genome")
		return false
	return true

func _test_cumulative_fitness() -> bool:
	var desc: Dictionary = {}
	var r1 := {"pair_points": 8.0, "pair_count": 4, "trainee_wins": 8, "trainee_losses": 0, "trainee_draws": 0}
	var r2 := {"pair_points": 7.0, "pair_count": 4, "trainee_wins": 7, "trainee_losses": 0, "trainee_draws": 1, "trainee_stale_draws": 1}
	var fit1 := AiGaPopulationScript.accumulate_eval(desc, r1)
	if not is_equal_approx(fit1, 2.0):
		push_error("First cumulative fit expected 2.0 got %s" % fit1)
		return false
	var fit2 := AiGaPopulationScript.accumulate_eval(desc, r2)
	if not is_equal_approx(fit2, 1.875):
		push_error("Second cumulative fit expected 1.875 got %s" % fit2)
		return false
	if int(desc.get("cum_wins", 0)) != 15:
		push_error("cum_wins expected 15")
		return false
	if int(desc.get("cum_draws", 0)) != 1:
		push_error("cum_draws expected 1")
		return false
	var boot: Dictionary = {}
	var fit3 := AiGaPopulationScript.accumulate_eval(boot, r1, 1.8)
	if not is_equal_approx(fit3, 1.9):
		push_error("Bootstrap cumulative fit expected 1.9 got %s" % fit3)
		return false
	return true

func _test_elite_pairs_budget() -> bool:
	if AiEvolveRunner._elite_pairs_per_eval(5) != 2:
		push_error("elite pairs for 5 should be 2")
		return false
	if AiEvolveRunner._elite_pairs_per_eval(4) != 2:
		push_error("elite pairs for 4 should be 2")
		return false
	if AiEvolveRunner._elite_pairs_per_eval(1) != 1:
		push_error("elite pairs for 1 should stay 1")
		return false
	return true

func _test_eval_rank_mark() -> bool:
	if AiEvolveRunner.eval_rank_mark(1.5, 1.1, 1.4) != "!!":
		push_error("expected !! above best elite")
		return false
	if AiEvolveRunner.eval_rank_mark(1.2, 1.1, 1.4) != "+":
		push_error("expected + above worst elite")
		return false
	if AiEvolveRunner.eval_rank_mark(1.0, 1.1, 1.4) != "·":
		push_error("expected · below worst elite")
		return false
	return true

func _test_confirm_report_merge() -> bool:
	var scout := {
		"pair_count": 2,
		"pair_points": 3.0,
		"fitness": 1.5,
		"trainee_wins": 2,
		"trainee_losses": 0,
		"trainee_draws": 2,
		"win_rate": 0.75,
		"trainee_stale_draws": 2,
		"trainee_timeouts": 0,
		"trainee_other_draws": 0,
		"trainee_draft_failures": 0,
		"match_stats": {"games": 4, "stale_draws": 2, "timeouts": 0, "other_draws": 0, "draft_failures": 0},
		"match_rows": [1, 2],
		"legion_rows": [3],
	}
	var confirm := {
		"pair_count": 4,
		"pair_points": 4.0,
		"fitness": 1.0,
		"trainee_wins": 1,
		"trainee_losses": 1,
		"trainee_draws": 6,
		"win_rate": 0.4375,
		"trainee_stale_draws": 6,
		"trainee_timeouts": 0,
		"trainee_other_draws": 0,
		"trainee_draft_failures": 0,
		"match_stats": {"games": 8, "stale_draws": 6, "timeouts": 0, "other_draws": 0, "draft_failures": 0},
		"match_rows": [4, 5],
		"legion_rows": [6],
		"opponent": "pass",
	}
	var merged: Dictionary = AiEvaluator.merge_scout_confirm_reports(scout, confirm)
	if int(merged.get("trainee_wins", 0)) != 3:
		push_error("merged wins expected 3")
		return false
	if int(merged.get("trainee_draws", 0)) != 8:
		push_error("merged draws expected 8")
		return false
	if int(merged.get("trainee_stale_draws", 0)) != 8:
		push_error("merged trainee stale expected 8")
		return false
	if int(merged.get("pair_count", 0)) != 6:
		push_error("merged pair_count expected 6")
		return false
	if not is_equal_approx(float(merged.get("win_rate", 0.0)), 7.0 / 12.0):
		push_error("merged win_rate expected 7/12")
		return false
	if int(merged.get("match_stats", {}).get("stale_draws", 0)) != 8:
		push_error("merged stale_draws expected 8")
		return false
	if int(merged.get("match_rows", []).size()) != 4:
		push_error("merged match_rows expected 4")
		return false
	return true

func _test_evaluator_smoke() -> bool:
	var g = AiGenomeScript.from_hand_v1()
	var report: Dictionary = AiEvaluator.evaluate_genome(g, 1, 3, 75, 1)
	var fitness := float(report.get("fitness", -999.0))
	if fitness < -3.0 or fitness > 5.0:
		push_error("Fitness out of plausible range: %s" % fitness)
		return false
	var d: Dictionary = report.get("descriptor", {})
	for key in ["aggression", "risk", "support_focus"]:
		if not d.has(key):
			push_error("Missing descriptor %s" % key)
			return false
	return true

func _test_evolve_one_generation_smoke() -> bool:
	var batch: Dictionary = AiEvolveRunner.run(1, 2, 1, 3, 75, 99, false)
	if int(batch.get("archive_size", 0)) < 1:
		push_error("Population should have at least one member")
		return false
	if int(batch.get("evaluations", 0)) < 2:
		push_error("Expected several evaluations")
		return false
	return true

func _test_checkpoint_roundtrip_and_continue() -> bool:
	var run_dir := "res://data/ai/evolve/_test_ckpt_%d" % Time.get_ticks_msec()
	var batch1: Dictionary = AiEvolveRunner.run_session({
		"gens": 1,
		"pop": 2,
		"pairs": 1,
		"map_size": 3,
		"budget": 75,
		"seed": 11,
		"verbose": false,
		"run_dir": run_dir,
		"continue_run": false,
		"arena_pairs": 1,
		"arena_opponents": 1,
		"checkpoint_every": 1,
	})
	if not AiArchiveStore.has_checkpoint(run_dir):
		push_error("Expected checkpoint after first session")
		return false
	if int(batch1.get("generations", 0)) != 1:
		push_error("Expected 1 generation completed")
		return false
	var batch2: Dictionary = AiEvolveRunner.run_session({
		"gens": 1,
		"pop": 2,
		"pairs": 1,
		"map_size": 3,
		"budget": 75,
		"seed": 11,
		"verbose": false,
		"run_dir": run_dir,
		"continue_run": true,
		"arena_pairs": 1,
		"arena_opponents": 1,
		"checkpoint_every": 1,
	})
	if int(batch2.get("generations", 0)) != 2:
		push_error("Continue should reach gen 2, got %s" % batch2.get("generations"))
		return false
	if not batch2.has("vs_cascade"):
		push_error("Expected vs_cascade metric")
		return false
	var abs_dir := ProjectSettings.globalize_path(run_dir)
	for fname in ["checkpoint.json", "history.jsonl", "best_profile.json", "STOP"]:
		var p := abs_dir.path_join(fname)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var bal := abs_dir.path_join("balance")
	if DirAccess.dir_exists_absolute(bal):
		for fname2 in ["matches.csv", "legions.csv"]:
			var p2 := bal.path_join(fname2)
			if FileAccess.file_exists(p2):
				DirAccess.remove_absolute(p2)
		DirAccess.remove_absolute(bal)
	DirAccess.remove_absolute(abs_dir)
	return true

func _test_continue_pairs_override() -> bool:
	var run_dir := "res://data/ai/evolve/_test_pairs_ov_%d" % Time.get_ticks_msec()
	AiEvolveRunner.run_session({
		"gens": 1,
		"pop": 2,
		"pairs": 1,
		"verbose": false,
		"run_dir": run_dir,
		"continue_run": false,
		"arena_pairs": 1,
		"arena_opponents": 1,
	})
	var state := AiArchiveStore.load_checkpoint(run_dir)
	if int(state.get("config", {}).get("pairs", 0)) != 1:
		push_error("Checkpoint should store pairs=1")
		return false
	AiEvolveRunner.run_session({
		"gens": 0,
		"pop": 2,
		"pairs": 4,
		"verbose": false,
		"run_dir": run_dir,
		"continue_run": true,
		"cli_overrides": {"pairs": 4},
	})
	state = AiArchiveStore.load_checkpoint(run_dir)
	if int(state.get("config", {}).get("pairs", 0)) != 4:
		push_error(
			"Continue pairs override should persist pairs=4, got %d"
			% int(state.get("config", {}).get("pairs", 0))
		)
		return false
	var abs_dir := ProjectSettings.globalize_path(run_dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.remove_absolute(abs_dir)
	return true

func _test_history_stage_inference() -> bool:
	const AiEvolveHistory = preload("res://scripts/ai/evolution/ai_evolve_history.gd")
	var checkpoint := {
		"curriculum": {
			"history": [
				{"stage": "pass_mirror", "promoted_at_gen": 10},
				{"stage": "pass_random", "promoted_at_gen": 20},
			]
		}
	}
	var timeline: Array = AiEvolveHistory.promotion_timeline(checkpoint)
	if String(AiEvolveHistory.stage_at_gen(0, timeline)) != "pass_mirror":
		return false
	if String(AiEvolveHistory.stage_at_gen(15, timeline)) != "pass_random":
		return false
	if String(AiEvolveHistory.stage_at_gen(25, timeline)) != "heal_mirror":
		return false
	return true

func _test_stop_file() -> bool:
	var run_dir := "res://data/ai/evolve/_test_stop_%d" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
	AiArchiveStore.request_stop(run_dir)
	if not AiArchiveStore.should_stop(run_dir):
		push_error("STOP file should be detected")
		return false
	AiArchiveStore.clear_stop(run_dir)
	if AiArchiveStore.should_stop(run_dir):
		push_error("STOP file should be cleared")
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_dir))
	return true

func _test_evaluation_leaves_global_sim_count_alone() -> bool:
	CombatExpectation.set_sim_count(9)
	var calls0: int = CombatExpectation.estimate_calls
	var sims0: int = CombatExpectation.sims_run
	AiEvaluator.evaluate_vs_cascade(AiGenomeScript.from_hand_v1(), 1, 3, 75, 3)
	var calls: int = CombatExpectation.estimate_calls - calls0
	var sims: int = CombatExpectation.sims_run - sims0
	var global_after: int = CombatExpectation.get_sim_count()
	CombatExpectation.use_play_mode()
	if global_after != 9:
		push_error("Evaluation must not toggle the global sim count (got %d)" % global_after)
		return false
	if calls <= 0 or sims != CombatExpectation.TRAIN_SIM_COUNT * calls:
		push_error("Evaluated utility brain must use TRAIN_SIM_COUNT (sims=%d calls=%d)" % [sims, calls])
		return false
	return true

func _test_worker_run_one_does_not_write_globals() -> bool:
	var prev_quiet: bool = CombatResolver.quiet
	var prev_debug: bool = AttackNearestEnemyBehavior.debug_enabled
	var prev_log: bool = GameSettings.battle_expectation_log_timing
	CombatResolver.quiet = false
	AttackNearestEnemyBehavior.debug_enabled = true
	GameSettings.battle_expectation_log_timing = true
	var probe := FlagProbeBrain.new()
	var other := FlagProbeBrain.new()
	var tid := WorkerThreadPool.add_task(func() -> void:
		AiDuelRunner.run_one(0, 3, 75, probe, other)
	)
	WorkerThreadPool.wait_for_task_completion(tid)
	var after: Array = [
		CombatResolver.quiet, AttackNearestEnemyBehavior.debug_enabled, GameSettings.battle_expectation_log_timing
	]
	CombatResolver.quiet = prev_quiet
	AttackNearestEnemyBehavior.debug_enabled = prev_debug
	GameSettings.battle_expectation_log_timing = prev_log
	if probe.seen.is_empty():
		push_error("Probe brain never decided")
		return false
	if probe.seen[0] != [false, true, true] or after != [false, true, true]:
		push_error("run_one on a worker must leave the shared flags alone (seen %s after %s)" % [probe.seen[0], after])
		return false
	return true

func _test_headless_flags_set_and_restored() -> bool:
	var prev_quiet: bool = CombatResolver.quiet
	var prev_debug: bool = AttackNearestEnemyBehavior.debug_enabled
	var prev_log: bool = GameSettings.battle_expectation_log_timing
	CombatResolver.quiet = false
	AttackNearestEnemyBehavior.debug_enabled = true
	GameSettings.battle_expectation_log_timing = true
	var saved: Dictionary = AiDuelRunner.begin_headless()
	var during: Array = [
		CombatResolver.quiet, AttackNearestEnemyBehavior.debug_enabled, GameSettings.battle_expectation_log_timing
	]
	AiDuelRunner.end_headless(saved)
	var restored: Array = [
		CombatResolver.quiet, AttackNearestEnemyBehavior.debug_enabled, GameSettings.battle_expectation_log_timing
	]
	# Parallel evaluation must hand the flags back untouched as well.
	var jobs: Array = []
	for i in range(2):
		jobs.append({
			"genome": AiGenomeScript.from_hand_v1(), "rng_seed": 5 + i, "seed_offset": i, "pairs": 1,
			"map_size": 3, "budget": 75, "use_curriculum": false, "teacher_on": true,
		})
	AiEvalParallel.run_jobs(jobs, 2)
	var after_jobs: Array = [
		CombatResolver.quiet, AttackNearestEnemyBehavior.debug_enabled, GameSettings.battle_expectation_log_timing
	]
	CombatResolver.quiet = prev_quiet
	AttackNearestEnemyBehavior.debug_enabled = prev_debug
	GameSettings.battle_expectation_log_timing = prev_log
	if during != [true, false, false]:
		push_error("begin_headless must silence the shared flags (got %s)" % [during])
		return false
	if restored != [false, true, true] or after_jobs != [false, true, true]:
		push_error("Flags must be restored (got %s / %s)" % [restored, after_jobs])
		return false
	return true

func _test_headless_duel_emits_no_event_bus_signals() -> bool:
	var count := [0]
	var cb := func(_entry: Dictionary) -> void:
		count[0] += 1
	var shield_cb := func(_legion: Legion) -> void:
		count[0] += 1
	EventBus.battle_log_entry_added.connect(cb)
	EventBus.legion_shields_refilled.connect(shield_cb)
	AiDuelRunner.run_one(1, 3, 75)
	EventBus.battle_log_entry_added.disconnect(cb)
	EventBus.legion_shields_refilled.disconnect(shield_cb)
	if count[0] != 0:
		push_error("Headless duel must not emit to EventBus (%d emits)" % count[0])
		return false
	return true

func _test_session_still_emits_by_default() -> bool:
	var session := MinigameTestHelpersScript.prepare_session()
	MinigameTestHelpersScript.start_two_legion_battle(session)
	if not session.emit_global_events:
		push_error("Sessions must emit global events by default (in-game behaviour)")
		return false
	var count := [0]
	var cb := func(_entry: Dictionary) -> void:
		count[0] += 1
	EventBus.battle_log_entry_added.connect(cb)
	session.apply({"type": "end_turn"})
	EventBus.battle_log_entry_added.disconnect(cb)
	if count[0] < 1:
		push_error("Default session should still emit battle_log_entry_added")
		return false
	return true

func _test_legion_shield_refill_emit_is_suppressible() -> bool:
	var count := [0]
	var cb := func(_legion: Legion) -> void:
		count[0] += 1
	EventBus.legion_shields_refilled.connect(cb)
	var quiet_legion := Legion.new("GOBLIN", 1, Vector2i.ZERO, "GREEN")
	quiet_legion.emit_global_events = false
	quiet_legion.units[0].shield_max = 2
	quiet_legion.units[0].shield_remaining = 0
	quiet_legion.refresh_ap()
	var quiet_emits: int = count[0]
	var loud_legion := Legion.new("GOBLIN", 1, Vector2i.ZERO, "GREEN")
	loud_legion.units[0].shield_max = 2
	loud_legion.units[0].shield_remaining = 0
	loud_legion.refresh_ap()
	EventBus.legion_shields_refilled.disconnect(cb)
	if quiet_emits != 0:
		push_error("A headless legion must not emit legion_shields_refilled")
		return false
	if count[0] != 1:
		push_error("A default legion must still emit legion_shields_refilled (in-game behaviour)")
		return false
	return true

func _test_null_job_result_becomes_error() -> bool:
	var r: Dictionary = AiEvalParallel.result_or_error(null, 3)
	if not r.has("error") or String(r["error"]).is_empty():
		push_error("A missing job result must carry an error message")
		return false
	if not (r.get("report") is Dictionary) or int((r["report"] as Dictionary).get("pair_count", -1)) != 0:
		push_error("Error result needs an empty report callers can .get on")
		return false
	var ok := {"report": {"pair_count": 2}, "eval_ms": 5}
	if AiEvalParallel.result_or_error(ok, 0) != ok:
		push_error("Valid results must pass through")
		return false
	return true

func _test_generation_seeds_shared_and_collision_free() -> bool:
	var seen := {}
	for gen in range(-1, 3000):
		var off: int = AiEvolveRunner.generation_seed_offset(7, gen)
		if seen.has(off):
			push_error("Generation seed collision at gen %d" % gen)
			return false
		seen[off] = true
	for gen in range(0, 3000):
		if seen.has(AiEvolveRunner.arena_seed_offset(7, gen)):
			push_error("Arena seed overlaps training seeds at gen %d" % gen)
			return false
	return true

func _test_session_children_share_generation_seed() -> bool:
	var batch: Dictionary = AiEvolveRunner.run_session({
		"gens": 2, "pop": 4, "elites": 2, "pairs": 2, "seed": 5, "verbose": false,
		"curriculum": false, "arena_pairs": 1, "arena_opponents": 1,
	})
	var by_gen: Dictionary = batch.get("generation_seed_offsets", {})
	if by_gen.size() != 2:
		push_error("Expected seed offsets for 2 generations, got %s" % [by_gen])
		return false
	var firsts := []
	for gen in by_gen.keys():
		var offs: Array = by_gen[gen]
		if offs.size() < 3:
			push_error("Expected elite + child jobs, got %s" % [offs])
			return false
		for o in offs:
			if o != offs[0]:
				push_error("All genomes of generation %s must share one seed, got %s" % [gen, offs])
				return false
		firsts.append(offs[0])
	if firsts[0] == firsts[1]:
		push_error("Generations must use different seeds")
		return false
	return true

func _test_reinforce_engage_only_floors_pass_penalty() -> bool:
	var g := AiGenomeScript.new()
	for name in AiFeatureNames.all_names():
		g.weights[name] = 0.0
	g.reinforce_engage()
	if float(g.weights[AiFeatureNames.PASS_PENALTY]) != -10.0:
		push_error("pass_penalty should be capped at -10")
		return false
	for name in [AiFeatureNames.CLOSER_TO_FOCUS, AiFeatureNames.ENABLES_ATTACK, AiFeatureNames.IS_COMBAT]:
		if float(g.weights[name]) != 0.0:
			push_error("%s must no longer be floored" % name)
			return false
	g.weights[AiFeatureNames.PASS_PENALTY] = -16.0
	g.reinforce_engage()
	if float(g.weights[AiFeatureNames.PASS_PENALTY]) != -16.0:
		push_error("Stronger pass penalties must be kept")
		return false
	return true

func _test_simple_draw_never_below_loss() -> bool:
	var stale := {"gold_start_green": 100.0, "gold_end_green": 100.0}
	var s: float = CurriculumScore.simple_draw_score(stale, true)
	if s < 0.0:
		push_error("A stale draw must not score below a loss (got %f)" % s)
		return false
	var bloody := {"gold_start_green": 100.0, "gold_end_green": 0.0}
	var b: float = CurriculumScore.simple_draw_score(bloody, true)
	if b < 0.0 or b >= 1.0:
		push_error("A draw must stay between a loss and a win (got %f)" % b)
		return false
	return true

func _test_arena_cadence_and_disjoint_seeds() -> bool:
	for use_cur in [false, true]:
		if AiEvolveRunner._should_run_arena(10, 10, false, use_cur) != true:
			push_error("Arena must run on every arena_every-th generation (curriculum=%s)" % use_cur)
			return false
		if AiEvolveRunner._should_run_arena(11, 10, false, use_cur) != false:
			push_error("Arena must skip off-cadence generations (curriculum=%s)" % use_cur)
			return false
		if AiEvolveRunner._should_run_arena(95, 10, true, use_cur) != true:
			push_error("Arena must run at session end")
			return false
	return true

func _test_history_row_omits_skipped_arena_numbers() -> bool:
	var stale := {"gen": 93, "arena_skipped": true, "vs_cascade": 0.7, "vs_arena": 1.2, "vs_arena_fitness": 1.2, "best_fitness": 2.0}
	var row: Dictionary = AiEvolveRunner._history_row(stale, null, null, false)
	for key in ["vs_cascade", "vs_arena", "vs_arena_fitness"]:
		if row.has(key):
			push_error("Skipped arena rows must not carry stale %s" % key)
			return false
	var fresh := {"gen": 100, "arena_skipped": false, "vs_cascade": 0.7, "vs_arena": 1.2, "best_fitness": 2.0}
	if not AiEvolveRunner._history_row(fresh, null, null, false).has("vs_cascade"):
		push_error("Measured rows keep their numbers")
		return false
	return true
